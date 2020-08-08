import 'package:flutter_test/flutter_test.dart';
import 'package:tus_client/tus_client.dart';

main() {
  final fingerprint = "test";
  final url = "https://example.com/files/pic.jpg?token=987298374";
  final uri = Uri.parse(url);

  test("url_store:TusURLMemoryStore.set", () async {
    TusURLMemoryStore store = TusURLMemoryStore();
    await store.set(fingerprint, uri);
    final foundUrl = await store.get(fingerprint);
    expect(foundUrl, uri);
  });

  test("url_store:TusURLMemoryStore.get.empty", () async {
    TusURLMemoryStore store = TusURLMemoryStore();
    final foundUrl = await store.get(fingerprint);
    expect(foundUrl, isNull);
  });

  test("url_store:TusURLMemoryStore.remove", () async {
    TusURLMemoryStore store = TusURLMemoryStore();
    await store.set(fingerprint, uri);
    await store.remove(fingerprint);
    final foundUrl = await store.get(fingerprint);
    expect(foundUrl, isNull);
  });

  test("url_store:TusURLMemoryStore.remove.empty", () async {});
}
