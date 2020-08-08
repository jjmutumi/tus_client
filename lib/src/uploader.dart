import 'client.dart';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'exceptions.dart';
import 'upload.dart';

/// This class is used for doing the actual upload of the files. Instances are
/// returned by [TusClient.createUpload], [TusClient.createUpload] and
/// [TusClient.resumeOrCreateUpload].
///
/// After obtaining an instance you can upload a file by following these steps:
///
///   - Upload a chunk using [uploadChunk]
///   - Optionally get the new offset [offset] to calculate the progress
///   - Repeat step 1 until the [uploadChunk] returns true
///   - Close resources using [finish]
class TusUploader {
  final Uri uploadURL;

  /// The current offset for the upload. This is the number of all bytes
  /// uploaded in total and in all requests (not only this one). You can use it
  /// in conjunction with [TusUpload.size] to calculate the progress.
  int offset;

  final TusClient client;
  final TusUpload upload;
  HttpClientRequest _httpRequest;

  /// Set the maximum payload size for a single request counted in bytes. This
  /// is useful for splitting bigger uploads into multiple requests. For
  /// example, if you have a resource of 2MB and the payload size set to 1MB,
  /// the upload will be transferred by two requests of 1MB each.
  ///
  /// **The default value for this setting is 4 * 1024 * 1024 bytes (4 MB).**
  ///
  /// Be aware that setting a low maximum payload size (in the low megabytes
  /// or even less range) will result in decreased performance since more
  /// requests need to be used for an upload. Each request will come with its
  /// overhead in terms of longer upload times.
  ///
  /// Be aware that setting a high maximum payload size may result in a high
  /// memory usage since client usually allocates a buffer with the maximum
  /// payload size (this buffer is used to allow retransmission of lost data if
  /// necessary). If the client is running on a memory- constrained device
  /// (e.g. mobile app) and the maximum payload size is too high, it might
  /// result in an error.
  ///
  /// This must not be set when the uploader has currently an open connection to
  /// the remote server. In general, try to set the payload size before invoking
  /// [uploadChunk] the first time.
  int payloadSize = 4 * 1024 * 1024;

  int _bytesRemainingForRequest;

  /// Begin a new [upload] request to specified [uploadURL] after a [client] has
  /// prepared for the upload.
  TusUploader(this.client, this.upload, this.uploadURL, this.offset);

  Future<void> _openConnection() async {
    // Only open a connection, if we have none open.
    if (_httpRequest != null) {
      return;
    }

    _bytesRemainingForRequest = payloadSize;

    final httpClient = HttpClient();
    _httpRequest = await httpClient.patchUrl(uploadURL);
    _httpRequest.headers.add("Upload-Offset", offset.toString());
    _httpRequest.headers.add("Content-Type", "application/offset+octet-stream");
    _httpRequest.headers.add("Expect", "100-continue");
  }

  /// Upload a part of the file by reading a chunk from the [TusUpload.file] and 
  /// writing it to [uploadURL] returning `true` if there are no more available
  /// bytes for upload.
  ///
  /// No new connection will be established when calling this method, instead 
  /// the connection opened in the previous calls will be used.
  ///
  /// In order to obtain the new offset, use [offset] after this method returns.
  /// 
  /// Throws [Exception]
  Future<bool> uploadChunk() async {
    _openConnection();

    int bytesToRead = min(payloadSize, _bytesRemainingForRequest);
    final buffer = Uint8List(bytesToRead);

    // Do not write the entire buffer to the stream
    final bytesRead = await upload.file.readInto(buffer, offset, bytesToRead);
    _httpRequest.add(buffer);

    offset += bytesRead;
    _bytesRemainingForRequest -= bytesRead;

    if (_bytesRemainingForRequest <= 0) {
      await _finishConnection();
      return true;
    }

    return false;
  }

  /// Finish the request and free up resources.
  /// 
  /// You can call this method even before the entire file has been uploaded.
  /// Use this behavior to enable pausing uploads.
  /// 
  /// Throws [ProtocolException] or [Exception]
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
    if (_httpRequest != null) {
      final response = await _httpRequest.close();
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

      _httpRequest = null;
    }
  }
}
