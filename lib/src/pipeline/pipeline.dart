/// @author viniciusddrft

part of '../sparky_server_base.dart';

/// This pipeline class has (N) middleware that can occur before or after route processing.
final class Pipeline {
  final List<MiddlewareNulable> _mids = [];

  List<MiddlewareNulable> get mids => _mids;

  /// This function adds middleware.
  void add(MiddlewareNulable middleware) => _mids.add(middleware);
}
