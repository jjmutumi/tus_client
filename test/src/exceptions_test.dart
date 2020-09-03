import 'package:flutter_test/flutter_test.dart';
import 'package:tus_client/tus_client.dart';

main() {
  test("exceptions_test.FingerprintNotFoundException", () {
    final err = FingerprintNotFoundException("test");
    expect(
        "$err",
        "FingerprintNotFoundException: "
            "fingerprint not in storage found: test");
  });

  test("exceptions_test.ResumingNotEnabledException", () {
    final err = ResumingNotEnabledException();
    expect(
        "$err",
        "ResumingNotEnabledException: "
            "resuming not enabled for this client, set a store to do so");
  });

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
