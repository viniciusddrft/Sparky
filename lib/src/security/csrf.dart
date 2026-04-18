// @author viniciusddrft

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sparky/src/extensions/http_request.dart';
import 'package:sparky/src/response/response.dart';
import 'package:sparky/src/types/sparky_types.dart';

/// Synchronized-token CSRF protection (double-submit cookie pattern).
///
/// A random token is stored in a **non-HttpOnly** cookie so that same-origin
/// JavaScript can read it and send the same value in a header (typical for SPAs).
/// For HTML forms, use a hidden field matching [formFieldName] or send the
/// [headerName] from your front-end.
///
/// **Multipart** requests do not read the body here (the stream would conflict
/// with [HttpRequest.getMultipartData] downstream); send the token in
/// [headerName] for `multipart/form-data`.
///
/// When [ignoreRequestsWithBearer] is `true` (default), requests with an
/// `Authorization: Bearer …` header skip the check so stateless APIs using JWT
/// are not broken. Cookie-based sessions should keep the default for browser
/// clients and use Bearer only for non-browser API clients.
///
/// Add to [Pipeline] in `pipelineBefore`:
/// ```dart
/// Pipeline()..add(CsrfConfig().createMiddleware())
/// ```
final class CsrfConfig {
  /// Cookie that stores the CSRF token (readable by same-origin JS).
  final String cookieName;

  /// Header the client must send on unsafe methods with the same value as the cookie.
  final String headerName;

  /// For `application/x-www-form-urlencoded` bodies.
  final String formFieldName;

  /// For `application/json` bodies (top-level key).
  final String jsonFieldName;

  /// Uppercase method names that do not require a token (RFC 9110 safe semantics).
  final Set<String> safeMethods;

  /// Skip CSRF validation when `Authorization` starts with `Bearer `.
  final bool ignoreRequestsWithBearer;

  /// `Set-Cookie` attribute `Secure` (default `true`, browsers only send the
  /// cookie over HTTPS). Set to `false` for local HTTP development.
  final bool cookieSecure;

  /// `Set-Cookie` `SameSite` attribute.
  final SameSite? cookieSameSite;

  /// `Set-Cookie` `Path`.
  final String cookiePath;

  /// `Set-Cookie` `Max-Age` in seconds, or `null` to omit (session cookie).
  final int? cookieMaxAge;

  /// Number of random bytes used to generate the token (before Base64URL).
  final int tokenByteLength;

  const CsrfConfig({
    this.cookieName = 'sparky_csrf',
    this.headerName = 'X-CSRF-Token',
    this.formFieldName = '_csrf',
    this.jsonFieldName = '_csrf',
    this.safeMethods = const {
      'GET',
      'HEAD',
      'OPTIONS',
      'TRACE',
    },
    this.ignoreRequestsWithBearer = true,
    this.cookieSecure = true,
    this.cookieSameSite = SameSite.lax,
    this.cookiePath = '/',
    this.cookieMaxAge,
    this.tokenByteLength = 32,
  }) : assert(tokenByteLength >= 16, 'tokenByteLength must be at least 16');

  /// Pipeline middleware: sets the cookie on safe requests; validates on others.
  MiddlewareNullable createMiddleware() {
    return (HttpRequest request) async {
      final method = request.method.toUpperCase();

      if (safeMethods.contains(method)) {
        _ensureCsrfCookie(request);
        return null;
      }

      if (ignoreRequestsWithBearer) {
        final auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (auth != null && auth.toLowerCase().startsWith('bearer ')) {
          return null;
        }
      }

      final cookieVal = request.getCookie(cookieName)?.value;
      final submitted = await _readSubmittedToken(request);
      if (!_isValidToken(cookieVal) ||
          !_constantTimeEquals(cookieVal!, submitted ?? '')) {
        return const Response.forbidden(
          body: {
            'error': 'csrf_validation_failed',
            'message': 'Invalid or missing CSRF token',
          },
        );
      }

      return null;
    };
  }

  void _ensureCsrfCookie(HttpRequest request) {
    final existing = request.getCookie(cookieName)?.value;
    if (_isValidToken(existing)) return;

    final token = _generateToken();
    final cookie = Cookie(cookieName, token)
      ..path = cookiePath
      ..httpOnly = false
      ..secure = cookieSecure
      ..sameSite = cookieSameSite;
    if (cookieMaxAge != null) {
      cookie.maxAge = cookieMaxAge!;
    }
    request.response.cookies.add(cookie);
  }

  String _generateToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(tokenByteLength, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<String?> _readSubmittedToken(HttpRequest request) async {
    final fromHeader = request.headers.value(headerName);
    if (fromHeader != null && fromHeader.isNotEmpty) {
      return fromHeader.trim();
    }

    final ct = request.headers.contentType;
    final mime = ct?.mimeType;

    if (mime == 'application/x-www-form-urlencoded') {
      final form = await request.getFormData();
      final v = form[formFieldName];
      if (v != null && v.isNotEmpty) return v;
    }

    if (mime == 'application/json' || mime == 'application/problem+json') {
      final map = await request.getJsonBody();
      final v = map[jsonFieldName];
      if (v == null) return null;
      if (v is String) return v;
      return v.toString();
    }

    return null;
  }

  bool _isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length < 16) return false;
    final allowed = RegExp(r'^[A-Za-z0-9_-]+$');
    return allowed.hasMatch(token);
  }
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
