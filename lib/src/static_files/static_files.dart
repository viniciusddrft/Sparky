// Author: viniciusddrft

import 'dart:convert';
import 'dart:io';
import 'package:sparky/src/response/response.dart';
import 'package:sparky/src/types/sparky_types.dart';

/// Middleware that serves static files from a directory.
///
/// Requests whose path starts with [urlPath] are mapped to files inside
/// [directory]. If the file exists it is served with the appropriate
/// content type; otherwise the pipeline continues (`null` is returned).
///
/// ```dart
/// final files = StaticFiles(urlPath: '/public', directory: './static');
///
/// Sparky.server(
///   pipelineBefore: Pipeline()..add(files.createMiddleware()),
///   routes: [...],
/// );
/// ```
final class StaticFiles {
  final String urlPath, directory;
  final int? maxFileSize;

  const StaticFiles({
    required this.urlPath,
    required this.directory,
    this.maxFileSize,
  });

  /// Creates a middleware that serves static files.
  ///
  /// Only handles GET and HEAD requests. Returns `null` for non-matching
  /// paths so the pipeline continues to the next handler.
  MiddlewareNulable createMiddleware() {
    return (HttpRequest request) async {
      if (request.method != 'GET' && request.method != 'HEAD') return null;

      final normalizedUrlPath = _normalizeUrlPath(urlPath);
      final requestPath = request.uri.path;
      final originalRequestPath = request.requestedUri.path;
      final isBasePath = requestPath ==
          normalizedUrlPath.substring(
            0,
            normalizedUrlPath.length - 1,
          );
      final isBasePathOriginal = originalRequestPath ==
          normalizedUrlPath.substring(
            0,
            normalizedUrlPath.length - 1,
          );
      final matchesOriginalPrefix =
          originalRequestPath.startsWith(normalizedUrlPath) ||
              isBasePathOriginal;
      if ((!requestPath.startsWith(normalizedUrlPath) && !isBasePath) &&
          !matchesOriginalPrefix) {
        return null;
      }

      final decodedOriginalPath = Uri.decodeFull(originalRequestPath);
      final rawRequestedUri = request.requestedUri.toString().toLowerCase();
      if (rawRequestedUri.contains('%2e%2e') ||
          rawRequestedUri.contains('%2f..') ||
          rawRequestedUri.contains('..%2f')) {
        return const Response.forbidden(
          body: {'error': 'Access denied'},
        );
      }
      if (decodedOriginalPath.contains('/../') ||
          decodedOriginalPath.endsWith('/..')) {
        return const Response.forbidden(
          body: {'error': 'Access denied'},
        );
      }

      var relativePath =
          isBasePath ? '/' : requestPath.substring(normalizedUrlPath.length);
      if (relativePath.isNotEmpty && !relativePath.startsWith('/')) {
        relativePath = '/$relativePath';
      }
      if (relativePath.isEmpty || relativePath == '/') {
        relativePath = '/index.html';
      }
      if (relativePath.contains('..')) {
        return const Response.forbidden(
          body: {'error': 'Access denied'},
        );
      }

      final sanitizedPath = _sanitizeRelativePath(relativePath);
      if (sanitizedPath == null) {
        return const Response.forbidden(
          body: {'error': 'Access denied'},
        );
      }
      final filePath = _resolveAbsolutePath(directory, sanitizedPath);
      final file = File(filePath);

      if (!await file.exists()) return null;
      try {
        final rootPath = Directory(directory).absolute.path;
        final canonicalRoot = await Directory(rootPath).resolveSymbolicLinks();
        final canonicalFile = await file.resolveSymbolicLinks();
        if (!_isInsideRoot(canonicalFile, canonicalRoot)) {
          return const Response.forbidden(
            body: {'error': 'Access denied'},
          );
        }
      } catch (_) {
        return null;
      }

      final fileStat = await file.stat();
      if (maxFileSize != null && fileStat.size > maxFileSize!) {
        return const Response.requestEntityTooLarge(
          body: {'error': 'Static file too large'},
        );
      }

      final lastModified = fileStat.modified.toUtc();
      final etag = _generateETag(fileStat);

      final ifNoneMatch = request.headers.value(HttpHeaders.ifNoneMatchHeader);
      if (ifNoneMatch != null && ifNoneMatch == etag) {
        return Response.notModified(
          body: '',
          headers: {
            HttpHeaders.etagHeader: etag,
            HttpHeaders.cacheControlHeader: 'public, max-age=3600',
          },
        );
      }

      final ifModifiedSince = request.headers.ifModifiedSince;
      if (ifModifiedSince != null && !lastModified.isAfter(ifModifiedSince)) {
        return Response.notModified(
          body: '',
          headers: {
            HttpHeaders.etagHeader: etag,
            HttpHeaders.cacheControlHeader: 'public, max-age=3600',
          },
        );
      }

      final contentType = _contentTypeFor(filePath);
      final contentLength = fileStat.size.toString();
      final cacheHeaders = {
        'Content-Length': contentLength,
        HttpHeaders.etagHeader: etag,
        HttpHeaders.lastModifiedHeader: HttpDate.format(lastModified),
        HttpHeaders.cacheControlHeader: 'public, max-age=3600',
      };

      if (request.method == 'HEAD') {
        return Response.ok(
          body: <int>[],
          contentType: contentType,
          headers: cacheHeaders,
        );
      }

      return Response.ok(
        body: file.openRead(),
        contentType: contentType,
        headers: cacheHeaders,
      );
    };
  }

