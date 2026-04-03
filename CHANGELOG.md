# 2.2.0

### Novas Funcionalidades

- **Parser multipart robusto**: Parsing real de `multipart/form-data` com suporte a upload de arquivos binários. `request.getMultipartData()` retorna `MultipartData` com `fields` (Map<String, String>) e `files`/`fileList` (Map/List de `UploadedFile`). Parser opera em bytes brutos (binary-safe). `UploadedFile` expõe `filename`, `bytes`, `contentType` e `size`.
- **Streaming de response (SSE)**: `Response.sse(stream)` para Server-Sent Events e `Response.stream(body: stream)` para download/streaming de arquivos grandes. `SseEvent` serializa no formato SSE wire protocol com suporte a `data`, `event`, `id` e `retry`.
- **Tratamento de erros estruturado**: Exceções tipadas (`NotFound`, `BadRequest`, `Forbidden`, `Unauthorized`, `Conflict`, `UnprocessableEntity`, `TooManyRequests`, `InternalServerError`, `BadGateway`, `ServiceUnavailable`) que mapeiam automaticamente para HTTP status codes com body JSON padronizado. `throw NotFound(message: 'User not found')` vira 404 com `{"errorCode": "404", "message": "User not found"}`.
- **Dependency injection por request**: `request.provide<T>(value)` / `request.read<T>()` / `request.tryRead<T>()` via Expando. Armazenamento por tipo, escopo por request. Funciona em guards, pipeline middlewares e handlers.
- **Suporte a isolates (cluster mode)**: `Sparky.cluster(factory, isolates: 4)` cria N isolates compartilhando a mesma porta. Factory deve ser função top-level ou estática. Retorna `SparkyCluster` com `.port` e `.close()`. Default: `Platform.numberOfProcessors` isolates.
- **Security headers (Helmet-style)**: `SecurityHeadersConfig().createMiddleware()` adiciona headers de segurança padrão — X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security, Content-Security-Policy, Referrer-Policy, Cross-Origin-Opener-Policy, Cross-Origin-Resource-Policy e mais. Todos configuráveis individualmente.
- **Test utilities**: `SparkyTestClient` que boota o servidor numa porta OS-assigned (port 0) com API limpa para GET/POST/PUT/PATCH/DELETE/HEAD. Importável via `package:sparky/testing.dart`.

### Breaking Changes

- **`Sparky.server` renomeado para `Sparky.single`**: O construtor principal agora é `Sparky.single(...)`. `Sparky.server` não existe mais.

---

# 2.1.0

### Melhorias de Segurança

- **CORS corrigido conforme a spec**: `Access-Control-Allow-Origin` não aceita múltiplas origins separadas por vírgula. Agora o middleware verifica o `Origin` do request e reflete a origin permitida. Quando `allowCredentials: true` com wildcard, reflete a origin do request ao invés de `*` (conforme exigido pela spec). Header `Vary: Origin` adicionado quando a resposta varia por origin.
- **JWT: remoção de padding base64url (RFC 7515/7519)**: Tokens gerados agora usam base64url sem padding (`=`), conforme exigido pelas RFCs. Tokens antigos com padding continuam sendo decodificados via `base64Url.normalize()`.
- **JWT: validação de algoritmo no `verifyToken`**: Previne ataques de *algorithm confusion* — agora verifica que o header especifica `HS256` antes de aceitar o token.

### Melhorias

