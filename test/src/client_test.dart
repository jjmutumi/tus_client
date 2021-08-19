import 'dart:io';

import 'package:cross_file/cross_file.dart' show XFile;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tus_client/tus_client.dart';
import 'client_test.mocks.dart';

class MockTusClient extends TusClient {
  MockClient? httpClient;

  MockTusClient(
    Uri url,
    XFile file, {
    TusStore? store,
    Map<String, String>? headers,
    Map<String, String>? metadata,
    int maxChunkSize = 512 * 1024,
  }) : super(
          url,
          file,
          store: store,
          headers: headers,
          metadata: metadata,
          maxChunkSize: maxChunkSize,
        ) {
    httpClient = MockClient();
  }

  @override
  http.Client getHttpClient() => httpClient as http.Client;
}

@GenerateMocks([http.Client])
main() {
  XFile file = _createTestFile("test.txt");
  final url = Uri.parse("https://example.com/tus");
  final uploadLocation =
      "https://example.com/tus/1ae64b4f-bd7a-410b-893d-3614a4bd68a6";
  final urlWithPort = Uri.parse("https://example.com:1234/tus");
  final uploadLocationWithPort =
      "https://example.com:1234/tus/1ae64b4f-bd7a-410b-893d-3614a4bd68a6";

  setUpAll(() {
    file = _createTestFile("test.txt");
  });

  tearDownAll(() {
    _clearTestFile("test.txt");
  });

  test("client_test.TusClient()", () async {
    final client = MockTusClient(url, file);
    // expect(client.fingerprint, isNot("test.txt"));
    expect(client.fingerprint, endsWith("test.txt"));
    expect(client.uploadMetadata, equals("filename dGVzdC50eHQ="));
  });

  test("client_test.TusClient().metadata", () async {
    final client = MockTusClient(url, file, metadata: {"id": "sample"});

    // expect(client.fingerprint, isNot("test.txt"));
    expect(client.fingerprint, endsWith("test.txt"));
    expect(client.uploadMetadata, matches(RegExp(r"filename dGVzdC50eHQ=")));
    expect(client.uploadMetadata, matches(RegExp(r"id c2FtcGxl")));
  });

  test("client_test.TusClient().metadata.filename", () async {
    final client = MockTusClient(url, file,
        metadata: {"id": "sample", "filename": "another-name.txt"});

    // expect(client.fingerprint, isNot("test.txt"));
    expect(client.fingerprint, endsWith("test.txt"));
    expect(client.uploadMetadata,
        matches(RegExp(r"filename YW5vdGhlci1uYW1lLnR4dA==")));
    expect(client.uploadMetadata, matches(RegExp(r"id c2FtcGxl")));
  });

  test('client_test.TusClient.create()', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));

    await client.create();

    expect(client.uploadUrl.toString(), equals(uploadLocation));
    expect(
        verify(client.httpClient
                ?.post(url, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.create().no.scheme', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 201, headers: {
              "location":
                  "//example.com/tus/1ae64b4f-bd7a-410b-893d-3614a4bd68a6"
            }));

    await client.create();

    expect(client.uploadUrl.toString(), equals(uploadLocation));
    expect(
        verify(client.httpClient
                ?.post(url, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.create().no.host', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 201, headers: {
              "location": "/tus/1ae64b4f-bd7a-410b-893d-3614a4bd68a6"
            }));

    await client.create();

    expect(client.uploadUrl.toString(), equals(uploadLocation));
    expect(
        verify(client.httpClient
                ?.post(url, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.create().no.host.with.port', () async {
    final client = MockTusClient(urlWithPort, file);
    when(client.httpClient?.post(urlWithPort, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response("", 201, headers: {
              "location": "/tus/1ae64b4f-bd7a-410b-893d-3614a4bd68a6"
            }));

    await client.create();

    expect(client.uploadUrl.toString(), equals(uploadLocationWithPort));
    expect(
        verify(client.httpClient
                ?.post(urlWithPort, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.create().double.header', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 201,
            headers: {"location": "$uploadLocation,$uploadLocation"}));

    await client.create();

    expect(client.uploadUrl.toString(), equals(uploadLocation));
    expect(
        verify(client.httpClient
                ?.post(url, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.create().failure.empty.location', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 201, headers: {"location": ""}));

    expectLater(
        () => client.create(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'missing upload Uri in response for creating upload')));
  });

  test('client_test.TusClient.create().failure.server.error', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response("500 Server Error", 500));

    expectLater(
        () => client.create(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'unexpected status code (500) while creating upload')));
  });

  test('client_test.TusClient.resume()', () async {
    final store = TusMemoryStore();
    final client = MockTusClient(url, file, store: store);
    store.set(client.fingerprint, Uri.parse(uploadLocation));

    await client.resume();

    expect(client.uploadUrl.toString(), equals(uploadLocation));
  });

  test('client_test.TusClient.resume().failure.no.store', () async {
    final client = MockTusClient(url, file);

    expect(await client.resume(), false);
  });

  test('client_test.TusClient.resume().failure.finger.not.found', () async {
    final client = MockTusClient(url, file, store: TusMemoryStore());

    expect(await client.resume(), false);
  });

  test('client_test.TusClient.upload()', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 200, headers: {"upload-offset": "0"}));
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer(
        (_) async => http.Response("", 204, headers: {"upload-offset": "100"}));

    bool success = false;
    double? progress;
    await client.upload(
        onComplete: () => success = true, onProgress: (p) => progress = p);

    expect(success, isTrue);
    expect(progress, equals(100));
    expect(
        verify(client.httpClient
                ?.post(any, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
    expect(
        verify(client.httpClient
                ?.head(any, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
    expect(
        verify(client.httpClient?.patch(any,
                headers: captureAnyNamed('headers'), body: anyNamed('body')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.upload().double.header', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 200, headers: {"upload-offset": "0,0"}));
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer((_) async =>
        http.Response("", 204, headers: {"upload-offset": "100,100"}));

    bool success = false;
    double? progress;
    await client.upload(
        onComplete: () => success = true, onProgress: (p) => progress = p);

    expect(success, isTrue);
    expect(progress, equals(100));
    expect(
        verify(client.httpClient
                ?.post(any, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
    expect(
        verify(client.httpClient
                ?.head(any, headers: captureAnyNamed('headers')))
            .captured
            .first,
        contains('Tus-Resumable'));
    expect(
        verify(client.httpClient?.patch(any,
                headers: captureAnyNamed('headers'), body: anyNamed('body')))
            .captured
            .first,
        contains('Tus-Resumable'));
  });

  test('client_test.TusClient.upload().pause', () async {
    final client = MockTusClient(url, file, maxChunkSize: 50);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 200, headers: {"upload-offset": "0"}));
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer((_) async {
      client.pause();
      return http.Response("", 204, headers: {"upload-offset": "50"});
    });

    bool success = false;
    double? progress;
    await client.upload(
        onComplete: () => success = true, onProgress: (p) => progress = p);

    expect(success, isFalse);
    expect(progress, equals(50));
  });

  test('client_test.TusClient.upload().chunks', () async {
    final client = MockTusClient(url, file, maxChunkSize: 50);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 200, headers: {"upload-offset": "0"}));
    int i = 0;
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer((_) async {
      final offset = (++i) * 50;
      return http.Response("", 204, headers: {"upload-offset": "$offset"});
    });

    bool success = false;
    double? progress;
    await client.upload(
        onComplete: () => success = true, onProgress: (p) => progress = p);

    expect(success, isTrue);
    expect(progress, equals(100));
  });

  test('client_test.TusClient.upload().offset.failure.server.error', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers')))
        .thenAnswer((_) async => http.Response("500 Server Error", 500));

    expectLater(
        () => client.upload(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'unexpected status code (500) while resuming upload')));
  });

  test('client_test.TusClient.upload().offset.failure.missing', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 204, headers: {"upload-offset": ""}));
    when(client.httpClient?.patch(any, headers: anyNamed('headers')))
        .thenAnswer((_) async =>
            http.Response("", 204, headers: {"upload-offset": ""}));

    expectLater(
        () => client.upload(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'missing upload offset in response for resuming upload')));
  });

  test('client_test.TusClient.upload().patch.failure.server.error', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 204, headers: {"upload-offset": "0"}));
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer((_) async => http.Response("500 Server Error", 500));

    expectLater(
        () => client.upload(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'unexpected status code (500) while uploading chunk')));
  });

  test('client_test.TusClient.upload().patch.failure.missing.offset', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 204, headers: {"upload-offset": "0"}));
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer((_) async => http.Response("", 204));

    expectLater(
        () => client.upload(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'response to PATCH request contains no or invalid Upload-Offset header')));
  });

  test('client_test.TusClient.upload().patch.failure.wrong.offset', () async {
    final client = MockTusClient(url, file);
    when(client.httpClient?.post(url, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response("", 201, headers: {"location": uploadLocation}));
    when(client.httpClient?.head(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async => http.Response("", 204, headers: {"upload-offset": "0"}));
    when(client.httpClient?.patch(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
    )).thenAnswer(
        (_) async => http.Response("", 204, headers: {"upload-offset": "50"}));

    expectLater(
        () => client.upload(),
        throwsA(predicate((e) =>
            e is ProtocolException &&
            e.message ==
                'response contains different Upload-Offset value (50) than expected (100)')));
  });
}

XFile _createTestFile(String name) {
  final f = File(name);
  f.writeAsBytesSync(List.generate(100, (index) => index >= 50 ? 1 : 0));
  final xf = XFile(f.path);
  return xf;
}

Future _clearTestFile(String name) async {
  final f = File(name);
  if (f.existsSync()) {
    f.deleteSync();
  }
}
