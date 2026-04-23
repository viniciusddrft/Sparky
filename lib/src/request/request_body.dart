// @author viniciusddrft

import 'dart:convert';
import 'dart:typed_data';

import 'package:sparky/src/multipart/multipart.dart';

import 'sparky_request.dart';

/// Unified body-reading namespace exposed via [SparkyRequest.body].
///
/// Each method consumes the stream only once and caches the result, so
/// mixing calls (e.g. [text] then [json]) is safe. [multipart] reads the
/// raw stream directly and does not share the text/bytes cache.
final class RequestBody {
  final SparkyRequest _request;
  String? _cachedText;
  Uint8List? _cachedBytes;

  /// @nodoc — Sparky-internal; `SparkyRequest.body` is the user-facing entry.
  RequestBody.internal(this._request);

  /// Reads the body as a UTF-8 string.
  Future<String> text() async {
    final cachedText = _cachedText;
    if (cachedText != null) return cachedText;
    final raw = await bytes();
    final content = utf8.decode(raw, allowMalformed: true);
    _cachedText = content;
    return content;
  }

  /// Reads the body as raw bytes.
  ///
  /// Unlike [text], this preserves binary data without UTF-8 decoding.
  /// [multipart] does **not** go through this cache — it reads the raw stream
  /// directly.
  Future<Uint8List> bytes() async {
    final cached = _cachedBytes;
    final max = _request.maxBodySize;
    if (cached != null) {
      if (max != null && cached.length > max) {
        throw BodyTooLargeException(max);
      }
      return cached;
    }

    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in _request.raw) {
      total += chunk.length;
      if (max != null && total > max) {
        throw BodyTooLargeException(max);
      }
      builder.add(chunk);
    }
    final result = builder.takeBytes();
    _cachedBytes = result;
    return result;
  }

  /// Parses the body as JSON and returns a `Map<String, dynamic>`.
  ///
  /// Returns an empty map when the body is empty or decodes to a non-object
  /// JSON value (array, scalar).
  Future<Map<String, dynamic>> json() async {
    final content = await text();
    if (content.isEmpty) return {};
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  /// Parses a URL-encoded form body (`application/x-www-form-urlencoded`).
  Future<Map<String, String>> form() async {
    final content = await text();
    if (content.isEmpty) return {};
    return Uri.splitQueryString(content);
  }

  /// Parses a `multipart/form-data` body into fields and files.
  ///
  /// Binary-safe: file uploads keep their exact bytes.
  ///
  /// ```dart
  /// final form = await request.body.multipart();
  /// final name = form.fields['name'];
  /// final avatar = form.files['avatar'];
  /// if (avatar != null) {
  ///   await File('uploads/${avatar.filename}').writeAsBytes(avatar.bytes);
  /// }
  /// ```
  ///
  /// Returns [MultipartData.empty] if the request is not
  /// `multipart/form-data` or has no boundary. Reads the raw stream directly,
  /// so calling this after [text] or [bytes] will yield an empty result.
  Future<MultipartData> multipart() async {
    final contentTypeHeader = _request.headers.value('content-type');
    final boundary = extractBoundary(contentTypeHeader);
    if (boundary == null) return const MultipartData.empty();
    return MultipartParser(_request.raw, boundary).parse();
  }
}
