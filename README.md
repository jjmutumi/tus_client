# tus_client

A TUS client in pure dart. [Resumable uploads using TUS protocol](https://tus.io/)

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again. An interruption may happen willingly, if
> the user wants to pause, or by accident in case of a network issue or server
> outage.

- [tus_client](#tus_client)
  - [Usage](#usage)
    - [Using Persistent URL Store](#using-persistent-url-store)
    - [Adding Extra Headers](#adding-extra-headers)
    - [Adding extra data](#adding-extra-data)
    - [Changing chunk size](#changing-chunk-size)
    - [Pausing upload](#pausing-upload)

## Usage

```dart
// File to be uploaded
final file = File("/path/to/my/pic.jpg");

// Create a client
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    store: TusMemoryStore(),
    metadata: {}
);

// Starts the upload
await client.upload(
    onComplete: (upload) {
        print("Complete!");
    },
    onProgress: (upload, progress) {
        print("Progress: $progress");
    },
);

// Prints the uploaded file URL
print(client.uploadUrl.toString());
```

### Using Persistent URL Store

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Directory the current uploads will be saved in
final tempDir = (await getTemporaryDirectory()).path;
final tempDirectory = Directory(p.join(tempDir, "tus-uploads"));

// Create a client
final client = TusClient(
    Uri.parse("https://example.com/tus"),
    file,
    store: TusFileStore(tempDirectory),
);

// Start upload
await client.upload();
```

### Adding Extra Headers

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    headers:{"Authorization": "..."},
);
```

### Adding extra data

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    metadata: {"for-gallery": "..."},
);
```

### Changing chunk size

The file is uploaded in chunks. Default size is 512KB. This should be set considering `speed of upload` vs `device memory constraints`

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    maxChunkSize: 10 * 1024 * 1024,  // chunk is 10MB
);
```

### Pausing upload

Pausing upload can be done after current uploading in chunk is completed.

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file
);

// Pause after 5 seconds
Future.delayed(Duration(seconds: 5)).then((_) =>client.pause());

// Starts the upload
await client.upload(
    onComplete: (upload) {
        print("Complete!");
    },
    onProgress: (upload, progress) {
        print("Progress: $progress");
    },
);
```