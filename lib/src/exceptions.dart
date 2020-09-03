import 'client.dart';

/// This exception is thrown if the server sends a request with an unexpected
/// status code or missing/invalid headers.
class ProtocolException implements Exception {
  final String message;

  ProtocolException(this.message);

  String toString() => "ProtocolException: $message";
}

/// This exception is thrown by [TusClient.resumeUpload] if no upload Uri
/// has been stored in the [TusClient.store]
class FingerprintNotFoundException implements Exception {
  final String fingerprint;

  FingerprintNotFoundException(this.fingerprint);

  String toString() => "FingerprintNotFoundException: "
      "fingerprint not in storage found: $fingerprint";
}

/// This exception is thrown when you try to resume an upload using
/// [TusClient.resumeUpload] without configuring a [TusClient.store].
class ResumingNotEnabledException implements Exception {
  ResumingNotEnabledException();

  String toString() => "ResumingNotEnabledException: "
      "resuming not enabled for this client, set a store to do so";
}
