## [2.1.0] - HTTP Package updated

- Now the package uses Dio to manage HTTP Requests.
- Estimated time added.
- Chunk size issue with big files and names fixed.

## [2.0.1] - Added Persistent Store

- Users can now use TusFileStore to create persistent state of uploads.

## [1.0.3] - Updating dependencies

- Updating dependencies
- Migrating to a native dart package

## [1.0.2] - Fixed issue with not parsing the http port number

- Fixed issue with not parsing the http port number
- Fixing formatting

## [1.0.1] - Fixing custom chunk size

- Fixing handling file as chunks correctly
- Fixing null safety warnings
- Updating dependencies

## [1.0.0] - Migrating to null safety

- Making null safe
- Increasing minimum Dart SDK
- Fixing deprecated APIs

## [0.1.3] - Updating dependencies

- Updating dependencies
- Removing deadcode

## [0.1.2] - Many improvements

- Fixing server returns partial url & double header.
- Fixing immediate pause even when uploading with large chunks by timing out the future
- Removing unused exceptions (deadcode)
- Updating dependencies

## [0.1.1] - Better file persistence documentation

- Have better documentation on using tus_client_file_store

## [0.1.0] - Web support

- This is update breaks backwards compatibility
- Adding cross_file Flutter plugin to manage reading files across platforms
- Refactoring example to show use with XFile on Android/iOS vs web

## [0.0.4] - Feature request

- Changing example by adding copying file to be uploaded to application temp directory before uploading

## [0.0.3] - Bug fix

- Fixing missing Tus-Resumable headers in all requests

## [0.0.2] - Bug fix

- Fixing failure when offset for server is missing or null

## [0.0.1] - Initial release

- Support for TUS 1.0.0 protocol
- Uploading in chunks
- Basic protocol support
- **TODO**: Add support for multiple file upload
- **TODO**: Add support for partial file uploads
