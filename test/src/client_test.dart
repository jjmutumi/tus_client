import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tus_client/tus_client.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockRedirectInfo extends Mock implements RedirectInfo {}

class MockTusUpload extends Mock implements TusUpload {}

class MockHttpHeaders extends Fake implements HttpHeaders {
  Map<String, String> _headers = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = "$value";
  }

  @override
  String value(String name) {
    return _headers[name];
  }
}

class MockTusClient extends TusClient {
  MockHttpClient mockHttpClient;

  MockTusClient(Uri uploadCreationURL) : super(uploadCreationURL);

  HttpClient httpClient() => mockHttpClient;
}

main() {
  test('client_test.TusClient.createUpload', () async {
    final client = MockTusClient(Uri.parse("https://example.com/tus"));

    final mockHttpClient = MockHttpClient();
    final mockHttpClientRequest = MockHttpClientRequest();
    final mockHttpHeaders = MockHttpHeaders();
    final mockHttpResponseHeaders = MockHttpHeaders();
    final mockHttpClientResponse = MockHttpClientResponse();
    final mockRedirectInfo = MockRedirectInfo();

    mockHttpResponseHeaders.add("Location", "/files");
    when(mockRedirectInfo.location).thenReturn(
      Uri.parse("https://example.com/tus"),
    );
    when(mockHttpClientResponse.statusCode).thenReturn(201);
    when(mockHttpClientResponse.redirects).thenReturn([mockRedirectInfo]);
    when(mockHttpClientResponse.headers).thenReturn(mockHttpResponseHeaders);

    when(mockHttpClientRequest.close()).thenAnswer(
      (_) async => mockHttpClientResponse,
    );
    when(mockHttpClientRequest.headers).thenReturn(mockHttpHeaders);

    when(mockHttpClient.postUrl(any)).thenAnswer(
      (_) async => mockHttpClientRequest,
    );
    client.mockHttpClient = mockHttpClient;

    final upload = MockTusUpload();
    when(upload.metadata).thenReturn("filename: pic.jpg");

    final uploader = await client.createUpload(upload);
    expect(uploader.uploadURL.toString(), "https://example.com/files");
  });
}