  static String _normalizeUrlPath(String value) {
    if (value.isEmpty) return '/';
    var normalized = value.startsWith('/') ? value : '/$value';
    if (!normalized.endsWith('/')) normalized = '$normalized/';
    return normalized;
  }

  static String _normalizeDirectoryPath(String value) {
    if (value.endsWith('/')) return value.substring(0, value.length - 1);
    return value;
  }

  static String? _sanitizeRelativePath(String relativePath) {
    final normalized =
        relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    if (normalized.isEmpty) return 'index.html';

    final cleanSegments = <String>[];
    for (final segment in normalized.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      final decoded = Uri.decodeComponent(segment);
      if (decoded == '..' || decoded.contains(r'\')) {
        return null;
      }
      cleanSegments.add(decoded);
    }
    if (cleanSegments.isEmpty) return 'index.html';
    return cleanSegments.join('/');
  }

  static String _resolveAbsolutePath(String root, String cleanRelativePath) {
    final normalizedRoot = _normalizeDirectoryPath(root);
    return '$normalizedRoot/$cleanRelativePath';
  }

  static bool _isInsideRoot(String candidatePath, String rootPath) {
    final normalizedRoot = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    return candidatePath == rootPath ||
        candidatePath.startsWith(normalizedRoot);
  }

  static String _generateETag(FileStat stat) {
    final raw = '${stat.size}-${stat.modified.millisecondsSinceEpoch}';
    final hash = base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    return '"$hash"';
  }

  static ContentType _contentTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'html' || 'htm' => ContentType.html,
      'css' => ContentType('text', 'css'),
      'js' => ContentType('application', 'javascript'),
      'json' => ContentType.json,
      'png' => ContentType('image', 'png'),
      'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
      'gif' => ContentType('image', 'gif'),
      'svg' => ContentType('image', 'svg+xml'),
      'ico' => ContentType('image', 'x-icon'),
      'webp' => ContentType('image', 'webp'),
      'pdf' => ContentType('application', 'pdf'),
      'xml' => ContentType('application', 'xml'),
      'txt' => ContentType.text,
      'csv' => ContentType('text', 'csv'),
      'woff' => ContentType('font', 'woff'),
      'woff2' => ContentType('font', 'woff2'),
      'ttf' => ContentType('font', 'ttf'),
      'mp4' => ContentType('video', 'mp4'),
      'mp3' => ContentType('audio', 'mpeg'),
      'zip' => ContentType('application', 'zip'),
      _ => ContentType.binary,
    };
  }
}
