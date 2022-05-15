import 'dart:convert' show base64, utf8;
import 'dart:typed_data' show Uint8List, BytesBuilder;
import 'package:dio/dio.dart';

import 'exceptions.dart';
import 'store.dart';

import 'package:cross_file/cross_file.dart' show XFile;
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

  final XFile file;

  final Map<String, String>? metadata;

  /// Any additional headers
  final Map<String, String>? headers;

  /// The maximum payload size in bytes when uploading the file in chunks (512KB)
  final int maxChunkSize;

  int? _fileSize;

  String _fingerprint = "";

  String? _uploadMetadata;

  Uri? _uploadUrl;

  int? _offset;

  bool _pauseUpload = false;

  Future? _chunkPatchFuture;

  TusClient(
    this.url,
    this.file, {
    this.store,
    this.headers,
    this.metadata = const {},
    this.maxChunkSize = 524288,
  }) {
    _fingerprint = generateFingerprint() ?? "";
    _uploadMetadata = generateMetadata();
  }

  /// Whether the client supports resuming
  bool get resumingEnabled => store != null;

  /// The URI on the server for the file
  Uri? get uploadUrl => _uploadUrl;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";

  /// Override this method to use a custom Client
  Dio getDioClient() => Dio();

  /// Create a new [upload] throwing [ProtocolException] on server error
  create() async {
    _fileSize = await file.length();

    final createHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({
        "Tus-Resumable": tusVersion,
        "Upload-Metadata": _uploadMetadata ?? "",
        "Upload-Length": "$_fileSize",
      });
    final client = getDioClient()..options.headers.addAll(createHeaders);

    final response = await client.post(url.toString());

    if (!((response.statusCode ?? 400) >= 200 &&
            (response.statusCode ?? 400) < 300) &&
        response.statusCode != 404) {
      throw ProtocolException(
          "unexpected status code (${response.statusCode}) while creating upload");
    }

    String urlStr = response.headers.value("Location") ?? "";
    if (urlStr.isEmpty) {
      throw ProtocolException(
          "missing upload Uri in response for creating upload");
    }

    _uploadUrl = _parseUrl(urlStr);
    store?.set(_fingerprint, _uploadUrl as Uri);
  }

  /// Check if possible to resume an already started upload
  Future<bool> resume() async {
    _fileSize = await file.length();
    _pauseUpload = false;

    if (!resumingEnabled) {
      return false;
    }

    _uploadUrl = await store?.get(_fingerprint);

    if (_uploadUrl == null) {
      return false;
    }
    return true;
  }

  /// Start or resume an upload in chunks of [maxChunkSize] throwing
  /// [ProtocolException] on server error
  upload({
    Function(double, Duration)? onProgress,
    Function()? onComplete,
  }) async {
    if (!await resume()) {
      await create();
    }

    // We start a stopwatch to calculate the upload speed
    final uploadStopwatch = Stopwatch()..start();

    // get offset from server
    _offset = await _getOffset();

    int totalBytes = _fileSize as int;

    // start upload
    final client = getDioClient();

    while (!_pauseUpload && (_offset ?? 0) < totalBytes) {
      final uploadHeaders = Map<String, String>.from(headers ?? {})
        ..addAll({
          "Tus-Resumable": tusVersion,
          "Upload-Offset": "$_offset",
          "Content-Type": "application/offset+octet-stream"
        });
      client.options.headers.addAll(uploadHeaders);
      _chunkPatchFuture = client.patch(
        (_uploadUrl as Uri).toString(),
        data: await _getData(),
        onSendProgress: (int sent, int total) {
          if (onProgress != null) {
            // Total byte sent
            final totalSent = (sent + (_offset ?? 0));

            // The total upload speed in bytes/ms
            final uploadSpeed = totalSent / uploadStopwatch.elapsedMilliseconds;

            // The data that hasn't been sent yet
            final remainData = totalBytes - totalSent;

            // The time remaining to finish the upload
            final estimate = Duration(
              milliseconds: (remainData / uploadSpeed).round(),
            );

            final progress = totalSent / totalBytes * 100;

            onProgress(progress.clamp(0, 100), estimate);
          }
        },
      );
      final response = await _chunkPatchFuture;

      _chunkPatchFuture = null;

      // check if correctly uploaded
      if (!(response.statusCode >= 200 && response.statusCode < 300)) {
        throw ProtocolException(
            "unexpected status code (${response.statusCode}) while uploading chunk");
      }

      final offset = response.headers.value("upload-offset");

      int? serverOffset = _parseOffset(offset);

      if (serverOffset == null) {
        throw ProtocolException(
            "response to PATCH request contains no or invalid Upload-Offset header");
      }

      _offset = serverOffset;

      if (_offset == totalBytes) {
        uploadStopwatch.stop();
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
    return file.path.replaceAll(RegExp(r"\W+"), '.');
  }

  /// Override this to customize creating 'Upload-Metadata'
  String generateMetadata() {
    final meta = Map<String, String>.from(metadata ?? {});

    if (!meta.containsKey("filename")) {
      meta["filename"] = p.basename(file.path);
    }

    return meta.entries
        .map((entry) =>
            entry.key + " " + base64.encode(utf8.encode(entry.value)))
        .join(",");
  }

  /// Get offset from server throwing [ProtocolException] on error
  Future<int> _getOffset() async {
    final client = getDioClient();

    final offsetHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({
        "Tus-Resumable": tusVersion,
      });
    client.options.headers.addAll(offsetHeaders);
    final response = await client.head((_uploadUrl as Uri).toString());

    if (!((response.statusCode ?? 400) >= 200 &&
            (response.statusCode ?? 400) < 300) &&
        response.statusCode != 404) {
      throw ProtocolException(
          "unexpected status code (${response.statusCode}) while resuming upload");
    }

    final offset = response.headers.value("upload-offset");

    int? serverOffset = _parseOffset(offset);
    if (serverOffset == null) {
      throw ProtocolException(
          "missing upload offset in response for resuming upload");
    }
    return serverOffset;
  }

  /// Get data from file to upload

  Future<Uint8List> _getData() async {
    int start = _offset ?? 0;

    // The server uses an offset 4.571... bigger than the number we pass to it,
    // so we need to divide it by 4.571...
    int end = (_offset ?? 0) + (maxChunkSize / 4.571556501348478).round();

    end = end > (_fileSize ?? 0) ? _fileSize ?? 0 : end;

    final result = BytesBuilder();
    await for (final chunk in file.openRead(start, end)) {
      result.add(chunk);
    }

    final response = result.takeBytes();

    return response;
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
