import 'client.dart';
import 'dart:io' show HttpClientResponse;

/// This exception is thrown if the server sends a request with an unexpected
/// status code or missing/invalid headers.
class ProtocolException implements Exception {
  final String message;
  final HttpClientResponse response;

  ProtocolException(this.message, [this.response]);

  bool shouldRetry() =>
      response != null &&
      ((response.statusCode >= 500 && response.statusCode < 600) ||
          response.statusCode == 423);

  String toString() => "ProtocolException: $message";
}

/// This exception is thrown by [TusClient.resumeUpload] if no upload Uri
/// has been stored in the [TusClient.urlStore]
class FingerprintNotFoundException implements Exception {
  final String fingerprint;

  FingerprintNotFoundException(this.fingerprint);

  String toString() => "FingerprintNotFoundException: "
      "fingerprint not in storage found: $fingerprint";
}

/// This exception is thrown when you try to resume an upload using
/// [TusClient.resumeUpload] without configuring a [TusClient.urlStore].
class ResumingNotEnabledException implements Exception {
  ResumingNotEnabledException();

  String toString() => "ResumingNotEnabledException: "
      "resuming not enabled for this client, set a urlStore to do so";
}
