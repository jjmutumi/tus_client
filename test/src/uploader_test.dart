import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tus_client/tus_client.dart';

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

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

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  MockHttpClientResponse mockHttpResponse;
  final _headers = MockHttpHeaders();
  final List<int> data = [];

  HttpHeaders get headers => _headers;

  @override
  void add(List<int> data) {
    this.data.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() async {
    return mockHttpResponse;
  }
}

class MockHttpClient extends Fake implements HttpClient {
  MockHttpClientRequest mockHttpRequest;

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async {
    return mockHttpRequest;
  }
}

class MockTusUploader extends TusUploader {
  MockHttpClient mockHttpClient;

  MockTusUploader(
    TusClient client,
    TusUpload upload,
    Uri uploadURL,
    int offset,
  ) : super(client, upload, uploadURL, offset);

  HttpClient httpClient() => mockHttpClient;
}

class MockTusUpload extends Mock implements TusUpload {}

class MockTusClient extends Mock implements TusClient {}

main() {
  test('uploader_test.TusUploader', () async {
    final httpRequest = MockHttpClientRequest();
    final httpResponse = MockHttpClientResponse();
    final httpClient = MockHttpClient();
    final upload = MockTusUpload();
    final client = MockTusClient();

    final data = utf8.encode("hello world");

    when(upload.size).thenReturn(data.length);
    when(upload.readInto(any, any)).thenAnswer((inv) async {
      final Uint8List buffer = inv.positionalArguments[0];
      final offset = inv.positionalArguments[1];
      int len = min(data.length - offset, buffer.length);
      data
          .sublist(offset, offset + len)
          .asMap()
          .forEach((i, e) => buffer[i] = e);
      return len;
    });

    final httpResponseHeaders = MockHttpHeaders();
    httpResponseHeaders.add("Upload-Offset", 11);
    when(httpResponse.statusCode).thenReturn(201);
    when(httpResponse.headers).thenReturn(httpResponseHeaders);

    httpRequest.mockHttpResponse = httpResponse;
    httpClient.mockHttpRequest = httpRequest;

    final uploader = MockTusUploader(
      client,
      upload,
      Uri.parse("https://example.com/tus"),
      0,
    );
    uploader.payloadSize = 5;
    uploader.mockHttpClient = httpClient;

    bool done = await uploader.uploadChunk();
    expect(done, false);
    expect(utf8.decode(httpRequest.data), startsWith("hello"));

    done = await uploader.uploadChunk();
    expect(done, false);
    expect(utf8.decode(httpRequest.data), startsWith("hello worl"));

    done = await uploader.uploadChunk();
    expect(done, true);
    expect(utf8.decode(httpRequest.data), startsWith("hello world"));
  });
}
