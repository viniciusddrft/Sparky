/// Author: viniciusddrft
///
/// This class provides the foundation for handling authentication using JWT tokens.
/// It takes a secret key in the constructor, which is used to sign the JWT tokens.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

final class AuthJwt {
  final String secretKey;

  /// Constructs an [AuthJwt] instance with the provided secret key.
  const AuthJwt({required this.secretKey});

  /// Generates a JWT token from the given [payload].
  ///
  /// If [expiresIn] is provided, an `exp` claim is added automatically.
  /// An `iat` (issued at) claim is always added with the current time.
  String generateToken(Map<String, Object> payload, {Duration? expiresIn}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final claims = <String, Object>{
      ...payload,
      'iat': now,
    };
    if (expiresIn != null) {
      claims['exp'] = now + expiresIn.inSeconds;
    }

    final header = json.encode({'alg': 'HS256', 'typ': 'JWT'});
    final encodedHeader =
        base64Url.encode(utf8.encode(header)).replaceAll('=', '');
    final encodedPayload =
        base64Url.encode(utf8.encode(json.encode(claims))).replaceAll('=', '');
    final signature = _hmacSha256('$encodedHeader.$encodedPayload', secretKey);
    return '$encodedHeader.$encodedPayload.$signature';
  }

  /// Verifies the given JWT [token].
  ///
  /// Checks the signature and, if an `exp` claim is present,
  /// verifies that the token has not expired.
  /// Returns `true` if valid, `false` otherwise.
  bool verifyToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;

    // Validate that the header specifies HS256 to prevent algorithm confusion.
    try {
      final headerJson = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[0])),
      );
      final header = json.decode(headerJson);
      if (header is! Map || header['alg'] != 'HS256') return false;
    } catch (_) {
      return false;
    }

    final signature = _hmacSha256('${parts[0]}.${parts[1]}', secretKey);
    if (parts[2] != signature) return false;

    final payload = decodePayload(token);
    if (payload == null) return false;

    if (payload.containsKey('exp')) {
      final exp = payload['exp'];
      if (exp is int) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now > exp) return false;
      }
    }

    return true;
  }

  /// Decodes and returns the payload from a JWT [token] without verifying
  /// the signature. Returns `null` if the token format is invalid.
  Map<String, dynamic>? decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final decoded = json.decode(payloadString);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Computes the HMAC SHA-256 signature for the given [input] using the [key].
  String _hmacSha256(String input, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(input));
    return base64Url.encode(Uint8List.fromList(digest.bytes))
        .replaceAll('=', '');
  }
}
