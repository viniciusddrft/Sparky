// @author viniciusddrft

import 'dart:io';

import '../response/response.dart';
import '../route/route_http.dart';
import '../route/route_base.dart';
import 'openapi_document.dart';
import 'openapi_types.dart';

/// Builds a minimal Swagger UI page that loads the spec from [specUrl] (usually relative).
String buildSwaggerUiHtml({
  required String specUrl,
  required String cdnBase,
}) {
  final base = cdnBase.endsWith('/') ? cdnBase.substring(0, cdnBase.length - 1) : cdnBase;
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>API docs</title>
  <link rel="stylesheet" href="$base/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="$base/swagger-ui-bundle.js"></script>
  <script src="$base/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function () {
      window.ui = SwaggerUIBundle({
        url: ${_jsString(specUrl)},
        dom_id: '#swagger-ui',
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
        layout: 'StandaloneLayout'
      });
    };
  </script>
</body>
</html>
''';
}

String _jsString(String s) => jsonStringEscape(s);

/// Escapes [s] for use inside a single-quoted JavaScript string literal.
String jsonStringEscape(String s) {
  final buf = StringBuffer("'");
  for (final c in s.split('')) {
    if (c == r'\') {
      buf.write(r'\\');
    } else if (c == "'") {
      buf.write(r"\'");
    } else if (c == '\n') {
      buf.write(r'\n');
    } else if (c == '\r') {
      buf.write(r'\r');
    } else {
      buf.write(c);
    }
  }
  buf.write("'");
  return buf.toString();
}

/// If [openApi] is null or [OpenApiConfig.enabled] is false, returns [routes] unchanged.
///
/// Otherwise appends `GET` routes for the OpenAPI JSON and Swagger UI page after
/// [routes], so documentation paths override duplicates in the static route map.
List<Route> mergeOpenApiRoutes(List<Route> routes, OpenApiConfig? openApi) {
  if (openApi == null || !openApi.enabled) return routes;

  final document = buildOpenApiDocument(
    routes: routes,
    info: openApi.info,
    servers: openApi.servers,
  );

  final specPath = openApi.specPath;
  final docsPath = openApi.docsPath;

  final specRoute = RouteHttp.get(
    specPath,
    middleware: (_) async => Response.ok(
      body: document,
      contentType: ContentType.json,
    ),
  );

  final html = buildSwaggerUiHtml(
    specUrl: specPath,
    cdnBase: openApi.swaggerUiCdnBase,
  );

  final docsRoute = RouteHttp.get(
    docsPath,
    middleware: (_) async => Response.ok(
      body: html,
      contentType: ContentType.html,
    ),
  );

  return [...routes, specRoute, docsRoute];
}
