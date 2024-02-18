/// @author viniciusddrft

part of '../sparky_base.dart';

/// This pipeline class has (N) middleware that can occur before or after route processing.
final class Pipeline {
  final List<MiddlewareNulable> _mids = [];

  /// This function adds middleware.
  void add(MiddlewareNulable middlewareBefore) => _mids.add(middlewareBefore);
}
