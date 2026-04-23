// Author: viniciusddrft

import 'package:sparky/src/request/sparky_request.dart';
import 'package:sparky/src/types/sparky_types.dart';

/// Configuration for security headers middleware (Helmet-style).
///
/// Adds standard security headers to every response to protect against
/// common web vulnerabilities like clickjacking, MIME sniffing, and XSS.
///
/// Use the default constructor for sensible defaults, or customize
/// individual headers as needed.
///
/// Example:
/// ```dart
/// pipelineBefore: Pipeline()
///   ..add(SecurityHeadersConfig().createMiddleware())
/// ```
final class SecurityHeadersConfig {
  /// Controls whether the browser should be allowed to render a page
  /// in a `<frame>`, `<iframe>`, `<embed>`, or `<object>`.
  ///
  /// Default: `DENY` — prevents all framing.
  /// Set to `SAMEORIGIN` to allow framing by the same origin,
  /// or `null` to omit the header.
  final String? xFrameOptions;

  /// Prevents the browser from MIME-sniffing a response away from
  /// the declared `Content-Type`.
  ///
  /// Default: `true` — sends `X-Content-Type-Options: nosniff`.
  final bool xContentTypeOptionsNoSniff;

  /// Controls the `X-XSS-Protection` header.
  ///
  /// Default: `0` — disables the XSS auditor (modern recommendation,
  /// as the auditor itself can introduce vulnerabilities).
  /// Set to `null` to omit the header.
  final String? xXssProtection;

  /// Enforces HTTPS via `Strict-Transport-Security`.
  ///
  /// Default: `max-age=15552000; includeSubDomains` (180 days).
  /// Set to `null` to omit the header (e.g. when not using HTTPS).
  final String? strictTransportSecurity;

  /// Sets the `Content-Security-Policy` header.
  ///
  /// Default: `default-src 'self'` — only allows resources from the
  /// same origin. Set to `null` to omit the header.
  final String? contentSecurityPolicy;

  /// Controls how much referrer information is sent with requests.
  ///
  /// Default: `no-referrer`.
  /// Set to `null` to omit the header.
  final String? referrerPolicy;

  /// Controls Adobe Flash and Acrobat cross-domain policies.
  ///
  /// Default: `none`.
  /// Set to `null` to omit the header.
  final String? xPermittedCrossDomainPolicies;

  /// Controls DNS prefetching by the browser.
  ///
  /// Default: `off` — disables DNS prefetching to prevent
  /// information leakage. Set to `null` to omit the header.
  final String? xDnsPrefetchControl;

  /// Isolates the browsing context to same-origin documents.
  ///
  /// Default: `same-origin`.
  /// Set to `null` to omit the header.
  final String? crossOriginOpenerPolicy;

  /// Restricts how resources can be shared cross-origin.
  ///
  /// Default: `same-origin`.
  /// Set to `null` to omit the header.
  final String? crossOriginResourcePolicy;

  /// Prevents a document from loading cross-origin resources that
  /// don't explicitly grant permission.
  ///
  /// Default: `null` (omitted) — `require-corp` can break third-party
  /// resources. Set to `require-corp` or `credentialless` if needed.
  final String? crossOriginEmbedderPolicy;

  const SecurityHeadersConfig({
    this.xFrameOptions = 'DENY',
    this.xContentTypeOptionsNoSniff = true,
    this.xXssProtection = '0',
    this.strictTransportSecurity = 'max-age=15552000; includeSubDomains',
    this.contentSecurityPolicy = "default-src 'self'",
    this.referrerPolicy = 'no-referrer',
    this.xPermittedCrossDomainPolicies = 'none',
    this.xDnsPrefetchControl = 'off',
    this.crossOriginOpenerPolicy = 'same-origin',
    this.crossOriginResourcePolicy = 'same-origin',
    this.crossOriginEmbedderPolicy,
  });

  /// Creates the security headers middleware to be added to [pipelineBefore].
  ///
  /// The middleware applies the configured headers directly on the response
  /// and returns `null` so the pipeline continues to the route handler.
  MiddlewareNullable createMiddleware() {
    return (SparkyRequest request) async {
      final response = request.response;

      if (xFrameOptions != null) {
        response.headers.set('X-Frame-Options', xFrameOptions!);
      }
      if (xContentTypeOptionsNoSniff) {
        response.headers.set('X-Content-Type-Options', 'nosniff');
      }
      if (xXssProtection != null) {
        response.headers.set('X-XSS-Protection', xXssProtection!);
      }
      if (strictTransportSecurity != null) {
        response.headers
            .set('Strict-Transport-Security', strictTransportSecurity!);
      }
      if (contentSecurityPolicy != null) {
        response.headers
            .set('Content-Security-Policy', contentSecurityPolicy!);
      }
      if (referrerPolicy != null) {
        response.headers.set('Referrer-Policy', referrerPolicy!);
      }
      if (xPermittedCrossDomainPolicies != null) {
        response.headers.set(
            'X-Permitted-Cross-Domain-Policies', xPermittedCrossDomainPolicies!);
      }
      if (xDnsPrefetchControl != null) {
        response.headers.set('X-DNS-Prefetch-Control', xDnsPrefetchControl!);
      }
      if (crossOriginOpenerPolicy != null) {
        response.headers
            .set('Cross-Origin-Opener-Policy', crossOriginOpenerPolicy!);
      }
      if (crossOriginResourcePolicy != null) {
        response.headers
            .set('Cross-Origin-Resource-Policy', crossOriginResourcePolicy!);
      }
      if (crossOriginEmbedderPolicy != null) {
        response.headers
            .set('Cross-Origin-Embedder-Policy', crossOriginEmbedderPolicy!);
      }

      return null;
    };
  }
}
