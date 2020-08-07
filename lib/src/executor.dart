// import 'client.dart';
import 'exceptions.dart';
import 'uploader.dart';

/// TusExecutor is a wrapper class which you can build around your uploading mechanism and any
/// exception thrown by it will be caught and may result in a retry. This way you can easily add
/// retrying functionality to your application with defined delays between them.
/// This can be achieved by extending TusExecutor and implementing the abstract makeAttempt() method:
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
/// The retries are basically just calling the [makeAttempt()] method which should then
/// retrieve an [TusUploader] using [TusClient.resumeOrCreateUpload()] and then
/// invoke [TusUploader.uploadChunk()] as int as possible without catching
/// [ProtocolException] or [Exception] as this is taken over by this class.
abstract class TusExecutor {
  /// Delays in milliseconds
  List<int> delays = [500, 1000, 2000, 3000];

  /// This method is basically just calling the [makeAttempt()] which should then
  /// retrieve an [TusUploader] using [TusClient.resumeOrCreateUpload()] and then
  /// invoke[TusUploader.uploadChunk()]
  /// Throws [ProtocolException] [IOException]
  Future<bool> makeAttempts() async {
    int attempt = -1;
    while (true) {
      attempt++;

      try {
        await makeAttempt();
        // Returning true is the signal that the makeAttempt() function exited without
        // throwing an error.
        return true;
      } catch (err) {
        // Do not attempt a retry, if the Exception suggests so.
        if (err is ProtocolException && !err.shouldRetry()) {
          throw err;
        }

        if (attempt >= delays.length) {
          // We exceeds the number of maximum retries. In this case the latest exception
          // is thrown.
          throw err;
        }
      }

      // Sleep for the specified delay before attempting the next retry.
      await Future.delayed(Duration(milliseconds: delays[attempt]));
    }
  }

  /// This method must be implemented by the specific caller. It will be invoked once or multiple
  /// times
  Future<void> makeAttempt();
}
