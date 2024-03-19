// @author viniciusddrft
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// This class provides the foundation for handling login using JWT tokens
/// it receives a secret key in the constructor to apply to the JWT token.
final class AuthJwt {
  final String secretKey;

  const AuthJwt({required this.secretKey});

  /// This function takes a payload, which is a [Map<String, Object>] payload
  /// where login data will be sent and a token will be returned.
  String generateToken(Map<String, Object> payload) {
    final header = json.encode({'alg': 'HS256', 'typ': 'JWT'});
    final encodedHeader = base64Url.encode(utf8.encode(header));
    final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
    final signature = _hmacSha256('$encodedHeader.$encodedPayload', secretKey);
    return '$encodedHeader.$encodedPayload.$signature';
  }

  //token verification function.
  bool verifyToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    final signature = _hmacSha256('${parts[0]}.${parts[1]}', secretKey);
    return parts[2] == signature;
  }

  //function that performs the conversion to sha256.
  String _hmacSha256(String input, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(input));
    return base64Url.encode(Uint8List.fromList(digest.bytes));
  }
}
