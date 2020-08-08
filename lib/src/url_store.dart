import 'dart:io';

import "package:path/path.dart" as p;
import 'upload.dart';

/// Implementations of this interface are used to lookup a
/// [TusUpload.fingerprint] with the corresponding [TusUpload.file].
///
/// This functionality is used to allow resuming uploads.
///
/// See [TusURLMemoryStore] or [TusURLFileStore]
abstract class TusURLStore {
  /// Store a new [fingerprint] and its upload [url].
  Future<void> set(String fingerprint, Uri url);

  /// Retrieve an upload's Uri for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  Future<Uri> get(String fingerprint);

  /// Remove an entry from the store using an upload's [fingerprint].
  Future<void> remove(String fingerprint);
}

/// This class is used to lookup a [TusUpload.fingerprint] with the
/// corresponding [TusUpload.file] entries in a [Map].
///
/// This functionality is used to allow resuming uploads.
///
/// This store **will not** keep the values after your application crashes or
/// restarts.
class TusURLMemoryStore implements TusURLStore {
  Map<String, Uri> store = {};

  @override
  Future<void> set(String fingerprint, Uri url) async {
    store[fingerprint] = url;
  }

  @override
  Future<Uri> get(String fingerprint) async {
    return store[fingerprint];
  }

  @override
  Future<void> remove(String fingerprint) async {
    store.remove(fingerprint);
  }
}

/// This class is used to lookup a [TusUpload.fingerprint] with the
/// corresponding [TusUpload.file] entries in different files on disk.
///
/// This functionality is used to allow resuming uploads.
///
/// This store **will** keep the values after your application crashes or
/// restarts.
class TusURLFileStore implements TusURLStore {
  final Directory directory;

  TusURLFileStore(this.directory);

  @override
  Future<void> set(String fingerprint, Uri url) async {
    final file = await _getFile(fingerprint);
    await file.writeAsString(url.toString());
  }

  @override
  Future<Uri> get(String fingerprint) async {
    final file = await _getFile(fingerprint);
    if (await file.exists()) {
      return Uri.parse(await file.readAsString());
    }
    return null;
  }

  @override
  Future<void> remove(String fingerprint) async {
    final file = await _getFile(fingerprint);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _getFile(fingerprint) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final filePath = p.join(directory.absolute.path, fingerprint);
    return File(filePath);
  }
}
