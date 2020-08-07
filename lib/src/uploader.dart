import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'client.dart';
import 'exceptions.dart';
import 'upload.dart';

/// This class is used for doing the actual upload of the files. Instances are returned by
/// [TusClient.createUpload()], [TusClient.createUpload()] and
/// [TusClient.resumeOrCreateUpload()].
/// <br>
/// After obtaining an instance you can upload a file by following these steps:
///
///   - Upload a chunk using [uploadChunk]
///   - Optionally get the new offset ([offset] to calculate the progress
///   - Repeat step 1 until the [uploadChunk] returns -1
///   - Close HTTP connection and InputStream using [finish] to free resources
class TusUploader {
  Uri uploadURL;

  /// The current offset for the upload. This is the number of all bytes uploaded in total and
  /// in all requests (not only this one). You can use it in conjunction with [TusUpload.size]
  /// to calculate the progress.
  int offset;

  TusClient client;
  TusUpload upload;
  HttpClientRequest httpRequest;

  /// Set the maximum payload size for a single request counted in bytes. This is useful for splitting
  /// bigger uploads into multiple requests. For example, if you have a resource of 2MB and
  /// the payload size set to 1MB, the upload will be transferred by two requests of 1MB each.
  ///
  /// The default value for this setting is 10 * 1024 * 1024 bytes (10 MiB).
  ///
  /// Be aware that setting a low maximum payload size (in the low megabytes or even less range) will result in decreased
  /// performance since more requests need to be used for an upload. Each request will come with its overhead in terms
  /// of longer upload times.
  ///
  /// Be aware that setting a high maximum payload size may result in a high memory usage since
  /// client usually allocates a buffer with the maximum payload size (this buffer is used
  /// to allow retransmission of lost data if necessary). If the client is running on a memory-
  /// constrained device (e.g. mobile app) and the maximum payload size is too high, it might
  /// result in an error.
  ///
  /// This must not be set when the uploader has currently an open connection to the
  /// remote server. In general, try to set the payload size before invoking [uploadChunk()]
  /// the first time.
  int chunkSize = 2 * 1024 * 1024;

  int requestPayloadSize = 10 * 1024 * 1024;
  int bytesRemainingForRequest;

  /// Begin a new upload request by opening a PATCH request to specified upload Uri. After this
  /// method returns a connection will be ready and you can upload chunks of the file.
  /// @param client Used for preparing a request ([TusClient.prepareConnection(HttpURLConnection)}
  /// @param uploadURL Uri to send the request to
  /// @param input Stream to read (and seek) from and upload to the remote server
  /// @param offset Offset to read from
  /// @throws IOException Thrown if an exception occurs while issuing the HTTP request.
  TusUploader(TusClient client, TusUpload upload, Uri uploadURL, int offset) {
    this.client = client;
    this.upload = upload;
    this.uploadURL = uploadURL;
    this.offset = offset;
  }

  Future<void> openConnection() async {
    // Only open a connection, if we have none open.
    if (httpRequest != null) {
      return;
    }

    bytesRemainingForRequest = requestPayloadSize;

    final httpClient = HttpClient();
    httpRequest = await httpClient.patchUrl(uploadURL);
    httpRequest.headers.add("Upload-Offset", offset.toString());
    httpRequest.headers.add("Content-Type", "application/offset+octet-stream");
    httpRequest.headers.add("Expect", "100-continue");

    // connection.setDoOutput(true);
    // connection.setChunkedStreamingMode(0);
    // try {
    //     output = connection.getOutputStream();
    // } catch(java.net.ProtocolException pe) {
    //     // If we already have a response code available, our expectation using the "Expect: 100-
    //     // continue" header failed and we should handle this response.
    //     if(connection.getResponseCode() != -1) {
    //         finish();
    //     }

    //     throw pe;
    // }
  }

  /// Upload a part of the file by reading a chunk from the file and writing
  /// it to the HTTP request's body. If the number of available bytes is lower than the chunk's
  /// size, all available bytes will be uploaded and nothing more.
  ///
  /// No new connection will be established when calling this method, instead the connection opened
  /// in the previous calls will be used.
  ///`
  /// The size of the read chunk can be obtained using [chunkSize] and changed
  /// using [chunkSize].
  /// In order to obtain the new offset, use [offset] after this method returns.
  /// @return Number of bytes read and written.
  /// @throws IOException  Thrown if an exception occurs while reading from the source or writing
  ///                      to the HTTP request.
  Future<bool> uploadChunk() async {
    openConnection();

    int bytesToRead = min(chunkSize, bytesRemainingForRequest);
    final buffer = Uint8List(bytesToRead);

    // Do not write the entire buffer to the stream since the array will
    // be filled up with 0x00s if the number of read bytes is lower then
    // the chunk's size.

    final bytesRead = await upload.file.readInto(buffer, offset, bytesToRead);
    httpRequest.add(buffer);
    // output.write(buffer, 0, bytesRead);
    // output.flush();

    offset += bytesRead;
    bytesRemainingForRequest -= bytesRead;

    if (bytesRemainingForRequest <= 0) {
      await _finishConnection();
      return true;
    }

    return false;
  }

  /// Finish the request by closing the HTTP connection and the InputStream.
  /// You can call this method even before the entire file has been uploaded. Use this behavior to
  /// enable pausing uploads.
  /// @throws ProtocolException Thrown if the server sends an unexpected status
  /// code
  /// @throws IOException  Thrown if an exception occurs while cleaning up.
  Future<void> finish() async {
    await _finishConnection();
    if (upload.size == offset) {
      client.uploadFinished(upload);
    }

    // Close the file after checking the response to ensure
    // that we will not need to read from it again in the future.
    upload.file.close();
  }

  Future<void> _finishConnection() async {
    if (httpRequest != null) {
      final response = await httpRequest.close();
      int responseCode = response.statusCode;

      if (!(responseCode >= 200 && responseCode < 300)) {
        throw ProtocolException(
            "unexpected status code ($responseCode) while uploading chunk",
            response);
      }

      // TODO detect changes and seek accordingly
      int serverOffset = int.tryParse(response.headers.value("Upload-Offset"));
      if (serverOffset == -1) {
        throw ProtocolException(
            "response to PATCH request contains no or invalid Upload-Offset header",
            response);
      }
      if (offset != serverOffset) {
        throw ProtocolException(
            "response contains different Upload-Offset value ($serverOffset) than expected ($offset)",
            response);
      }

      httpRequest = null;
    }
  }
}
