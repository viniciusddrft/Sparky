// @author viniciusddrft

import '../openapi/openapi_types.dart';

/// A validation rule receives the field name, its value (nullable),
/// and returns an error message or `null` if valid.
typedef ValidationRule = String? Function(String field, Object? value);

/// Validates a [Map<String, dynamic>] against a set of rules per field.
///
/// ```dart
/// final schema = Validator({
///   'name': [isRequired, isString, minLength(3)],
///   'email': [isRequired, isString, isEmail],
///   'age': [isRequired, isNum, min(18)],
/// });
///
/// final errors = schema.validate(body);
/// if (errors.isNotEmpty) {
///   return Response.badRequest(body: {'errors': errors});
/// }
/// ```
final class Validator {
  final Map<String, List<ValidationRule>> _rules;

  /// Optional JSON Schema object (`type`, `properties`, `required`, …) describing
  /// the JSON request body for OpenAPI. Keep in sync with [_rules] manually or
  /// via code generation.
  final Map<String, Object?>? openApiBodySchema;

  const Validator(this._rules, {this.openApiBodySchema});

  /// Minimal [OpenApiOperation] with `requestBody` for `application/json`, or
  /// `null` when [openApiBodySchema] is null.
  OpenApiOperation? get openApiOperation {
    final schema = openApiBodySchema;
    if (schema == null) return null;
    return OpenApiOperation(
      requestBody: {
        'required': true,
        'content': {
          'application/json': {
            'schema': schema,
          },
        },
      },
    );
  }

  /// Validates [data] against the schema.
  /// Returns a map of field names to their first error message.
  /// An empty map means all fields are valid.
  Map<String, String> validate(Map<String, dynamic> data) {
    final errors = <String, String>{};
    for (final entry in _rules.entries) {
      final field = entry.key;
      final rules = entry.value;
      final value = data[field];

      for (final rule in rules) {
        final error = rule(field, value);
        if (error != null) {
          errors[field] = error;
          break;
        }
      }
    }
    return errors;
  }
}

// ──────────────────────────────────────────
// Built-in validation rules
// ──────────────────────────────────────────

/// The field must be present and non-null.
String? isRequired(String field, Object? value) =>
    value == null ? '$field is required' : null;

/// The value must be a [String].
String? isString(String field, Object? value) =>
    value != null && value is! String ? '$field must be a string' : null;

/// The value must be a [num] (int or double).
String? isNum(String field, Object? value) =>
    value != null && value is! num ? '$field must be a number' : null;

/// The value must be an [int].
String? isInt(String field, Object? value) =>
    value != null && value is! int ? '$field must be an integer' : null;

/// The value must be a [double].
String? isDouble(String field, Object? value) =>
    value != null && value is! double ? '$field must be a double' : null;

/// The value must be a [bool].
String? isBool(String field, Object? value) =>
    value != null && value is! bool ? '$field must be a boolean' : null;

/// The value must be a [List].
String? isList(String field, Object? value) =>
    value != null && value is! List ? '$field must be a list' : null;

/// The value must be a [Map].
String? isMap(String field, Object? value) =>
    value != null && value is! Map ? '$field must be a map' : null;

/// The string value must be a valid email address.
String? isEmail(String field, Object? value) {
  if (value == null || value is! String) return null;
  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return regex.hasMatch(value) ? null : '$field must be a valid email';
}

/// The string must have at least [length] characters.
ValidationRule minLength(int length) => (String field, Object? value) {
      if (value == null || value is! String) return null;
      return value.length >= length
          ? null
          : '$field must be at least $length characters';
    };

/// The string must have at most [length] characters.
ValidationRule maxLength(int length) => (String field, Object? value) {
      if (value == null || value is! String) return null;
      return value.length <= length
          ? null
          : '$field must be at most $length characters';
    };

/// The numeric value must be >= [minimum].
ValidationRule min(num minimum) => (String field, Object? value) {
      if (value == null || value is! num) return null;
      return value >= minimum ? null : '$field must be at least $minimum';
    };

/// The numeric value must be <= [maximum].
ValidationRule max(num maximum) => (String field, Object? value) {
      if (value == null || value is! num) return null;
      return value <= maximum ? null : '$field must be at most $maximum';
    };

/// The string must match the given [regex].
ValidationRule matches(RegExp regex, {String? message}) =>
    (String field, Object? value) {
      if (value == null || value is! String) return null;
      return regex.hasMatch(value)
          ? null
          : message ?? '$field has an invalid format';
    };

/// The value must be one of the allowed [values].
ValidationRule oneOf(List<Object> values) => (String field, Object? value) {
      if (value == null) return null;
      return values.contains(value)
          ? null
          : '$field must be one of: ${values.join(', ')}';
    };

/// The list must have at least [length] elements.
ValidationRule minItems(int length) => (String field, Object? value) {
      if (value == null || value is! List) return null;
      return value.length >= length
          ? null
          : '$field must have at least $length items';
    };

/// The list must have at most [length] elements.
ValidationRule maxItems(int length) => (String field, Object? value) {
      if (value == null || value is! List) return null;
      return value.length <= length
          ? null
          : '$field must have at most $length items';
    };

/// Custom validation with a user-provided predicate.
ValidationRule custom(bool Function(Object? value) predicate, String message) =>
    (String field, Object? value) => predicate(value) ? null : message;
