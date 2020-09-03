import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:tus_client/tus_client.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockTusClient extends TusClient {
  final mockHttpClient = MockHttpClient();

  MockTusClient(
    Uri url,
    File file, {
    TusStore store,
    Map<String, String> headers,
    Map<String, String> metadata,
    int maxChunkSize = 512 * 1024,
  }) : super(
          url,
          file,
          store: store,
          headers: headers,
          metadata: metadata,
          maxChunkSize: maxChunkSize,
        );

  http.Client httpClient() => mockHttpClient;
}

main() {
  File file;
  final url = Uri.parse("https://example.com/tus");

  setUpAll(() async {
    file = await _createTestFile("test.txt");
  });

  tearDownAll(() async {
    await _clearTestFile(file);
  });

  test("client_test.TusClient().simple", () async {
    final client = TusClient(url, file);
    expect(client.fingerprint, isNot("test.txt"));
    expect(client.fingerprint, endsWith("test.txt"));
    expect(client.uploadMetadata, equals("filename dGVzdC50eHQ="));
  });

  test("client_test.TusClient().metadata", () async {
    final client = TusClient(url, file, metadata: {"id": "sample"});
    expect(client.fingerprint, isNot("test.txt"));
    expect(client.fingerprint, endsWith("test.txt"));
    expect(client.uploadMetadata, matches(RegExp(r"filename dGVzdC50eHQ=")));
    expect(client.uploadMetadata, matches(RegExp(r"id c2FtcGxl")));
  });

  test("client_test.TusClient().metadata.filename", () async {
    final client = TusClient(url, file,
        metadata: {"id": "sample", "filename": "another-name.txt"});
    expect(client.fingerprint, isNot("test.txt"));
    expect(client.fingerprint, endsWith("test.txt"));
    expect(client.uploadMetadata,
        matches(RegExp(r"filename YW5vdGhlci1uYW1lLnR4dA==")));
    expect(client.uploadMetadata, matches(RegExp(r"id c2FtcGxl")));
  });

  test('client_test.TusClient.create()', () async {
    final client = MockTusClient(url, file);
    final uploadLocation =
        "https://example.com/tus/1ae64b4f-bd7a-410b-893d-3614a4bd68a6";
    when(client.mockHttpClient.post(url, headers: anyNamed('headers')))
        .thenAnswer((_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));

    await client.create();

    expect(client.uploadUrl.toString(), equals(uploadLocation));
  });

  test('client_test.TusClient.create().failure', () async {
    final client = MockTusClient(url, file);
    when(client.mockHttpClient.post(url, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response("500 Server Error", 500));

    await client.create();

    expect(client.uploadUrl, isNull);
  });

  test('client_test.TusClient.resume()', () async {
    final client = MockTusClient(Uri.parse("https://example.com/tus"), file);

    final mockHttpClient = MockHttpClient();

    // when(mockHttpClientResponse.statusCode).thenReturn(201);
    // when(mockHttpClientResponse.redirects).thenReturn([mockRedirectInfo]);
    // when(mockHttpClientResponse.headers).thenReturn(mockHttpResponseHeaders);

    // when(mockHttpClientRequest.close()).thenAnswer(
    //   (_) async => mockHttpClientResponse,
    // );
    // when(mockHttpClientRequest.headers).thenReturn(mockHttpHeaders);

    // when(mockHttpClient.postUrl(any)).thenAnswer(
    //   (_) async => mockHttpClientRequest,
    // );
    // client.mockHttpClient = mockHttpClient;

    // final uploader = await client.create();
    // expect(uploader.uploadURL.toString(), "https://example.com/files");
  });
}

Future<File> _createTestFile(String name) async {
  final f = File(name);
  await f.writeAsBytes(List.generate(100, (index) => index >= 50 ? 1 : 0));
  return f;
}

Future _clearTestFile(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}
