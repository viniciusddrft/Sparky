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
