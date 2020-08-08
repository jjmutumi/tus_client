# tus_client

A TUS client for dart. Translation of the [tus-java-client](https://github.com/tus/tus-java-client).

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again. An interruption may happen willingly, if
> the user wants to pause, or by accident in case of a network issue or server
> outage.

## Installing

Add to pubspec.yaml
```yaml
dependencies:
  tus: ^0.0.1
```

## Usage

```dart
final tusClient = TusClient(
    Uri.parse("https://example.com/tus"),
    urlStore: TusURLMemoryStore(),
);

final file = File("/my/pic.jpg");

final upload = TusUpload();
await upload.initialize(file);

final executor = TusMainExecutor(
    client,
    onComplete: (upload) {},
    onProgress: (upload, progress) {},
);
await executor.makeAttempts(upload);
```