/// Author: viniciusddrft
///
/// This file defines the base class for Sparky errors and several specific error types.
/// All internal errors within Sparky extend from the `SparkyError` base class.
library;

/// Base class for all internal Sparky errors.
///
/// This class is used as the foundation for all specific error types in Sparky,
/// implementing the `Exception` interface.
sealed class SparkyError implements Exception {}

/// Error thrown when Sparky is initialized with an empty set of routes.
///
/// At least one route is required for Sparky to function properly. This error indicates
/// that the provided routes list was empty.
final class ErrorRouteEmpty implements SparkyError {
  @override
  String toString() => 'Exception: Sparky booted with empty routes';
}

/// Error thrown when duplicate routes are detected during Sparky initialization.
///
/// Routes are identified by `(method, path)` for HTTP and by `path` for WebSocket.
/// Registering the same `(method, path)` twice — or any HTTP route on the same
/// path as a WebSocket route — triggers this error. The [duplicate] field
/// describes the colliding key (e.g. `GET /users` or `/chat`).
final class RoutesRepeated implements SparkyError {
  final String duplicate;

  RoutesRepeated() : duplicate = 'unknown';

  RoutesRepeated.duplicate(this.duplicate);

  @override
  String toString() =>
      'Exception: Sparky initialized with duplicate route: $duplicate';
}

