// @author viniciusddrft
//
// @nodoc INTERNAL — byte-level helpers for [MultipartParser]. Not exported
// from `package:sparky/sparky.dart`.

import 'dart:typed_data';

/// Splits [data] into parts using the boundary marker.
List<Uint8List> splitByBoundary(Uint8List data, List<int> boundary) {
  final parts = <Uint8List>[];

  // Find the first boundary
  var start = indexOfBytes(data, boundary, 0);
  if (start < 0) return parts;

  // Move past the boundary and the trailing \r\n
  start += boundary.length;
  if (start < data.length && data[start] == 13) start++; // \r
  if (start < data.length && data[start] == 10) start++; // \n

  while (start < data.length) {
    // Find the next boundary
    final end = indexOfBytes(data, boundary, start);
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
int indexOfBytes(Uint8List data, List<int> pattern, int offset) {
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
int indexOfDoubleNewline(Uint8List data) {
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
Map<String, String> parsePartHeaders(String headerSection) {
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
String? extractHeaderParam(String headerValue, String paramName) {
  // Try quoted value first: paramName="value"
  final quoted = RegExp('$paramName="([^"]*)"');
  final quotedMatch = quoted.firstMatch(headerValue);
  if (quotedMatch != null) return quotedMatch.group(1);

  // Fallback to unquoted value: paramName=value (token until ; or end)
  final unquoted = RegExp('$paramName=([^;\\s]+)');
  final unquotedMatch = unquoted.firstMatch(headerValue);
  return unquotedMatch?.group(1);
}
