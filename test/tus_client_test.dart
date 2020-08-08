import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tus_client/tus_client.dart';

void main() {
  test('Intializing client', () async {
    final tusClient = TusClient(
      Uri.parse("https://example.com/tus"),
      urlStore: TusURLMemoryStore(),
    );

    final upload = TusUpload();

    // final file = File("/my/pic.jpg");
    // await upload.initialize(file);
    // final executor = TusMainExecutor();
    // await executor.makeAttempt();
  });
}
