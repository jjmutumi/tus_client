import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:tus_client/tus_client.dart';

class MockTusUploader extends Mock implements TusUploader {}

class MockTusUpload extends Mock implements TusUpload {}

class MockTusClient extends Fake implements TusClient {
  MockTusUploader mockUploader;

  @override
  Future<TusUploader> resumeOrCreateUpload(TusUpload upload) async {
    return mockUploader;
  }
}

main() {
  test('executor_test.TusMainExecutor', () async {
    final client = MockTusClient();
    final uploader = MockTusUploader();
    final upload = MockTusUpload();

    int called = 0;
    when(uploader.offset).thenAnswer((_) => (called++) * 100);
    when(uploader.uploadChunk()).thenAnswer((_) async => called == 10);
    when(uploader.finish()).thenAnswer((_) async => null);
    when(upload.size).thenReturn(1000);

    client.mockUploader = uploader;

    final executor = TusMainExecutor(client);
    await executor.makeAttempts(upload);

    verify(uploader.uploadChunk()).called(10);
  });
}
