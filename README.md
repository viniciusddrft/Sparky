# Welcome to Sparky

[Switch to English](README_EN.md)

Sparky é um pacote Dart para construção de APIs REST de forma simples, com suporte a WebSocket, autenticação JWT, CORS, rotas dinâmicas e muito mais.

## Features

- Rotas dinâmicas com path parameters (`:id`)
- Agrupamento de rotas com prefixo (`RouteGroup`)
- Guards por rota e por grupo
- Cache automático nas rotas (diferenciado por método HTTP, com TTL e limite de entradas)
- Suporte a CORS configurável (multi-origin, credentials, `Vary: Origin`)
- Sistema de logs (console, arquivo ou ambos)
- Suporte a WebSocket
- Autenticação JWT com expiração (HS256, sem padding base64url, validação de algoritmo)
- Pipeline antes e depois do middleware principal
- Serialização automática de Map/List para JSON
- Headers customizados na Response
- Graceful shutdown
- Parsing de JSON body, form-data e URL-encoded
- Limite de tamanho de body (`maxBodySize`)
- Timeout por request (`requestTimeout`)
- Compressão gzip para responses normais e streams (`enableGzip`, `gzipMinLength`)
- Rate limiting pronto para uso
- Servir arquivos estáticos com `StaticFiles` (ETag, Last-Modified, 304)
- Helpers de content negotiation e cookies
- Validação de request body (`Validator`)
- HTTPS/TLS nativo via `SecurityContext`
- Upload de arquivos com parser multipart robusto (binary-safe)
- Server-Sent Events (SSE) e streaming de responses
- Tratamento de erros estruturado com exceções tipadas (`NotFound`, `BadRequest`, `Forbidden`, etc.)
- Dependency injection por request (`provide<T>` / `read<T>` / `tryRead<T>`)
- Multi-isolate com `Sparky.cluster()` para escalar em múltiplos cores
- Security headers (Helmet-style) com `SecurityHeadersConfig`
- Test utilities com `SparkyTestClient`

## Como Usar

### Criando uma rota simples

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
  final route1 = RouteHttp.get('/hello', middleware: (request) async {
    return const Response.ok(body: 'Olá mundo');
  });

  Sparky.single(routes: [route1]);
}
```

### Rotas dinâmicas com path parameters

Defina segmentos dinâmicos com `:param` e acesse via `request.pathParams`.

```dart
final userRoute = RouteHttp.get('/users/:id', middleware: (request) async {
  final userId = request.pathParams['id'];
  return Response.ok(body: {'userId': userId, 'name': 'User $userId'});
});

final itemRoute = RouteHttp.get('/items/:category/:itemId', middleware: (request) async {
  return Response.ok(body: {
    'category': request.pathParams['category'],
    'itemId': request.pathParams['itemId'],
  });
});
```

### Agrupamento de rotas (RouteGroup)

Agrupe rotas sob um prefixo comum e use `flatten()` para expandir.

```dart
final apiRoutes = RouteGroup('/api/v1', routes: [
  RouteHttp.get('/users', middleware: (r) async => const Response.ok(body: {'users': []})),
  RouteHttp.get('/products', middleware: (r) async => const Response.ok(body: {'products': []})),
]);

Sparky.single(routes: [
  ...apiRoutes.flatten(), // gera /api/v1/users e /api/v1/products
]);
```

### Criando uma rota a partir de uma classe

```dart
final class RouteTest extends Route {
  RouteTest()
      : super('/test', middleware: (request) async {
          return const Response.ok(body: 'test');
        }, acceptedMethods: [
          AcceptedMethods.get,
          AcceptedMethods.post,
        ]);
}

final class RouteSocket extends Route {
  RouteSocket()
      : super('/socket', middlewareWebSocket: (WebSocket webSocket) async {
          webSocket.listen(print, onDone: () {
            webSocket.close();
          });
        });
}

