// @author viniciusddrft

import '../route/route_base.dart';
import 'openapi_types.dart';

/// Converts a Sparky path (`/users/:id`) to an OpenAPI path (`/users/{id}`).
String sparkyPathToOpenApi(String sparkyPath) {
  final segments = sparkyPath.split('/');
  final out = segments.map((seg) {
    if (seg.startsWith(':') && seg.length > 1) {
      return '{${seg.substring(1)}}';
    }
    return seg;
  });
  return out.join('/');
}

/// Builds an OpenAPI 3.0.3 document map from HTTP [routes].
///
/// Only routes with [Route.isHttpRoute] are included. Each [AcceptedMethods]
/// entry becomes a separate operation under the same path.
Map<String, Object?> buildOpenApiDocument({
  required List<Route> routes,
  required OpenApiInfo info,
  List<OpenApiServer>? servers,
}) {
  final paths = <String, Map<String, Object?>>{};

  for (final route in routes) {
    if (!route.isHttpRoute) continue;
    final pathKey = sparkyPathToOpenApi(route.name);
    final pathItem = paths.putIfAbsent(pathKey, () => <String, Object?>{});

    final pathParams = route.pathParameterNames;
    final autoParams = <Map<String, Object?>>[
      for (final name in pathParams)
        {
          'name': name,
          'in': 'path',
          'required': true,
          'schema': {'type': 'string'},
        },
    ];

    final methods = route.acceptedMethods;
    if (methods == null || methods.isEmpty) continue;

    for (final method in methods) {
      final opKey = method.text.toLowerCase();
      final meta = route.openApi;
      final operation = <String, Object?>{
        'responses': meta?.responses ??
            {
              '200': {
                'description': 'OK',
              },
            },
      };

      final userParams = meta?.parameters ?? const <Map<String, Object?>>[];
      final seen = <String>{};
      final mergedParams = <Map<String, Object?>>[];
      for (final p in userParams) {
        final key = '${p['name']}|${p['in']}';
        if (seen.add(key)) mergedParams.add(p);
      }
      for (final p in autoParams) {
        final key = '${p['name']}|${p['in']}';
        if (seen.add(key)) mergedParams.add(p);
      }
      if (mergedParams.isNotEmpty) {
        operation['parameters'] = mergedParams;
      }
      if (meta != null) {
        if (meta.summary != null) operation['summary'] = meta.summary!;
        if (meta.description != null) {
          operation['description'] = meta.description!;
        }
        if (meta.tags != null) operation['tags'] = meta.tags!;
        if (meta.requestBody != null) {
          operation['requestBody'] = meta.requestBody!;
        }
        if (meta.deprecated) operation['deprecated'] = true;
        if (meta.security != null) operation['security'] = meta.security!;
      }

      pathItem[opKey] = operation;
    }
  }

  return {
    'openapi': '3.0.3',
    'info': info.toJson(),
    if (servers != null && servers.isNotEmpty)
      'servers': [for (final s in servers) s.toJson()],
    'paths': paths,
  };
}
