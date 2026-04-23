// @author viniciusddrft

import 'dart:convert';

import 'package:test/test.dart';
import 'package:sparky/src/handler/error_body.dart';

void main() {
  group('ErrorBody.toMap', () {
    test('defaults errorCode to status.toString()', () {
      final map = ErrorBody.toMap(404, 'Not Found');
      expect(map['errorCode'], '404');
      expect(map['message'], 'Not Found');
      expect(map.containsKey('details'), isFalse);
      expect(map.containsKey('requestId'), isFalse);
    });

    test('respects errorCode override', () {
      final map = ErrorBody.toMap(400, 'Bad Request', errorCode: 'invalid');
      expect(map['errorCode'], 'invalid');
    });

    test('merges details at top level', () {
      final map = ErrorBody.toMap(
        404,
        'User not found',
        details: const {'userId': 42, 'tenant': 'acme'},
      );
      expect(map['errorCode'], '404');
      expect(map['userId'], 42);
      expect(map['tenant'], 'acme');
    });

    test('details cannot accidentally clobber canonical fields', () {
      // details is spread AFTER errorCode/message, so a malicious or
      // accidental override IS possible — this test pins the current
      // behavior so a future change is intentional.
      final map = ErrorBody.toMap(
        500,
        'Original',
        details: const {'message': 'Override'},
      );
      expect(map['message'], 'Override');
    });

    test('includes requestId when provided', () {
      final map = ErrorBody.toMap(500, 'Boom', requestId: 'req-abc');
      expect(map['requestId'], 'req-abc');
    });
  });

  group('ErrorBody.toJson', () {
    test('produces valid JSON matching toMap', () {
      final json = ErrorBody.toJson(
        404,
        'Not Found',
        details: const {'resource': 'user'},
        requestId: 'req-1',
      );
      final decoded = jsonDecode(json) as Map<String, Object?>;
      expect(decoded, ErrorBody.toMap(
        404,
        'Not Found',
        details: const {'resource': 'user'},
        requestId: 'req-1',
      ));
    });

    test('emits the canonical errorCode/message keys', () {
      final json = ErrorBody.toJson(413, 'Request Entity Too Large');
      expect(json, contains('"errorCode":"413"'));
      expect(json, contains('"message":"Request Entity Too Large"'));
    });
  });
}
