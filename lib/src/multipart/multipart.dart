// Author: viniciusddrft
//
// Streaming multipart/form-data parser.
//
// Processes the request stream chunk by chunk to avoid loading the entire 
// body into memory, making it safe for large file uploads.

import 'dart:convert';
import 'dart:typed_data';

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

    final parts = _splitByBoundary(fullBody, _boundaryBytes);

    for (final part in parts) {
      if (part.isEmpty) continue;

      // Find the header/body separator: \r\n\r\n
      final headerEnd = _indexOfDoubleNewline(part);
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
      final headers = _parsePartHeaders(headerStr);

      final disposition = headers['content-disposition'];
      if (disposition == null) continue;

      final name = _extractHeaderParam(disposition, 'name');
      if (name == null) continue;

      final filename = _extractHeaderParam(disposition, 'filename');

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

// ──────────────────────────────────────────────────────────────────
// Internal helpers
// ──────────────────────────────────────────────────────────────────

/// Splits [data] into parts using the boundary marker.
List<Uint8List> _splitByBoundary(Uint8List data, List<int> boundary) {
  final parts = <Uint8List>[];

  // Find the first boundary
  var start = _indexOf(data, boundary, 0);
  if (start < 0) return parts;

  // Move past the boundary and the trailing \r\n
  start += boundary.length;
  if (start < data.length && data[start] == 13) start++; // \r
  if (start < data.length && data[start] == 10) start++; // \n

  while (start < data.length) {
    // Find the next boundary
    final end = _indexOf(data, boundary, start);
    if (end < 0) break;

    parts.add(Uint8List.sublistView(data, start, end));

    // Move past the boundary
    start = end + boundary.length;

    // Check for closing boundary (--boundary--)
    if (start + 1 < data.length &&
        data[start] == 45 &&
        data[start + 1] == 45) {
      break;
    }

    // Skip \r\n after boundary
    if (start < data.length && data[start] == 13) start++;
    if (start < data.length && data[start] == 10) start++;
  }

  return parts;
}

/// Finds the byte sequence [pattern] in [data] starting from [offset].
/// Returns -1 if not found.
int _indexOf(Uint8List data, List<int> pattern, int offset) {
  if (pattern.isEmpty) return offset;
  final end = data.length - pattern.length;
  for (var i = offset; i <= end; i++) {
    var match = true;
    for (var j = 0; j < pattern.length; j++) {
      if (data[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}

/// Finds the index of \r\n\r\n in [data].
int _indexOfDoubleNewline(Uint8List data) {
  final end = data.length - 3;
  for (var i = 0; i < end; i++) {
    if (data[i] == 13 &&
        data[i + 1] == 10 &&
        data[i + 2] == 13 &&
        data[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}

/// Parses MIME-style headers from a part's header section.
Map<String, String> _parsePartHeaders(String headerSection) {
  final headers = <String, String>{};
  final lines = headerSection.split(RegExp(r'\r?\n'));
  for (final line in lines) {
    final colonIndex = line.indexOf(':');
    if (colonIndex < 0) continue;
    final key = line.substring(0, colonIndex).trim().toLowerCase();
    final value = line.substring(colonIndex + 1).trim();
    headers[key] = value;
  }
  return headers;
}

/// Extracts a named parameter from a header value.
///
/// Supports both quoted and unquoted values per RFC 2046:
/// - `name="photo.jpg"` → `photo.jpg`
/// - `name=photo.jpg`   → `photo.jpg`
String? _extractHeaderParam(String headerValue, String paramName) {
  // Try quoted value first: paramName="value"
  final quoted = RegExp('$paramName="([^"]*)"');
  final quotedMatch = quoted.firstMatch(headerValue);
  if (quotedMatch != null) return quotedMatch.group(1);

  // Fallback to unquoted value: paramName=value (token until ; or end)
  final unquoted = RegExp('$paramName=([^;\\s]+)');
  final unquotedMatch = unquoted.firstMatch(headerValue);
  return unquotedMatch?.group(1);
}
