// @author viniciusddrft

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:sparky/sparky.dart';
import 'package:sparky/src/handler/error_response.dart';

void main() {
  group('errorInfoFor', () {
    test('maps BodyTooLargeException to 413', () {
      final info = errorInfoFor(const BodyTooLargeException(1024), '/upload');

      expect(info.status, HttpStatus.requestEntityTooLarge);
      expect(info.logMessage, 'Request entity too large: /upload');
      final body = jsonDecode(info.body) as Map<String, Object?>;
      expect(body['errorCode'], '413');
      expect(body['message'], 'Request Entity Too Large');
    });

    test('maps TimeoutException to 408', () {
      final info =
          errorInfoFor(TimeoutException('slow', const Duration(seconds: 1)),
              '/slow');

      expect(info.status, HttpStatus.requestTimeout);
      expect(info.logMessage, 'Request timeout: /slow');
      final body = jsonDecode(info.body) as Map<String, Object?>;
      expect(body['errorCode'], '408');
      expect(body['message'], 'Request Timeout');
    });

    test('maps HttpException using its statusCode and toJson', () {
      const error = NotFound(
        message: 'User not found',
        details: {'userId': 42},
      );
      final info = errorInfoFor(error, '/users/42');

      expect(info.status, HttpStatus.notFound);
      expect(info.logMessage, 'HTTP 404: User not found (/users/42)');
      final body = jsonDecode(info.body) as Map<String, Object?>;
      expect(body['errorCode'], '404');
      expect(body['message'], 'User not found');
      expect(body['userId'], 42);
    });

    test('maps custom HttpException subclass with arbitrary status', () {
      const error = HttpException(418, "I'm a teapot");
      final info = errorInfoFor(error, '/brew');

      expect(info.status, 418);
      expect(info.logMessage, "HTTP 418: I'm a teapot (/brew)");
      final body = jsonDecode(info.body) as Map<String, Object?>;
      expect(body['errorCode'], '418');
    });

    test('falls back to 500 for unknown errors', () {
      final info = errorInfoFor(StateError('boom'), '/anything');

      expect(info.status, HttpStatus.internalServerError);
      expect(info.logMessage, contains('Bad state: boom'));
      final body = jsonDecode(info.body) as Map<String, Object?>;
      expect(body['errorCode'], '500');
      expect(body['message'], 'Internal Server Error');
    });

    test('valid JSON body for every branch', () {
      final samples = <Object>[
        const BodyTooLargeException(1),
        TimeoutException('x'),
        const NotFound(),
        Exception('generic'),
      ];
      for (final s in samples) {
        final info = errorInfoFor(s, '/p');
        expect(() => jsonDecode(info.body), returnsNormally,
            reason: 'body for ${s.runtimeType} must be valid JSON');
      }
    });
  });
}
