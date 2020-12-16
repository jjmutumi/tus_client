import 'package:flutter_test/flutter_test.dart';
import 'package:tus_client/tus_client.dart';

main() {
  final fingerprint = "test";
  final url = "https://example.com/files/pic.jpg?token=987298374";
  final uri = Uri.parse(url);
  group('url_store:TusMemoryStore', () {
    test("set", () async {
      TusMemoryStore store = TusMemoryStore();
      await store.set(fingerprint, uri);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, uri);
    });

    test("get.empty", () async {
      TusMemoryStore store = TusMemoryStore();
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    test("remove", () async {
      TusMemoryStore store = TusMemoryStore();
      await store.set(fingerprint, uri);
      await store.remove(fingerprint);
      final foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });

    test("remove.empty", () async {
      TusMemoryStore store = TusMemoryStore();
      var foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
      await store.remove(fingerprint);
      foundUrl = await store.get(fingerprint);
      expect(foundUrl, isNull);
    });
  });
}
