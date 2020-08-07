import 'dart:convert' show utf8, base64;
import 'dart:io';
import "package:path/path.dart" as p;

/// This class contains information about a file which will be uploaded later. Uploading is not
/// done using this class but using [TusUploader] whose instances are returned by
/// [TusClient.createUpload] [TusClient.createUpload] and
/// [TusClient.resumeOrCreateUpload].
class TusUpload {
  /// File's size in bytes.
  int _size;

  String _fingerprint;

  RandomAccessFile file;
  Map<String, String> _metadata;

  /// Initialize [TusUpload] with [file] whose content should be later uploaded.
  /// [size] and [fingerprint] will be automatically set.
  initialize(File file) async {
    this.file = await file.open(mode: FileMode.read);
    _size = await file.length();
    _fingerprint = "${file.path}-$_size";
    _metadata = {};
    _metadata["filename"] = p.basename(file.path);
  }

  int get size => _size;

  String get fingerprint => _fingerprint;

  /// Encode the metadata into a string according to the specification, so it can be
  /// used as the value for the Upload-Metadata header.
  String get metadata {
    if (_metadata == null || _metadata.isEmpty) {
      return "";
    }

    String encoded = "";

    bool firstElement = true;
    for (MapEntry<String, String> entry in _metadata.entries) {
      if (!firstElement) {
        encoded += ",";
      }

      encoded += entry.key + " " + base64.encode(utf8.encode(entry.value));

      firstElement = false;
    }

    return encoded;
  }
}
