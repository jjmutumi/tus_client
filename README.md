# A tus client

[![Pub Version](https://img.shields.io/pub/v/tus_client_dart)](https://pub.dev/packages/tus_client_dart)
[![Build Status](https://app.travis-ci.com/tomassasovsky/tus_client.svg?branch=master)](https://travis-ci.org/tomassasovsky/tus_client)

---

A tus client in pure dart. [Resumable uploads using tus protocol](https://tus.io/)
Forked from [tus_client](https://pub.dev/packages/tus_client)

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again. An interruption may happen willingly, if
> the user wants to pause, or by accident in case of a network issue or server
> outage.

- [A tus client](#a-tus-client)
  - [Usage](#usage)
    - [Using Persistent URL Store](#using-persistent-url-store)
    - [Adding Extra Headers](#adding-extra-headers)
    - [Adding extra data](#adding-extra-data)
    - [Changing chunk size](#changing-chunk-size)
    - [Pausing upload](#pausing-upload)
  - [Example](#example)
  - [Maintainers](#maintainers)

## Usage

```dart
import 'package:cross_file/cross_file.dart' show XFile;

// File to be uploaded
final file = XFile("/path/to/my/pic.jpg");

// Create a client
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    store: TusMemoryStore(),
);

// Starts the upload
await client.upload(
    onComplete: () {
        print("Complete!");

        // Prints the uploaded file URL
        print(client.uploadUrl.toString());
    },
    onProgress: (progress) {
        print("Progress: $progress");
    },
);
```

### Using Persistent URL Store

This is only supported on Flutter Android, iOS, desktop and web.
You need to add to your `pubspec.yaml`:

```yaml
dependencies:
  tus_client: ^1.0.2
  tus_client_file_store: ^0.0.3
```

```dart
import 'package:path_provider/path_provider.dart';
import 'package:tus_client_file_store/tus_client_file_store.dart' show TusFileStore;
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
    headers: {"Authorization": "..."},
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
    onComplete: () {
        print("Complete!");
    },
    onProgress: (progress) {
        print("Progress: $progress");
    },
);
```

## Example

For an example of usage in a Flutter app (using file picker) see: [/example](https://github.com/tomassasovsky/tus_client/tree/master/example/lib/main.dart)

## Maintainers

* [Nazareno Cavazzon](https://github.com/NazarenoCavazzon)
* [Jorge Rincon](https://github.com/jorger5)
* [Tomás Sasovsky](https://github.com/tomassasovsky)
