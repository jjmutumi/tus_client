import 'dart:convert' show base64, jsonEncode, utf8;
import 'dart:math' show min;
import 'dart:typed_data' show Uint8List, BytesBuilder;
import 'exceptions.dart';
import 'store.dart';

import 'package:cross_file/cross_file.dart' show XFile;
import 'package:http/http.dart' as http;
import "package:path/path.dart" as p;

/// This class is used for creating or resuming uploads.
class TusClient {
  /// Version of the tus protocol used by the client. The remote server needs to
  /// support this version, too.
  static final tusVersion = "1.0.0";

  /// The tus server Uri
  final Uri url;

  /// Storage used to save and retrieve upload URLs by its fingerprint.
  final TusStore? store;

  final XFile? file;

  final Stream<List<int>>? fileStream;

  final Map<String, String>? metadata;

  /// Any additional headers
  final Map<String, String>? headers;

  //body for POST initialization request
  final Map<String, dynamic>? body;

  /// The maximum payload size in bytes when uploading the file in chunks (512KB)
  final int maxChunkSize;

  int? fileSize;

  String _fingerprint = "";

  String? _uploadMetadata;

  Uri? uploadUrl;

  int? _offset;

  bool _pauseUpload = false;

  Future? _chunkPatchFuture;

  TusClient(
    this.url, {
    this.file,
    this.fileStream,
    this.store,
    this.headers,
    this.metadata = const {},
    this.maxChunkSize = 512 * 1024,
    this.body,
  }) {
    _fingerprint = generateFingerprint() ?? "";
    _uploadMetadata = generateMetadata();
  }

  /// Whether the client supports resuming
  bool get resumingEnabled => store != null;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";

  /// Override this method to use a custom Client
  http.Client getHttpClient() => http.Client();

  /// Create a new [upload] throwing [ProtocolException] on server error

  /// Start or resume an upload in chunks of [maxChunkSize] throwing
  /// [ProtocolException] on server error
  upload({
    Function(double)? onProgress,
    Function()? onComplete,
  }) async {
    // get offset from server
    _offset = await _getOffset();

    int totalBytes = fileSize as int;

    // start upload
    final client = getHttpClient();

    while (!_pauseUpload && (_offset ?? 0) < totalBytes) {
      final uploadHeaders = Map<String, String>.from(headers ?? {})
        ..addAll({
          "Tus-Resumable": tusVersion,
          "Upload-Offset": "$_offset",
          "Content-Type": "application/offset+octet-stream"
        });
      if(file != null){
        _chunkPatchFuture = client.patch(
          uploadUrl as Uri,
          headers: uploadHeaders,
          body: await _getData(),
        );
      }else if(fileStream != null){
        int start = _offset ?? 0;
        int end = (_offset ?? 0) + maxChunkSize;
        end = end > (fileSize ?? 0) ? fileSize ?? 0 : end;

        final result = BytesBuilder();
        await for (final chunk in fileStream!) {
          result.add(chunk);
        }

        final bytesRead = min(maxChunkSize, result.length);
        _offset = (_offset ?? 0) + bytesRead;

        return result.takeBytes();


      }else{
        throw Error();
      }

      final response = await _chunkPatchFuture;
      _chunkPatchFuture = null;

      // check if correctly uploaded
      if (!(response.statusCode >= 200 && response.statusCode < 300)) {
        throw ProtocolException(
            "unexpected status code (${response.statusCode}) while uploading chunk");
      }

      int? serverOffset = _parseOffset(response.headers["upload-offset"]);
      if (serverOffset == null) {
        throw ProtocolException(
            "response to PATCH request contains no or invalid Upload-Offset header");
      }
      if (_offset != serverOffset) {
        throw ProtocolException(
            "response contains different Upload-Offset value ($serverOffset) than expected ($_offset)");
      }

      // update progress
      if (onProgress != null) {
        onProgress((_offset ?? 0) / totalBytes * 100);
      }

      if (_offset == totalBytes) {
        this.onComplete();
        if (onComplete != null) {
          onComplete();
        }
      }
    }
  }

  /// Pause the current upload
  pause() {
    _pauseUpload = true;
    _chunkPatchFuture?.timeout(Duration.zero, onTimeout: () {});
  }

  /// Actions to be performed after a successful upload
  void onComplete() {
    store?.remove(_fingerprint);
  }

  /// Override this method to customize creating file fingerprint
  String? generateFingerprint() {
    return file!.path.replaceAll(RegExp(r"\W+"), '.');
  }

  /// Override this to customize creating 'Upload-Metadata'
  String generateMetadata() {
    final meta = Map<String, String>.from(metadata ?? {});

    if (!meta.containsKey("filename")) {
      meta["filename"] = p.basename(file!.path);
    }

    return meta.entries
        .map((entry) => entry.key + " " + base64.encode(utf8.encode(entry.value)))
        .join(",");
  }

  /// Get offset from server throwing [ProtocolException] on error
  Future<int> _getOffset() async {
    final client = getHttpClient();

    final offsetHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({
        "Tus-Resumable": tusVersion,
      });
    final response = await client.head(uploadUrl as Uri, headers: offsetHeaders);

    if (!(response.statusCode >= 200 && response.statusCode < 300)) {
      throw ProtocolException(
          "unexpected status code (${response.statusCode}) while resuming upload");
    }

    int? serverOffset = _parseOffset(response.headers["upload-offset"]);
    if (serverOffset == null) {
      throw ProtocolException("missing upload offset in response for resuming upload");
    }
    return serverOffset;
  }

  /// Get data from file to upload

  Future<Uint8List> _getData() async {
    int start = _offset ?? 0;
    int end = (_offset ?? 0) + maxChunkSize;
    end = end > (fileSize ?? 0) ? fileSize ?? 0 : end;

    final result = BytesBuilder();
    await for (final chunk in file!.openRead(start, end)) {
      result.add(chunk);
    }

    final bytesRead = min(maxChunkSize, result.length);
    _offset = (_offset ?? 0) + bytesRead;

    return result.takeBytes();
  }

  int? _parseOffset(String? offset) {
    if (offset == null || offset.isEmpty) {
      return null;
    }
    if (offset.contains(",")) {
      offset = offset.substring(0, offset.indexOf(","));
    }
    return int.tryParse(offset);
  }

  Uri _parseUrl(String urlStr) {
    if (urlStr.contains(",")) {
      urlStr = urlStr.substring(0, urlStr.indexOf(","));
    }
    Uri uploadUrl = Uri.parse(urlStr);
    if (uploadUrl.host.isEmpty) {
      uploadUrl = uploadUrl.replace(host: url.host, port: url.port);
    }
    if (uploadUrl.scheme.isEmpty) {
      uploadUrl = uploadUrl.replace(scheme: url.scheme);
    }
    return uploadUrl;
  }
}
