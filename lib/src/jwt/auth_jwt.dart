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
  ///
  /// The [secretKey] is used for signing the JWT tokens.
  const AuthJwt({required this.secretKey});

  /// Generates a JWT token from the given [payload].
  ///
  /// The [payload] is a [Map<String, Object>] containing the login data.
  /// This function returns a signed JWT token as a [String].
  String generateToken(Map<String, Object> payload) {
    final header = json.encode({'alg': 'HS256', 'typ': 'JWT'});
    final encodedHeader = base64Url.encode(utf8.encode(header));
    final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
    final signature = _hmacSha256('$encodedHeader.$encodedPayload', secretKey);
    return '$encodedHeader.$encodedPayload.$signature';
  }

  /// Verifies the given JWT [token].
  ///
  /// This function checks if the token is valid by comparing the signature
  /// with a newly computed HMAC SHA-256 signature. Returns `true` if the
  /// token is valid, otherwise `false`.
  bool verifyToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final signature = _hmacSha256('${parts[0]}.${parts[1]}', secretKey);
    return parts[2] == signature;
  }

  /// Computes the HMAC SHA-256 signature for the given [input] using the [key].
  ///
  /// This function returns the computed signature as a base64 URL-encoded [String].
  String _hmacSha256(String input, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(input));
    return base64Url.encode(Uint8List.fromList(digest.bytes));
  }
}
