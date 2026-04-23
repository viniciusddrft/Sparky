// @author viniciusddrft
//
// @nodoc INTERNAL — Accept-header parsing for SparkyRequest.preferredType.
// Not exported from `package:sparky/sparky.dart`.

/// Picks the best match from [available] against the client's raw Accept
/// header value. Returns `null` when no candidate is acceptable.
///
/// Rules: higher `q` wins; ties broken by specificity (`text/html` beats
/// `text/*` beats `*/*`), then by order in the Accept header, then by
/// order in [available].
String? preferredMimeType(String? acceptHeader, List<String> available) {
  if (available.isEmpty) return null;
  if (acceptHeader == null || acceptHeader.trim().isEmpty) {
    return available.first;
  }

  final parsedAvailable = available
      .map(parseMediaType)
      .whereType<MediaType>()
      .toList(growable: false);
  if (parsedAvailable.isEmpty) return null;

  final ranges = parseAcceptHeader(acceptHeader);
  if (ranges.isEmpty) return available.first;

  MatchResult? bestMatch;
  for (var i = 0; i < parsedAvailable.length; i++) {
    final candidate = parsedAvailable[i];
    for (final range in ranges) {
      if (!range.matches(candidate)) continue;
      final result = MatchResult(
        availableIndex: i,
        quality: range.quality,
        specificity: range.specificity,
        acceptOrder: range.order,
      );
      if (bestMatch == null || result.isBetterThan(bestMatch)) {
        bestMatch = result;
      }
    }
  }

  return bestMatch != null ? available[bestMatch.availableIndex] : null;
}

List<AcceptRange> parseAcceptHeader(String headerValue) {
  final ranges = <AcceptRange>[];
  final parts = headerValue.split(',');
  for (var i = 0; i < parts.length; i++) {
    final rawPart = parts[i].trim();
    if (rawPart.isEmpty) continue;
    final pieces = rawPart.split(';');
    final mediaType = parseMediaType(pieces.first.trim());
    if (mediaType == null) continue;
    var quality = 1.0;
    for (final param in pieces.skip(1)) {
      final clean = param.trim();
      if (!clean.startsWith('q=')) continue;
      final parsed = double.tryParse(clean.substring(2).trim());
      if (parsed == null) continue;
      quality = parsed.clamp(0, 1).toDouble();
    }
    if (quality <= 0) continue;
    ranges.add(AcceptRange(
      type: mediaType.type,
      subtype: mediaType.subtype,
      quality: quality,
      order: i,
    ));
  }
  return ranges;
}

MediaType? parseMediaType(String value) {
  final parts = value.split('/');
  if (parts.length != 2) return null;
  final type = parts[0].trim().toLowerCase();
  final subtype = parts[1].trim().toLowerCase();
  if (type.isEmpty || subtype.isEmpty) return null;
  return MediaType(type, subtype);
}

final class MediaType {
  final String type;
  final String subtype;

  const MediaType(this.type, this.subtype);
}

final class AcceptRange {
  final String type;
  final String subtype;
  final double quality;
  final int order;

  const AcceptRange({
    required this.type,
    required this.subtype,
    required this.quality,
    required this.order,
  });

  bool matches(MediaType candidate) {
    final typeMatch = type == '*' || type == candidate.type;
    final subtypeMatch = subtype == '*' || subtype == candidate.subtype;
    return typeMatch && subtypeMatch;
  }

  int get specificity {
    if (type == '*' && subtype == '*') return 0;
    if (subtype == '*') return 1;
    return 2;
  }
}

final class MatchResult {
  final int availableIndex;
  final double quality;
  final int specificity;
  final int acceptOrder;

  const MatchResult({
    required this.availableIndex,
    required this.quality,
    required this.specificity,
    required this.acceptOrder,
  });

  bool isBetterThan(MatchResult other) {
    if (quality != other.quality) return quality > other.quality;
    if (specificity != other.specificity) {
      return specificity > other.specificity;
    }
    if (acceptOrder != other.acceptOrder) return acceptOrder < other.acceptOrder;
    return availableIndex < other.availableIndex;
  }
}
