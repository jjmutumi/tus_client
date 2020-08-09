import 'package:tus_client/src/upload.dart';

import 'client.dart';
import 'exceptions.dart';
import 'uploader.dart';

/// TusExecutor is a wrapper class which you can build around your uploading
/// mechanism and any exception thrown by it will be caught and may result in
/// a retry. This way you can easily add retrying functionality to your
/// application with defined delays between them.
///
/// This can be achieved by extending TusExecutor and implementing the abstract
/// makeAttempt() method:
///
///     class MyExecutor extends TusExecutor {
///         @override
///         Future<void> makeAttempt() async {
///             TusUploader uploader = await client.resumeOrCreateUpload(upload);
///             while(await uploader.uploadChunk()) {}
///             uploader.finish();
///         }
///     }
///     final executor = MyExecutor();
///     await executor.makeAttempts();
///
/// The retries are basically just calling the [makeAttempt] method which
/// should then retrieve an [TusUploader] using [TusClient.resumeOrCreateUpload]
/// and then invoke [TusUploader.uploadChunk] without catching
/// [ProtocolException] or [Exception] as this is taken over by this class.
abstract class TusExecutor {
  /// Delays in milliseconds
  List<int> delays = [500, 1000, 2000, 3000];

  /// This method is basically just calling the [makeAttempt] which should then
  /// retrieve an [TusUploader] using [TusClient.resumeOrCreateUpload] and then
  /// invoke[TusUploader.uploadChunk]
  /// Throws [ProtocolException] [IOException]
  Future<bool> makeAttempts(TusUpload upload) async {
    int attempt = -1;
    while (true) {
      attempt++;

      try {
        await makeAttempt(upload);
        // Returning true is the signal that the makeAttempt() function exited without
        // throwing an error.
        return true;
      } catch (err, trace) {
        // Do not attempt a retry, if the Exception suggests so.
        if (err is ProtocolException && !err.shouldRetry()) {
          rethrow;
        }

        if (attempt >= delays.length) {
          // We exceeds the number of maximum retries. In this case the latest exception
          // is thrown.
          rethrow;
        }
      }

      // Sleep for the specified delay before attempting the next retry.
      await Future.delayed(Duration(milliseconds: delays[attempt]));
    }
  }

  /// This method must be implemented by the specific caller. It will be invoked once or multiple
  /// times
  Future<void> makeAttempt(TusUpload upload);
}

class TusMainExecutor extends TusExecutor {
  final TusClient client;
  final void Function(TusUpload upload, double progress) onProgress;
  final void Function(TusUpload upload) onComplete;

  TusMainExecutor(
    this.client, {
    this.onProgress,
    this.onComplete,
  });

  @override
  Future<void> makeAttempt(TusUpload upload) async {
    // First try to resume an upload. If that's not possible we will create a new
    // upload and get a TusUploader in return. This class is responsible for opening
    // a connection to the remote server and doing the uploading.
    final uploader = await client.resumeOrCreateUpload(upload);

    // Upload the file as long as data is available. Once the
    // file has been fully uploaded the method will return true
    do {
      // Calculate the progress using the total size of the uploading file and
      // the current offset.
      int totalBytes = upload.size;
      int bytesUploaded = uploader.offset;
      double progress = bytesUploaded / totalBytes * 100;
      if (onProgress != null) {
        onProgress(upload, progress);
      }
    } while (!(await uploader.uploadChunk()));

    // Allow cleaned up
    uploader.finish();

    if (onComplete != null) {
      onComplete(upload);
    }
  }
}
