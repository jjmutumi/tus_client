# tus_client

A TUS client in pure dart. [Resumable uploads using TUS protocol](https://tus.io/)

Translation of the [tus-java-client](https://github.com/tus/tus-java-client).

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again. An interruption may happen willingly, if
> the user wants to pause, or by accident in case of a network issue or server
> outage.

- [tus_client](#tus_client)
  - [Installing](#installing)
  - [Usage](#usage)
    - [Using Persistent URL Store](#using-persistent-url-store)
    - [Adding Extra Headers](#adding-extra-headers)

## Installing

Add to pubspec.yaml
```yaml
dependencies:
  # ...
  tus: ^0.0.1
```

## Usage

```dart
final client = TusClient(
    Uri.parse("https://example.com/tus"),
    urlStore: TusURLMemoryStore(),
);

final file = File("/my/pic.jpg");

final upload = TusUpload();
await upload.initialize(file);

final executor = TusMainExecutor(
    client,
    onComplete: (upload) {
      print("Complete!");
    },
    onProgress: (upload, progress) {
      print("Progress: $progress");
    },
);
await executor.makeAttempts(upload);
```

### Using Persistent URL Store

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final tempDir = (await getTemporaryDirectory()).path;
final tempDirectory = Directory(p.join(tempDir, "tus-uploads"));

final client = TusClient(
    Uri.parse("https://example.com/tus"),
    urlStore: TusURLFileStore(tempDirectory),
);
```

### Adding Extra Headers

```dart
final client = TusClient(
    Uri.parse("https://example.com/tus"),
    urlStore: TusURLMemoryStore(),
    headers:{"Authorization": "..."},
);
```