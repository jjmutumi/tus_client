import 'client.dart';

/// This exception is thrown if the server sends a request with an unexpected
/// status code or missing/invalid headers.
class ProtocolException implements Exception {
  final String message;

  ProtocolException(this.message);

  String toString() => "ProtocolException: $message";
}