void main() {
  Sparky.single(routes: [RouteTest(), RouteSocket()]);
}
```

### Serialização automática para JSON

O body da `Response` aceita String, Map ou List. Valores não-String são serializados automaticamente.

```dart
final route = RouteHttp.get('/data', middleware: (request) async {
  return const Response.ok(body: {'message': 'hello', 'items': [1, 2, 3]});
});
```

### Parsing de body (JSON, form-data, URL-encoded)

```dart
final route = RouteHttp.post('/submit', middleware: (request) async {
  // JSON body (application/json)
  final json = await request.getJsonBody();

  // URL-encoded (application/x-www-form-urlencoded)
  final form = await request.getFormData();

  return Response.ok(body: {'received': json});
});
```

### Upload de arquivos (multipart/form-data)

Parser robusto que opera em bytes brutos (binary-safe). Suporta múltiplos arquivos e campos texto.

```dart
final upload = RouteHttp.post('/upload', middleware: (request) async {
  final form = await request.getMultipartData();

  // Campos texto
  final description = form.fields['description'];

  // Arquivos
  for (final file in form.fileList) {
    print('${file.filename} (${file.size} bytes, ${file.contentType})');
    // file.bytes contém o Uint8List com os dados binários
  }

  // Ou acesse por nome do campo
  final avatar = form.files['avatar'];

  return Response.ok(body: {'filesReceived': form.fileList.length});
});
```

### Headers customizados na Response

```dart
final route = RouteHttp.get('/download', middleware: (request) async {
  return const Response.ok(
    body: 'conteúdo',
    headers: {
      'X-Custom-Header': 'valor',
      'Cache-Control': 'no-cache',
    },
  );
});
```

### Validação de request body

```dart
final schema = Validator({
  'name': [isRequired, isString, minLength(3)],
  'email': [isRequired, isString, isEmail],
  'age': [isRequired, isNum, min(18)],
});

RouteHttp.post('/register', middleware: (request) async {
  final body = await request.getJsonBody();
  final errors = schema.validate(body);
  if (errors.isNotEmpty) {
    return Response.badRequest(body: {'errors': errors});
  }
  return Response.created(body: {'ok': true});
});
```

### Guards por rota

Guards são middlewares que rodam antes do handler da rota. Se qualquer guard retornar uma `Response`, a rota não executa.

```dart
Future<Response?> authGuard(HttpRequest request) async {
  final token = request.headers.value('Authorization');
  if (token != null && authJwt.verifyToken(token)) return null;
  return const Response.unauthorized(body: {'error': 'Não autorizado'});
}

final route = RouteHttp.get('/admin',
  middleware: (r) async => const Response.ok(body: {'admin': true}),
  guards: [authGuard],
);
```

### Como personalizar o ip e porta

```dart
Sparky.single(
  routes: [...],
  ip: '0.0.0.0',
  port: 8080,
);
```

### Como criar pipeline

Você pode adicionar N middlewares nas pipelines.

```dart
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add((request) async {
      // Retorne null para continuar ou uma Response para interromper
      return null;
    }),
  pipelineAfter: Pipeline()
    ..add((request) async {
      print('Executado após a rota');
      return null;
    }),
);
```

### Suporte a CORS

```dart
// Múltiplas origins — o middleware reflete a origin do request se permitida
const cors = CorsConfig(
  allowOrigins: ['https://meuapp.com', 'https://admin.meuapp.com'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
);

// Com credentials (allowOrigins: ['*'] reflete a origin do request ao invés de *)
const corsWithCreds = CorsConfig(allowCredentials: true);

// Ou use CorsConfig.permissive() para desenvolvimento
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(cors.createMiddleware()),
);
```

### Sistema de logs

Por padrão mostra e salva logs. Você pode configurar o tipo, o modo e o caminho do arquivo.

```dart
Sparky.single(
  routes: [...],
  logConfig: LogConfig.showAndWriteLogs,
  logType: LogType.all,
  logFilePath: 'server.log', // padrão: 'logs.txt'
);
```

### Como usar WebSockets

```dart
final websocket = RouteWebSocket(
  '/ws',
  middlewareWebSocket: (WebSocket socket) async {
    socket.add('Hello World');
    socket.listen(
      print,
      onDone: () => socket.close(),
    );
  },
);

