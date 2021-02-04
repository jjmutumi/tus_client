import 'package:flutter_test/flutter_test.dart';
import 'package:tus_client/tus_client.dart';

main() {
  test("exceptions_test.ProtocolException", () {
    final err = ProtocolException("Expected HEADER 'Tus-Resumable'");
    expect(
        "$err",
        "ProtocolException: "
            "Expected HEADER 'Tus-Resumable'");
  });

  test("exceptions_test.ProtocolException.response.shouldRetry", () {
    final err = ProtocolException("Expected HEADER 'Tus-Resumable'");
    expect(
        "$err",
        "ProtocolException: "
            "Expected HEADER 'Tus-Resumable'");
  });

  test("exceptions_test.ProtocolException.response.shouldNotRetry", () {
    final err = ProtocolException("Expected HEADER 'Tus-Resumable'");
    expect(
        "$err",
        "ProtocolException: "
            "Expected HEADER 'Tus-Resumable'");
  });
}
