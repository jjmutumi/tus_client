import 'package:http/http.dart';

/// This exception is thrown if the server sends a request with an unexpected
/// status code or missing/invalid headers.
class ProtocolException implements Exception {
  final String message;
  final Response? response;

  ProtocolException(this.message, {this.response});

  String toString() => "ProtocolException: $message";
}