Sparky.single(routes: [websocket]);
```

### Autenticação JWT com expiração

```dart
const authJwt = AuthJwt(secretKey: 'minha-chave-secreta');

final login = RouteHttp.post('/login', middleware: (request) async {
  final data = await request.getJsonBody();

  final token = authJwt.generateToken(
    {'username': data['user']},
    expiresIn: const Duration(hours: 2),
  );

  return Response.ok(body: {'token': token});
});

Sparky.single(
  routes: [login],
  pipelineBefore: Pipeline()
    ..add((request) async {
      if (request.uri.path == '/login') return null;

      final token = request.headers.value('Authorization');
      if (token != null && authJwt.verifyToken(token)) {
        final payload = authJwt.decodePayload(token);
        print('Usuário: ${payload?['username']}');
        return null;
      }

      return const Response.unauthorized(
        body: {'error': 'Token ausente ou inválido'},
      );
    }),
);
```

### Cache de rotas

O cache é automático e diferenciado por método HTTP. Após a primeira execução, a rota retorna a resposta em cache. Chame `onUpdate()` para invalidar o cache.

```dart
final random = RouteHttp.get('/random', middleware: (request) async {
  final value = Random().nextInt(100);
  return Response.ok(body: {'value': value});
});

Sparky.single(
  routes: [random],
  pipelineBefore: Pipeline()
    ..add((request) async {
      random.onUpdate(); // invalida o cache, executa o código da rota
      return null;
    }),
);
```

Você também pode configurar TTL e limite máximo de entradas:

```dart
Sparky.single(
  routes: [...],
  cacheTtl: const Duration(seconds: 30),
  cacheMaxEntries: 500,
);
```

### Limite de body e timeout

```dart
Sparky.single(
  routes: [...],
  maxBodySize: 10 * 1024 * 1024, // 10 MB
  requestTimeout: const Duration(seconds: 10),
);
```

### Servir arquivos estáticos

```dart
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(
      StaticFiles(
        urlPath: '/public',
        directory: './static',
        maxFileSize: 5 * 1024 * 1024, // opcional
      ).createMiddleware(),
    ),
);
```

### Gzip

```dart
Sparky.single(
  routes: [...],
  enableGzip: true,
  gzipMinLength: 1024,
);
```

### Rate limit

```dart
final limiter = RateLimiter(
  maxRequests: 100,
  window: const Duration(minutes: 1),
  trustProxyHeaders: true, // use apenas atrás de proxy confiável
);

Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()..add(limiter.createMiddleware()),
);
```

### Content negotiation

```dart
RouteHttp.get('/data', middleware: (request) async {
  final preferred = request.preferredType(
    const ['application/json', 'text/html'],
  );
  if (preferred == 'text/html') {
    return Response.ok(body: '<h1>ok</h1>', contentType: ContentType.html);
  }
  return Response.ok(body: {'ok': true}, contentType: ContentType.json);
});
```

### Cookies

```dart
RouteHttp.get('/set-cookie', middleware: (request) async {
  final cookie = Cookie('session', 'token')
    ..httpOnly = true
    ..secure = true;
  return Response.ok(body: {'ok': true}, cookies: [cookie]);
});
```

### HTTPS/TLS

```dart
final context = SecurityContext()
  ..useCertificateChain('cert.pem')
  ..usePrivateKey('key.pem');