- **Gzip em stream responses**: Responses baseadas em `Stream<List<int>>` (ex: arquivos estáticos via `StaticFiles`) agora são comprimidas com gzip quando `enableGzip: true` e o content-type é comprimível (text/*, application/json, etc.). Binários como imagens não são comprimidos.
- **`RateLimiter.maxClients` obrigatório com default**: Antes era `int?` — agora é `int` com default `10000`, garantindo que o mapa de clientes nunca cresce indefinidamente.
- **Encapsulamento do cache**: `cacheManager` público substituído por `_cacheManager` privado com métodos públicos `isCached()`, `getCachedResponse()` e `cacheResponse()`.
- **`Sparky.actualPort`**: Nova propriedade para obter a porta real quando usando `port: 0` (porta atribuída pelo OS).
- **Reorganização de `Response`**: Construtores mais usados (`created`, `internalServerError`, `noContent`, `tooManyRequests`, `serviceUnavailable`, etc.) separados no topo. Construtores raramente usados marcados com `@Deprecated` com mensagem indicando o construtor genérico.

### Breaking Changes

- **`MiddlewareNulable` renomeado para `MiddlewareNullable`**: Correção de typo no typedef público. Atualize `MiddlewareNulable` → `MiddlewareNullable` no seu código.
- **`RateLimiter.maxClients`** agora é `int` (não mais `int?`). O default `10000` mantém o comportamento anterior para quem não passava o parâmetro.
- **`SparkyBase.cacheManager`** não é mais acessível publicamente. Use `isCached()`, `getCachedResponse()` e `cacheResponse()`.

### Testes

- Adicionados testes para CORS (multi-origin, origin não permitida, wildcard, credentials + wildcard, preflight).
- Adicionados testes para gzip em stream responses (text comprimido, binário não comprimido).
- Adicionado teste para tokens JWT sem padding base64url.
- Todos os testes migrados de portas hardcoded para `port: 0` + `server.actualPort`, eliminando colisões de porta em CI.
- Total: 105 testes passando.

---

# 2.0.1

### Correções de Bugs

- **Cache em rotas dinâmicas**: Rotas com path parameters (`:param`) não são mais cacheadas, corrigindo bug onde `/users/2` retornava os dados de `/users/1` (cache usava o objeto `Route` como chave, ignorando os parâmetros reais).
- **`RouteGroup.flatten()` perdia `acceptedMethods`**: Rotas criadas com `RouteHttp.get()` dentro de um `RouteGroup` passavam a aceitar todos os métodos HTTP após o `flatten()`. Agora o `acceptedMethods` é preservado corretamente.
- **CORS double close**: O middleware de CORS fechava `request.response` diretamente e depois retornava um `Response`, fazendo o servidor tentar escrever na response já fechada (`HttpException: HTTP headers are not mutable`). Agora o preflight OPTIONS retorna um `Response` com os headers CORS sem manipular a response diretamente, e o `pipelineAfter` executa normalmente.

---

# 2.0.0

### Correções de Bugs

- **`runPipeline`**: Corrigida condição que sempre avaliava como `true` (`!= null` trocado por checagem correta de `isNotEmpty`).
- **Sistema de logs**: Reestruturada a lógica dos métodos `_openServerLog`, `_errorServerLog` e `_requestServerLog` para que o modo `LogConfig.writeLogs` funcione corretamente (antes o arquivo de log nunca era criado nesse modo).
- **Status 405**: Corrigido handler de "Method Not Allowed" que retornava status 404 em vez de 405.
- **Estado global no `RequestTools`**: Removidas variáveis top-level mutáveis (`_hash` e `_cache`) compartilhadas entre requisições concorrentes, substituídas por `Expando` para isolamento por request.
- **`_start()` async void**: Corrigido para `Future<void>`, com validações síncronas no construtor e binding assíncrono observável via `server.ready`.
- **JSON inválido nos erros**: Bodies de erro internos agora usam JSON válido com aspas duplas em vez de aspas simples.
- **Objetos `Route` temporários**: Removida criação desnecessária de `Route('/404', ...)` e `Route('/405', ...)` no `_internalHandler`, retornando `Response` diretamente.

### Novas Funcionalidades

- **Rotas dinâmicas com path parameters**: Suporte a segmentos dinâmicos usando sintaxe `:param` (ex: `/users/:id`, `/products/:category/:itemId`). Parâmetros acessíveis via `request.pathParams['id']`.
- **Parsing de JSON body e URL-encoded**: Novos métodos `getJsonBody()` (retorna `Map<String, dynamic>`), `getFormData()` (para `application/x-www-form-urlencoded`) e `getRawBody()` (body cru com cache) na extension `RequestTools`.
- **Suporte a CORS**: Nova classe `CorsConfig` com construtores `CorsConfig()` e `CorsConfig.permissive()`, e método `createMiddleware()` para adicionar ao pipeline. Trata preflight `OPTIONS` automaticamente.
- **Headers customizados na Response**: Novo campo opcional `Map<String, String>? headers` em todos os construtores de `Response`, aplicados automaticamente na resposta HTTP.
- **JWT com expiração e decodificação**: `generateToken()` agora aceita `Duration? expiresIn` e adiciona claims `iat` e `exp`. `verifyToken()` valida expiração automaticamente. Novo método `decodePayload()` para extrair dados do token.
- **Agrupamento de rotas (RouteGroup)**: Nova classe `RouteGroup` que permite agrupar rotas sob um prefixo comum (ex: `RouteGroup('/api/v1', routes: [...]).flatten()`).
- **Serialização automática para JSON**: O `body` da `Response` agora aceita `Object` (String, Map, List). Valores não-String são serializados automaticamente com `json.encode`.
- **Graceful shutdown**: Novo método `close()` no `Sparky` para encerrar o servidor de forma limpa, cancelando a subscription e fechando o arquivo de log.
- **try-catch global**: Erros não tratados em middlewares/handlers agora retornam `500 Internal Server Error` em vez de travar o servidor.
- **Cache diferenciado por método HTTP**: O cache agora usa a combinação de `Route` + método HTTP como chave, evitando que GET e POST na mesma rota compartilhem cache.
- **Nome do arquivo de log configurável**: Novo parâmetro `logFilePath` no construtor de `Sparky.server` (padrão: `'logs.txt'`).
- **`pipelineAfter` em WebSocket**: O `pipelineAfter` agora também é executado após conexões WebSocket.
- **`server.ready`**: Nova propriedade `Future<void> get ready` para aguardar o servidor estar pronto.

### Testes

- Adicionados 42 testes unitários e de integração cobrindo: validação de rotas, Response (status codes, auto-serialização, headers), JWT (geração, verificação, expiração, decodificação), route matching (estático e dinâmico), cache versioning, RouteHttp, RouteGroup, Pipeline, CorsConfig, integração HTTP completa (GET, POST, 404, 405, path params) e graceful shutdown.

### Breaking Changes

- O campo `body` de `Response` agora é do tipo `Object` internamente (acessado via getter `String get body`). Código existente que usa `String` continua funcionando sem alterações.
- `_CacheManager` agora requer o método HTTP como parâmetro em `verifyVersionCache`, `getCache` e `saveCache`.
- O construtor `Sparky.server` agora aceita `logFilePath` como parâmetro opcional.

---

# 1.1.1

- update packages!!!

## 1.1.0

- Cache Adicionado!!!

## 1.0.15

- Foram adicionados os metodos de requisição web que faltavam.

## 1.0.14

- export necessario para usar criar rotas com herança de route.

## 1.0.13

- Correção de bug em websocket quando ela recebe uma request get,post,put ou delete.

## 1.0.12

- Melhoria nos construtores de rotas.

## 1.0.11

- Topico novo adicionado no pubspec, e pequenas correções em construtores e nomes.

## 1.0.10

- Topicos adicionados no pubspec.

## 1.0.9

- Melhoria na doc da Pagina inicial.

## 1.0.8

- Mais opções de responses com contrutores com status prontos, melhoria no código de exemplo a parte do login jwt não estava de maneira adequada antes.

## 1.0.7

- Melhoria na função de validação de rotas repetidas.

## 1.0.6

- A vesão anterior foi com um commit a menos 😅

## 1.0.5

- Melhoria no sistema de busca de rotas antes a cada request ele fazia um lop de complexidade O(N) para achar a rota correta e executada, agora todas rotas são pré-carregadas no início da função em um map e acessadas diretamente com a complexidade O(1) o que entrega mais performance é mais perceptível em casos de grandes números de rotas.

## 1.0.4

- Melhoria no sistema de logs, agora ele não fecha o arquivo e reabre toda vez que precisar salvar uma nova informação.

## 1.0.3

- Correção de exemplo.

## 1.0.2

- Add doc english.

## 1.0.1

- Uptade doc.

## 1.0.0

- Initial version.
