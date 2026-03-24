# Welcome to Sparky

[Switch to English](README_EN.md)

Sparky é um pacote Dart para construção de APIs REST de forma simples, com suporte a WebSocket, autenticação JWT, CORS, rotas dinâmicas e muito mais.

## Features

- Rotas dinâmicas com path parameters (`:id`)
- Agrupamento de rotas com prefixo (`RouteGroup`)
- Cache automático nas rotas (diferenciado por método HTTP)
- Suporte a CORS configurável
- Sistema de logs (console, arquivo ou ambos)
- Suporte a WebSocket
- Autenticação JWT com expiração
- Pipeline antes e depois do middleware principal
- Serialização automática de Map/List para JSON
- Headers customizados na Response
- Graceful shutdown
- Parsing de JSON body, form-data e URL-encoded
- Limite de tamanho de body (`maxBodySize`)
- Timeout por request (`requestTimeout`)
- Compressão gzip (`enableGzip`, `gzipMinLength`)
- Rate limiting pronto para uso
- Servir arquivos estáticos com `StaticFiles`
- Helpers de content negotiation e cookies

## Como Usar

### Criando uma rota simples

```dart
import 'dart:io';
import 'package:sparky/sparky.dart';

void main() {
  final route1 = RouteHttp.get('/hello', middleware: (request) async {
    return const Response.ok(body: 'Olá mundo');
  });

  Sparky.server(routes: [route1]);
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

Sparky.server(routes: [
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
  Sparky.server(routes: [RouteTest(), RouteSocket()]);
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

  // Multipart form-data
  final multipart = await request.getBodyParams();

  return Response.ok(body: {'received': json});
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

### Como personalizar o ip e porta

```dart
Sparky.server(
  routes: [...],
  ip: '0.0.0.0',
  port: 8080,
);
```

### Como criar pipeline

Você pode adicionar N middlewares nas pipelines.

```dart
Sparky.server(
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
const cors = CorsConfig(
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
);
// Ou use CorsConfig.permissive() para desenvolvimento

Sparky.server(
  routes: [...],
  pipelineBefore: Pipeline()
    ..add(cors.createMiddleware()),
);
```

### Sistema de logs

Por padrão mostra e salva logs. Você pode configurar o tipo, o modo e o caminho do arquivo.

```dart
Sparky.server(
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

Sparky.server(routes: [websocket]);
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

Sparky.server(
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

Sparky.server(
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
Sparky.server(
  routes: [...],
  cacheTtl: const Duration(seconds: 30),
  cacheMaxEntries: 500,
);
```

### Limite de body e timeout

```dart
Sparky.server(
  routes: [...],
  maxBodySize: 10 * 1024 * 1024, // 10 MB
  requestTimeout: const Duration(seconds: 10),
);
```

### Servir arquivos estáticos

```dart
Sparky.server(
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
Sparky.server(
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

Sparky.server(
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

Sparky.server(
  routes: [...],
  securityContext: context,
);
```

### Graceful shutdown

```dart
final server = Sparky.server(routes: [...]);
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
