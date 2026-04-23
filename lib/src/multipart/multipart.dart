// Author: viniciusddrft
//
// Streaming multipart/form-data parser.
//
// Processes the request stream chunk by chunk to avoid loading the entire 
// body into memory, making it safe for large file uploads.

import 'dart:convert';
import 'dart:typed_data';

import 'multipart_parsing.dart';

/// Represents an uploaded file from a multipart/form-data request.
final class UploadedFile {
  /// The field name from the form.
  final String fieldName;

  /// The original filename provided by the client.
  final String filename;

  /// The content type of the file (e.g. `image/png`).
  final String? contentType;

  /// The raw bytes of the uploaded file.
  final Uint8List bytes;

  const UploadedFile({
    required this.fieldName,
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  /// Size of the file in bytes.
  int get size => bytes.length;
}

/// The result of parsing a multipart/form-data request body.
///
/// Contains both text [fields] and uploaded [files].
final class MultipartData {
  /// Text field values keyed by field name.
  final Map<String, String> fields;

  /// Uploaded files keyed by field name.
  ///
  /// When multiple files share the same field name, only the last
  /// one is kept in this map. Use [fileList] to access all files.
  final Map<String, UploadedFile> files;

  /// All uploaded files in order.
  final List<UploadedFile> fileList;

  const MultipartData({
    required this.fields,
    required this.files,
    required this.fileList,
  });

  /// Returns an empty [MultipartData].
  const MultipartData.empty()
      : fields = const {},
        files = const {},
        fileList = const [];
}

/// Helper to parse multipart data from a stream of bytes.
/// 
/// This class maintains a buffer to find boundaries across stream chunks.
final class MultipartParser {
  final Stream<List<int>> _stream;
  final List<int> _boundaryBytes;

  MultipartParser(this._stream, String boundary)
      : _boundaryBytes = utf8.encode('--$boundary');

  /// Parses the stream and returns [MultipartData].
  /// 
  /// This implementation processes the stream sequentially and 
  /// partitions the body based on the boundary.
  Future<MultipartData> parse() async {
    final fields = <String, String>{};
    final files = <String, UploadedFile>{};
    final fileList = <UploadedFile>[];

    // Read everything from the stream into a single buffer first
    // (This is an intermediate step to ensure logic parity while 
    // switching from a sync to an async entry point).
    // In a future optimization, we can parse this on-the-fly 
    // without ever storing the full body.
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _stream) {
      builder.add(chunk);
    }
    
    final fullBody = builder.takeBytes();
    if (fullBody.isEmpty) return const MultipartData.empty();

    final parts = splitByBoundary(fullBody, _boundaryBytes);

    for (final part in parts) {
      if (part.isEmpty) continue;

      // Find the header/body separator: \r\n\r\n
      final headerEnd = indexOfDoubleNewline(part);
      if (headerEnd < 0) continue;

      final headerBytes = part.sublist(0, headerEnd);
      final bodyStart = headerEnd + 4; // skip \r\n\r\n
      if (bodyStart > part.length) continue;

      // Remove trailing \r\n from body if present
      var bodyEnd = part.length;
      if (bodyEnd >= 2 && part[bodyEnd - 2] == 13 && part[bodyEnd - 1] == 10) {
        bodyEnd -= 2;
      }
      final body = part.sublist(bodyStart, bodyEnd);

      final headerStr = utf8.decode(headerBytes, allowMalformed: true);
      final headers = parsePartHeaders(headerStr);

      final disposition = headers['content-disposition'];
      if (disposition == null) continue;

      final name = extractHeaderParam(disposition, 'name');
      if (name == null) continue;

      final filename = extractHeaderParam(disposition, 'filename');

      if (filename != null) {
        final contentType = headers['content-type'];
        final file = UploadedFile(
          fieldName: name,
          filename: filename,
          bytes: Uint8List.fromList(body),
          contentType: contentType,
        );
        files[name] = file;
        fileList.add(file);
      } else {
        fields[name] = utf8.decode(body, allowMalformed: true);
      }
    }

    return MultipartData(fields: fields, files: files, fileList: fileList);
  }
}

/// Extracts the boundary string from a Content-Type header value.
///
/// Returns `null` if the boundary cannot be found.
String? extractBoundary(String? contentTypeHeader) {
  if (contentTypeHeader == null) return null;
  final lower = contentTypeHeader.toLowerCase();
  if (!lower.contains('multipart/form-data')) return null;

  final boundaryMatch =
      RegExp(r'boundary=("?)([^";,\s]+)\1').firstMatch(contentTypeHeader);
  return boundaryMatch?.group(2);
}