Sparky.single(
  routes: [...],
  securityContext: context,
);
```

### Server-Sent Events (SSE)

```dart
final sse = RouteHttp.get('/events', middleware: (request) async {
  final events = Stream.periodic(
    const Duration(seconds: 1),
    (i) => SseEvent(data: 'tick ${i + 1}', id: '${i + 1}', event: 'tick'),
  ).take(10);
  return Response.sse(events);
});
```

Para streaming de arquivos grandes ou downloads:

```dart
final download = RouteHttp.get('/download-csv', middleware: (request) async {
  final file = File('report.csv');
  return Response.stream(
    body: file.openRead(),
    contentType: ContentType('text', 'csv'),
    headers: {'Content-Disposition': 'attachment; filename="report.csv"'},
  );
});
```

### Tratamento de erros estruturado

Exceções tipadas que mapeiam automaticamente para HTTP status codes com body JSON padronizado.

```dart
RouteHttp.get('/users/:id', middleware: (request) async {
  final id = request.pathParams['id'];
  final user = await findUser(id);

  if (user == null) {
    throw NotFound(message: 'Usuário não encontrado', details: {'id': id!});
    // Retorna 404 com {"errorCode": "404", "message": "Usuário não encontrado", "id": "..."}
  }

  return Response.ok(body: user);
});
```

Exceções disponíveis: `BadRequest` (400), `Unauthorized` (401), `Forbidden` (403), `NotFound` (404), `MethodNotAllowed` (405), `Conflict` (409), `UnprocessableEntity` (422), `TooManyRequests` (429), `InternalServerError` (500), `BadGateway` (502), `ServiceUnavailable` (503).

### Dependency injection por request

Injete dependências em guards/middlewares e consuma em handlers.

```dart
Future<Response?> authGuard(HttpRequest request) async {
  final user = await authenticate(request);
  if (user == null) return const Response.unauthorized(body: 'Denied');
  request.provide<User>(user); // injeta no request
  return null;
}

RouteHttp.get('/profile',
  middleware: (request) async {
    final user = request.read<User>();        // lança se não existir
    final config = request.tryRead<Config>(); // retorna null se não existir
    return Response.ok(body: {'name': user.name});
  },
  guards: [authGuard],
);
```

### Security headers (Helmet-style)

Adiciona headers de segurança padrão com uma única linha no pipeline.

```dart
Sparky.single(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(SecurityHeadersConfig().createMiddleware()),
);
```

Headers aplicados por padrão: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `Content-Security-Policy: default-src 'self'`, `Referrer-Policy: no-referrer`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, entre outros. Cada header é configurável individualmente:

```dart
const headers = SecurityHeadersConfig(
  xFrameOptions: 'SAMEORIGIN',
  contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'",
  strictTransportSecurity: null, // omite o header
);
```

### Multi-isolate (cluster mode)

Escale o servidor em múltiplos cores da CPU.

```dart
// Factory DEVE ser função top-level ou estática
Sparky createServer(int isolateIndex) {
  return Sparky.single(
    port: 3000,
    shared: true, // obrigatório para cluster
    routes: [...],
  );
}

void main() async {
  final cluster = await Sparky.cluster(createServer, isolates: 4);
  print('Rodando na porta ${cluster.port} com 4 isolates');

  // Para encerrar:
  await cluster.close();
}
```

### Test utilities

`SparkyTestClient` boota o servidor numa porta OS-assigned para testes sem colisão de porta.

```dart
import 'package:sparky/testing.dart';
import 'package:test/test.dart';

void main() {
  late SparkyTestClient client;

  setUp(() {
    client = SparkyTestClient(routes: [myRoute]);
  });

  tearDown(() => client.close());

  test('GET /hello returns 200', () async {
    final response = await client.get('/hello');
    expect(response.statusCode, 200);
  });
}
```

### Graceful shutdown

```dart
final server = Sparky.single(routes: [...]);
await server.ready; // aguarda o servidor estar pronto

// Quando quiser parar:
await server.close();
```

### Como compilar para máxima performance

```bash
dart compile exe main.dart
```

## Contribuições

O projeto é totalmente open source e contribuições são muito bem-vindas.
