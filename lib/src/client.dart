import 'dart:io';

import 'exceptions.dart';
import 'upload.dart';
import 'uploader.dart';
import 'url_store.dart';

/// This class is used for creating or resuming uploads.
class TusClient {
  /// Version of the tus protocol used by the client. The remote server needs to support this version, too.
  static final tusVersion = "1.0.0";

  /// The tus server Uri
  final Uri uploadCreationURL;

  /// Storage used to save and retrieve upload URLs by its fingerprint.
  final TusURLStore urlStore;

  /// Enable removing fingerprints after a successful upload.
  final bool removeFingerprintOnSuccess;

  /// Any additional headers
  final Map<String, String> headers;

  final int connectTimeout;

  bool _resumingEnabled = false;

  TusClient(
    this.uploadCreationURL, {
    this.urlStore,
    this.headers,
    this.removeFingerprintOnSuccess = true,
    this.connectTimeout = 5000,
  }) {
    if (urlStore != null) {
      _resumingEnabled = true;
    }
  }

  bool get resumingEnabled => _resumingEnabled;

  /// Create a new upload using the Creation extension. Before calling this function, an "upload
  /// creation Uri" must be defined using {@link #setUploadCreationURL(Uri)} or else this
  /// function will fail.
  /// In order to create the upload a POST request will be issued. The file's chunks must be
  /// uploaded manually using the returned {@link TusUploader} object.
  /// @param upload The file for which a new upload will be created
  /// @return Use {@link TusUploader} to upload the file's chunks.
  /// @throws ProtocolException Thrown if the remote server sent an unexpected response, e.g.
  /// wrong status codes or missing/invalid headers.
  /// @throws IOException Thrown if an exception occurs while issuing the HTTP request.
  Future<TusUploader> createUpload(TusUpload upload) async {
    HttpClient client = HttpClient();
    client.connectionTimeout = Duration(milliseconds: connectTimeout);
    final request = await client.postUrl(uploadCreationURL);
    prepareConnection(request);

    String metadata = upload.metadata;
    if (metadata.isNotEmpty) {
      request.headers.add("Upload-Metadata", metadata);
    }

    request.headers.add("Upload-Length", upload.size.toString());

    final response = await request.close();
    int responseCode = response.statusCode;
    if (!(responseCode >= 200 && responseCode < 300)) {
      throw ProtocolException(
          "unexpected status code ($responseCode) while creating upload",
          response);
    }

    String urlStr = response.headers.value("Location");
    if (urlStr == null || urlStr.isEmpty) {
      throw ProtocolException(
          "missing upload Uri in response for creating upload", response);
    }

    // The upload Uri must be relative to the Uri of the request by which is was returned,
    // not the upload creation Uri. In most cases, there is no difference between those two
    // but there may be cases in which the POST request is redirected.
    Uri uploadURL = response.redirects.last.location.replace(path: urlStr);

    if (resumingEnabled) {
      urlStore.set(upload.fingerprint, uploadURL);
    }

    return TusUploader(this, upload, uploadURL, 0);
  }

  /// Try to resume an already started upload. Before call this function, resuming must be
  /// enabled using {@link #enableResuming(TusURLStore)}. This method will look up the Uri for this
  /// upload in the {@link TusURLStore} using the upload's fingerprint (see
  /// {@link TusUpload#fingerprint}). After a successful lookup a HEAD request will be issued
  /// to find the current offset without uploading the file, yet.
  /// @param upload The file for which an upload will be resumed
  /// @return Use {@link TusUploader} to upload the remaining file's chunks.
  /// @throws FingerprintNotFoundException Thrown if no matching fingerprint has been found in
  /// {@link TusURLStore}. Use {@link #createUpload(TusUpload)} to create a new upload.
  /// @throws ResumingNotEnabledException Throw if resuming has not been enabled using {@link
  /// #enableResuming(TusURLStore)}.
  /// @throws ProtocolException Thrown if the remote server sent an unexpected response, e.g.
  /// wrong status codes or missing/invalid headers.
  /// @throws IOException Thrown if an exception occurs while issuing the HTTP request.
  Future<TusUploader> resumeUpload(TusUpload upload) async {
    if (!resumingEnabled) {
      throw ResumingNotEnabledException();
    }

    Uri uploadURL = urlStore.get(upload.fingerprint);
    if (uploadURL == null) {
      throw FingerprintNotFoundException(upload.fingerprint);
    }

    return await beginOrResumeUploadFromURL(upload, uploadURL);
  }

