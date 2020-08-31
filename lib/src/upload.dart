import 'dart:convert' show utf8, base64;
import 'dart:io';
import 'dart:typed_data';

import 'client.dart';
import 'uploader.dart';
import "package:path/path.dart" as p;

/// This class contains information about a file which will be uploaded later.
/// Uploading is done using [TusUploader] returned by
/// [TusClient.createUpload], [TusClient.createUpload] and
/// [TusClient.resumeOrCreateUpload].
///
/// Object must be initialized before being used:
///
///     File file;
///     final upload = TusUpload();
///     await upload.initialize(file);
class TusUpload {
  /// File's size in bytes.
  int _size;

  String _fingerprint;

  File _file;

  Map<String, String> _metadata;

  /// Initialize [TusUpload] with [file] whose content should be later uploaded.
  /// [size] and [fingerprint] will be automatically set.
  initialize(File file, {Map<String, String> metadata}) async {
    this._file = file;
    _size = await file.length();
    final path = file.absolute.path.replaceAll(RegExp(r"\W+"), '.');
    _fingerprint = "$path-$_size";
    _metadata = metadata ?? {};
    if (!_metadata.containsKey("filename")) {
      _metadata["filename"] = p.basename(file.path);
    }
  }

  int get size => _size;

  String get fingerprint => _fingerprint;

  /// Reads [Uint8List.length] bytes of [buffer] from [_file] into [buffer]
  /// starting at [offset] returning the actual number of bytes read
  Future<int> readInto(Uint8List buffer, int offset) async {
    final f = await _file.open(mode: FileMode.read);
    await f.setPosition(offset);
    final bytesRead = await f.readInto(buffer);
    await f.close();
    return bytesRead;
  }

  /// Encode the metadata into a string according to the specification, so it
  /// can be used as the value for the Upload-Metadata header.
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
