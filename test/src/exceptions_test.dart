import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tus_client/tus_client.dart';

class MockResponse extends Mock implements HttpClientResponse {}

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
            "resuming not enabled for this client, set a urlStore to do so");
  });

  test("exceptions_test.ProtocolException", () {
    final err = ProtocolException("Expected HEADER 'TUS_VERSION'");
    expect(
        "$err",
        "ProtocolException: "
            "Expected HEADER 'TUS_VERSION'");
    expect(err.shouldRetry(), false);
  });

  test("exceptions_test.ProtocolException.response.shouldRetry", () {
    final response = MockResponse();
    when(response.statusCode).thenReturn(506);

    final err = ProtocolException("Expected HEADER 'TUS_VERSION'", response);
    expect(
        "$err",
        "ProtocolException: "
            "Expected HEADER 'TUS_VERSION'");
    expect(err.shouldRetry(), true);
  });

  test("exceptions_test.ProtocolException.response.shouldNotRetry", () {
    final response = MockResponse();
    when(response.statusCode).thenReturn(401);

    final err = ProtocolException("Expected HEADER 'TUS_VERSION'", response);
    expect(
        "$err",
        "ProtocolException: "
            "Expected HEADER 'TUS_VERSION'");
    expect(err.shouldRetry(), false);
  });
}