  /// Begin an upload or alternatively resume it if the upload has already been started before. In contrast to
  /// {@link #createUpload(TusUpload)} and {@link #resumeOrCreateUpload(TusUpload)} this method will not create a new
  /// upload. The user must obtain the upload location Uri on their own as this method will not send the POST request
  /// which is normally used to create a new upload.
  /// Therefore, this method is only useful if you are uploading to a service which takes care of creating the tus
  /// upload for yourself. One example of such a service is the Vimeo API.
  /// When called a HEAD request will be issued to find the current offset without uploading the file, yet.
  /// The uploading can be started by using the returned {@link TusUploader} object.
  /// @param upload The file for which an upload will be resumed
  /// @param uploadURL The upload location Uri at which has already been created and this file should be uploaded to.
  /// @return Use {@link TusUploader} to upload the remaining file's chunks.
  /// @throws ProtocolException Thrown if the remote server sent an unexpected response, e.g.
  /// wrong status codes or missing/invalid headers.
  /// @throws IOException Thrown if an exception occurs while issuing the HTTP request.
  Future<TusUploader> beginOrResumeUploadFromURL(
      TusUpload upload, Uri uploadURL) async {
    HttpClient client = HttpClient();
    client.connectionTimeout = Duration(milliseconds: connectTimeout);
    final request = await client.headUrl(uploadCreationURL);
    prepareConnection(request);

    final response = await request.close();
    int responseCode = response.statusCode;
    if (!(responseCode >= 200 && responseCode < 300)) {
      throw ProtocolException(
          "unexpected status code ($responseCode) while resuming upload",
          response);
    }

    String offsetStr = response.headers.value("Upload-Offset");
    if (offsetStr == null || offsetStr.isEmpty) {
      throw ProtocolException(
          "missing upload offset in response for resuming upload", response);
    }
    int offset = int.tryParse(offsetStr);

    return TusUploader(this, upload, uploadURL, offset);
  }

  /// Try to resume an upload using {@link #resumeUpload(TusUpload)}. If the method call throws
  /// an {@link ResumingNotEnabledException} or {@link FingerprintNotFoundException}, a new upload
  /// will be created using {@link #createUpload(TusUpload)}.
  /// @param upload The file for which an upload will be resumed
  /// @throws ProtocolException Thrown if the remote server sent an unexpected response, e.g.
  /// wrong status codes or missing/invalid headers.
  /// @throws IOException Thrown if an exception occurs while issuing the HTTP request.
  Future<TusUploader> resumeOrCreateUpload(TusUpload upload) async {
    try {
      return await resumeUpload(upload);
    } catch (err) {
      if (err is FingerprintNotFoundException) {
        return await createUpload(upload);
      } else if (err is ResumingNotEnabledException) {
        return await createUpload(upload);
      } else if (err is ProtocolException) {
        // If the attempt to resume returned a 404 Not Found, we immediately try to create a new
        // one since TusExectuor would not retry this operation.
        if (err.response != null && err.response.statusCode == 404) {
          return await createUpload(upload);
        }
      }
      throw err;
    }
  }

  /// Set headers used for every HTTP request. Currently, this will add the Tus-Resumable header
  /// and any custom header which can be configured using {@link #setHeaders(Map)},
  /// @param connection The connection whose headers will be modified.
  void prepareConnection(HttpClientRequest request) {
    request.headers.add("Tus-Resumable", tusVersion);

    if (headers != null) {
      for (MapEntry<String, String> entry in headers.entries) {
        request.headers.add(entry.key, entry.value);
      }
    }
  }

  /// Actions to be performed after a successful upload completion.
  /// Manages Uri removal from the Uri store if remove fingerprint on success is enabled
  /// @param upload that has been finished
  void uploadFinished(TusUpload upload) {
    if (resumingEnabled && removeFingerprintOnSuccess) {
      urlStore.remove(upload.fingerprint);
    }
  }
}
