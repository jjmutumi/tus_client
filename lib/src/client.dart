import 'dart:io';
import 'exceptions.dart';
import 'upload.dart';
import 'uploader.dart';
import 'url_store.dart';

/// This class is used for creating or resuming uploads.
class TusClient {
  /// Version of the tus protocol used by the client. The remote server needs to
  /// support this version, too.
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

  /// Create a new [upload] returning a [TusUploader] to upload the file's
  /// chunks (manually).
  ///
  /// Throws [ProtocolException] or [Exception]
  Future<TusUploader> createUpload(TusUpload upload) async {
    final client = httpClient();
    client.connectionTimeout = Duration(milliseconds: connectTimeout);
    final request = await client.postUrl(uploadCreationURL);
    _addHeaders(request);

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

    // The upload Uri must be relative to the Uri of the response by which is
    // was returned, not the upload creation Uri. In most cases, there is no
    // difference between those two but there may be cases in which the POST
    // request is redirected.
    Uri uploadURL = response.redirects.last.location.replace(path: urlStr);

    if (resumingEnabled) {
      urlStore.set(upload.fingerprint, uploadURL);
    }

    return TusUploader(this, upload, uploadURL, 0);
  }

  /// Try to resume an already started [upload] returning a [TusUploader] to
  /// upload the file's remaining chunks (manually).
  ///
  /// [TusClient] must be initialized with [urlStore].
  ///
  /// Throws [FingerprintNotFoundException] or [ResumingNotEnabledException]
  /// or [ProtocolException] or [Exception]
  Future<TusUploader> resumeUpload(TusUpload upload) async {
    if (!resumingEnabled) {
      throw ResumingNotEnabledException();
    }

    Uri uploadURL = await urlStore.get(upload.fingerprint);
    if (uploadURL == null) {
      throw FingerprintNotFoundException(upload.fingerprint);
    }

    return await beginOrResumeUploadFromURL(upload, uploadURL);
  }

  /// Try to resume an already started [upload] returning a [TusUploader] to
  /// upload the file's remaining chunks (manually).
  ///
  /// Incontrast to [resumeOrCreateUpload] this method will not create a new
  /// upload.
  ///
  /// [TusClient] must be initialized with [urlStore].
  ///
  /// Throws [FingerprintNotFoundException] or [ResumingNotEnabledException]
  /// or [ProtocolException] or [Exception]
  Future<TusUploader> beginOrResumeUploadFromURL(
      TusUpload upload, Uri uploadURL) async {
    final client = httpClient();
    client.connectionTimeout = Duration(milliseconds: connectTimeout);
    final request = await client.headUrl(uploadCreationURL);
    _addHeaders(request);

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

  /// Try to resume an [upload] using [resumeUpload]. If the method call throws
  /// an [ResumingNotEnabledException] or [FingerprintNotFoundException], a
  /// new upload will be created using [createUpload].
  ///
  /// Throws [ProtocolException] or [Exception]
  Future<TusUploader> resumeOrCreateUpload(TusUpload upload) async {
    try {
      return await resumeUpload(upload);
    } catch (err) {
      if (err is FingerprintNotFoundException ||
          err is ResumingNotEnabledException ||
          (err is ProtocolException && err.response?.statusCode == 404)) {
        return await createUpload(upload);
      }
      throw err;
    }
  }

  /// Set headers used for every HTTP request. Currently, this will add the
  /// Tus-Resumable header and any custom header
  void _addHeaders(HttpClientRequest request) {
    request.headers.add("Tus-Resumable", tusVersion);

    if (headers != null) {
      for (MapEntry<String, String> entry in headers.entries) {
        request.headers.add(entry.key, entry.value);
      }
    }
  }

  /// Actions to be performed after a successful [upload] completion such as
  /// removal from the [urlStore] if [removeFingerprintOnSuccess]
  void uploadFinished(TusUpload upload) {
    if (resumingEnabled && removeFingerprintOnSuccess) {
      urlStore.remove(upload.fingerprint);
    }
  }

  HttpClient httpClient() => HttpClient();
}
