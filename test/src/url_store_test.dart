import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tus_client/tus_client.dart';

main() {
  final fingerprint = "test";
  final url = "https://example.com/files/pic.jpg?token=987298374";
  final uri = Uri.parse(url);
  group('url_store:TusURLMemoryStore', () {
    test("set", () async {
      TusURLMemoryStore store = TusURLMemoryStore();
      await store.set(fingerprint, uri);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, uri);
    });

    test("get.empty", () async {
      TusURLMemoryStore store = TusURLMemoryStore();
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    test("remove", () async {
      TusURLMemoryStore store = TusURLMemoryStore();
      await store.set(fingerprint, uri);
      await store.remove(fingerprint);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    test("remove.empty", () async {
      TusURLMemoryStore store = TusURLMemoryStore();
      var foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
      await store.remove(fingerprint);
      foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });
  });

  group('url_store:TusURLFileStore', () {
    final directory = Directory("test-dir");

    test("set", () async {
      TusURLFileStore store = TusURLFileStore(directory);
      await store.set(fingerprint, uri);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, uri);
    });

    test("get.empty", () async {
      TusURLFileStore store = TusURLFileStore(directory);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    test("remove", () async {
      TusURLFileStore store = TusURLFileStore(directory);
      await store.set(fingerprint, uri);
      await store.remove(fingerprint);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    test("remove.empty", () async {
      TusURLFileStore store = TusURLFileStore(directory);
      var foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
      await store.remove(fingerprint);
      foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });
  });
}
