/// Author: viniciusddrft
///
/// This file defines the `Pipeline` class, which manages a list of middleware functions
/// that can be executed before or after route processing in the Sparky server.

part of '../sparky_server_base.dart';

/// A class representing a pipeline of middleware functions.
///
/// The `Pipeline` class allows for the management and execution of multiple middleware functions.
/// These functions can be configured to run either before or after the processing of a route.
final class Pipeline {
  final List<MiddlewareNulable> _mids = [];

  /// Returns the list of middleware functions in the pipeline.
  ///
  /// The list is modifiable, allowing for the dynamic addition of middleware functions.
  List<MiddlewareNulable> get mids => _mids;

  /// Adds a middleware function to the pipeline.
  ///
  /// The [middleware] parameter is a function that conforms to the `MiddlewareNulable` type.
  /// This function will be executed as part of the pipeline.
  void add(MiddlewareNulable middleware) => _mids.add(middleware);
}
