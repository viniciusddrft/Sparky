// Author: viniciusddrft
//
// Server-Sent Events (SSE) data types.
//
// Use with `Response.sse()` to create SSE responses:
//
// ```dart
// RouteHttp.get('/events', middleware: (request) async {
//   final stream = Stream.periodic(
//     const Duration(seconds: 1),
//     (i) => SseEvent(data: 'tick $i', id: '$i'),
//   ).take(10);
//   return Response.sse(stream);
// });
// ```

/// Represents a single Server-Sent Event.
///
/// The [data] field is the event payload (required).
/// Optional fields [event], [id], and [retry] follow the SSE spec.
///
/// Use with `Response.sse()`:
/// ```dart
/// final events = Stream.fromIterable([
///   SseEvent(data: 'hello'),
///   SseEvent(data: 'world', event: 'greeting', id: '2'),
/// ]);
/// return Response.sse(events);
/// ```
final class SseEvent {
  /// The event data. Multi-line strings are supported.
  final String data;

  /// The event type (becomes the `event:` field). If null, the
  /// browser dispatches a generic `message` event.
  final String? event;

  /// The event ID (becomes the `id:` field). Used by the client
  /// to resume after a disconnection via `Last-Event-ID`.
  final String? id;

  /// Reconnection time in milliseconds (becomes the `retry:` field).
  final int? retry;

  const SseEvent({
    required this.data,
    this.event,
    this.id,
    this.retry,
  });

  /// Serializes this event to the SSE wire format.
  String encode() {
    final buffer = StringBuffer();
    if (id != null) buffer.writeln('id: $id');
    if (event != null) buffer.writeln('event: $event');
    if (retry != null) buffer.writeln('retry: $retry');
    // data field — each line must be prefixed with "data: "
    for (final line in data.split('\n')) {
      buffer.writeln('data: $line');
    }
    buffer.writeln(); // blank line terminates the event
    return buffer.toString();
  }
}
