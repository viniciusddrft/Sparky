// @author viniciusddrft

/// Metadata for the top-level OpenAPI [info](https://spec.openapis.org/oas/v3.0.3#info-object) object.
final class OpenApiInfo {
  final String title;
  final String version;
  final String? description;

  const OpenApiInfo({
    required this.title,
    required this.version,
    this.description,
  });

  Map<String, Object?> toJson() => {
        'title': title,
        'version': version,
        if (description != null) 'description': description,
      };
}

/// A single entry in `servers` (OpenAPI 3.0).
final class OpenApiServer {
  final String url;
  final String? description;

  const OpenApiServer({required this.url, this.description});

  Map<String, Object?> toJson() => {
        'url': url,
        if (description != null) 'description': description,
      };
}

/// Optional documentation attached to an HTTP [Route].
///
/// Maps to an OpenAPI [Operation Object](https://spec.openapis.org/oas/v3.0.3#operation-object).
/// Use [requestBody] and [responses] as raw OpenAPI maps when you need full control.
final class OpenApiOperation {
  final String? summary;
  final String? description;
  final List<String>? tags;

  /// OpenAPI `parameters` array — each entry is a raw Parameter Object with
  /// keys like `name`, `in` (`query`/`header`/`cookie`/`path`), `required`,
  /// `schema`, `description`.
  ///
  /// Path parameters declared here override the auto-generated ones for the
  /// same `name`, so you can upgrade a path param from the default `string`
  /// schema to `integer`/`uuid`/`enum` without duplicating it.
  final List<Map<String, Object?>>? parameters;

  /// OpenAPI `requestBody` object (e.g. `content`, `required`).
  final Map<String, Object?>? requestBody;

  /// OpenAPI `responses` object: status code or `default` → response object.
  final Map<String, Object?>? responses;

  final bool deprecated;

  /// OpenAPI `security` array (e.g. `[{'bearerAuth': []}]`).
  final List<Map<String, List<String>>>? security;

  const OpenApiOperation({
    this.summary,
    this.description,
    this.tags,
    this.parameters,
    this.requestBody,
    this.responses,
    this.deprecated = false,
    this.security,
  });
}

/// Enables OpenAPI 3.0 JSON and Swagger UI routes on the server.
///
/// Pass to [Sparky.single] as the `openApi` argument. Documentation routes are
/// appended after your routes so they take precedence if paths collide.
///
/// Defaults: [specPath] `/openapi.json`, [docsPath] `/docs`.
final class OpenApiConfig {
  /// When false, no routes are injected (same as omitting config).
  final bool enabled;

  final String specPath;
  final String docsPath;

  final OpenApiInfo info;
  final List<OpenApiServer>? servers;

  /// Base URL for Swagger UI assets (e.g. unpkg). Must host `swagger-ui-bundle.js`
  /// and `swagger-ui-standalone-preset.js` under this path.
  final String swaggerUiCdnBase;

  const OpenApiConfig({
    this.enabled = true,
    this.specPath = '/openapi.json',
    this.docsPath = '/docs',
    required this.info,
    this.servers,
    this.swaggerUiCdnBase =
        'https://unpkg.com/swagger-ui-dist@5.11.0',
  });
}
