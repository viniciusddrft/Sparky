---
name: Sparky Architecture Overview
description: Key architecture decisions and patterns in the Sparky Dart HTTP framework - file locations, naming conventions, extension patterns
type: project
---

Sparky is a Dart HTTP server framework. Key patterns:

- **Base class chain**: `SparkyBase` (in `sparky_server_base.dart`) -> `Sparky` (in `sparky_server.dart`) with `Logs` mixin
- **Part files**: `pipeline.dart` and `cache_manager.dart` are `part of` sparky_server_base.dart; `logs.dart` is `part of` sparky_server.dart
- **HttpRequest extensions**: `Expando`-based storage for path params, body cache, etc. in `extensions/http_request.dart`
- **Response class**: immutable `final class` with `const` named constructors for each HTTP status
- **Route types**: `Route` base -> `RouteHttp` (with method constructors like `.get`, `.post`) and `RouteWebSocket`
- **Middleware types**: `Middleware = Future<Response> Function(HttpRequest)`, `MiddlewareNullable = Future<Response?> Function(HttpRequest)` (guards/pipeline)
- **Pipeline**: class with `List<MiddlewareNullable>` for before/after processing
- **Feature modules**: each in own directory (cors/, jwt/, validator/, rate_limiter/, static_files/, security/)
- **Exports**: barrel file at `lib/sparky.dart` exports all public APIs
- **Tests**: single test file `test/sparky_test.dart` with groups for each feature
- **Language**: Portuguese comments in PLAN.md, English code/docs. Author prefers `final class` and `const` constructors.

**Why:** Understanding these patterns is essential for implementing new features consistently.
**How to apply:** New features should follow module-per-directory pattern, use `final class`, export from `lib/sparky.dart`.
