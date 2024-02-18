/// @author viniciusddrft
/// Sparky error base class.
/// All internal errors have this class as implementation.
sealed class SparkyError implements Exception {}

/// This error occurs when Sparky is initialized with empty routes
/// at least one route is required.
final class ErrorRouteEmpty implements SparkyError {
  @override
  String toString() => 'Exception: Sparky booted with empty routes';
}

/// This error occurs when routes have repeated names
/// Sparky relies on the uniqueness of each route name for its proper functioning.
final class RoutesRepeated implements SparkyError {
  @override
  String toString() =>
      'Exception: Sparky initialized with routes with repeated names';
}

/// This is an unusual error; it occurs after the validation of duplicate routes. Multiple routes and 'not found' are still unmapped errors.
final class SparkyUnexpectedError implements SparkyError {
  @override
  String toString() =>
      'Exception: This is an unusual error; it occurs after the validation of duplicate routes. Multiple routes and not found are still unmapped errors.';
}
