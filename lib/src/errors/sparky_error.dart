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

/// Error thrown when duplicate route names are detected during Sparky initialization.
///
/// Sparky relies on each route having a unique name for correct operation. This error
/// indicates that there were repeated route names in the provided routes list.
final class RoutesRepeated implements SparkyError {
  @override
  String toString() =>
      'Exception: Sparky initialized with routes with repeated names';
}

