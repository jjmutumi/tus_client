import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tus_client/tus_client.dart';

main() {
  test("upload_test.TusUpload", () async {
    final file = await _createTestFile("test.txt");
    try {
      final upload = TusUpload();
      expect(upload.size, isNull);
      expect(upload.fingerprint, isNull);
      expect(upload.metadata, "");

      await upload.initialize(file, metadata: {"id": "sample"});
      expect(upload.size, 100);
      expect(upload.fingerprint, isNot("test.txt-100"));
      expect(upload.fingerprint, endsWith("test.txt-100"));
      expect(upload.metadata, matches(RegExp(r"filename \w+=*")));
      expect(upload.metadata, matches(RegExp(r"id c2FtcGxl")));

      var buffer = Uint8List(7);
      int bytesRead = await upload.readInto(buffer, 45);
      expect(bytesRead, 7);
      expect(buffer, [0, 0, 0, 0, 0, 1, 1]);

      buffer = Uint8List(7);
      bytesRead = await upload.readInto(buffer, 98);
      expect(bytesRead, 2);
      expect(buffer, [1, 1, 0, 0, 0, 0, 0]);
    } finally {
      await _clearTestFile(file);
    }
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
