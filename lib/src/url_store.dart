/// Implementations of this interface are used to map an upload's fingerprint with the corresponding
/// upload Uri. This functionality is used to allow resuming uploads. The fingerprint is usually
/// retrieved using [TusUpload.getFingerprint]
/// See [TusURLMemoryStore]
abstract class TusURLStore {
  /// Store a new [fingerprint] and its upload [url].
  void set(String fingerprint, Uri url);

  /// Retrieve an upload's Uri for a [fingerprint]. If no matching entry is found this method will
  /// return `null`.
  Uri get(String fingerprint);

  /// Remove an entry from the store using an upload's [fingerprint].
  void remove(String fingerprint);
}

/// This class is used to map an upload's fingerprint with the corresponding upload Uri by storing
/// the entries in a [Map]. This functionality is used to allow resuming uploads. The
/// fingerprint is usually retrieved using [TusUpload.getFingerprint].
///
/// The values will only be stored as int as the application is running. This store will not
/// keep the values after your application crashes or restarts.
class TusURLMemoryStore implements TusURLStore {
  Map<String, Uri> store = {};

  @override
  void set(String fingerprint, Uri url) {
    store[fingerprint] = url;
  }

  @override
  Uri get(String fingerprint) {
    return store[fingerprint];
  }

  @override
  void remove(String fingerprint) {
    store.remove(fingerprint);
  }
}
