# Welcome to Sparky

[Switch to English](README_EN.md)

Sparky é pacote que ajuda na construção de apis rest de forma simples com suporte a websocket a autenticação jwt.

## Features

- Sistema de logs.
- Suporte a webSocket.
- Autenticação JWT.
- Pipeline antes e depois do middleware principal.

## Como Usar

## Criando uma rota simples

você pode usar esse construtor personalizado para aceitar apenas metodo get ou pode
usar o construtor normal e personalizar.

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';

void  main(){
  // Criação da rota passando um middleware que recebe todos os dados da request, e precisa retornar uma response.

  final  route1  =  RouteHttp.get('/teste', middleware: (request) async {
    return  Response.ok(body:  'Olá mundo');
  });
  
  // inicialização do Sparky passando uma lista de rotas.
  Sparky.server(routes: [route1]);
}
```

## Criando uma rota apartir de uma classe

ao criar uma rota apartir de uma classe você pode definir se será uma rota de websocket ou não
pode definir se ela vai aceitar somente um metodo get ou outros.

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';

final class RouteTest extends Route {
  RouteTest()
      : super('/test', middleware: (request) async {
          return Response.ok(body: 'test');
        }, acceptedMethods: [
          AcceptedMethods.get,
          AcceptedMethods.post,
        ]);
}

final class RouteSocket extends Route {
  RouteSocket()
      : super('/socket', middlewareWebSocket: (WebSocket webSocket) async {
          webSocket.listen((event) {
            print(event);
          }, onDone: () {
            webSocket.close();
          });
        });
}

void  main(){
  // inicialização do Sparky passando uma lista de rotas.
  Sparky.server(routes: [RouteTest(),RouteSocket()]);
}
```

## Como personalizar o ip e porta

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';
void  main(){
 Sparky.server(
  routes: [...],
  ip:  '0.0.0.0',
  port:  8080,
 );
}
```

## Como Criar pipeline

Você pode criar Adicionar N middlewares nas pipilenes .

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';
void  main(){
Sparky.server(
 routes: [...],
 // Executa depois de executar a rota.
 pipelineAfter:  Pipeline()..add((request)async  =>  null)..add((request)async  =>  null),
 // Executa antes de executar a rota, pode retornar null ou uma Response, se for retornado uma response ele não executa a rota principal.
 pipelineBefore:  Pipeline()..add((request) async {
   ......
   }),
  );
}
```

## Sistema de logs

Ele por padrão implicitamente tem essa configuração mas você pode mudar esse enum para mostrar só logs de erros, pode escolher entre só mostrar ou salvar em um arquivo 'logs.txt'

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';
void  main(){
 Sparky.server(
  routes: [...],
  logConfig:  LogConfig.showAndWriteLogs,
  logType:  LogType.all
 );
}
```

## Como usar WebSockets

Uma rota webSocket é uma Criada com essa classe RouteWebSocket e passada na lista de rotas como todas as outras, ela recebe um socket onde você pode ouvir e lidar com todos dados enviados e recebidos no socket.

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';
void  main(){
 final  websocket  =  RouteWebSocket(
  '/test',
  middlewareWebSocket: (WebSocket  socket) async {
   socket.add('Hello World');
   socket.listen(
    (event) {
     print(event);
    },
    onDone: () {
     socket.close();
    },
   );
  },
 );
 Sparky.server(
  routes: [websocket],
 );
}
```

## Como fazer um login simples com JWT

Aqui é gerado um token e antes de cada request ele verifica se a requisição é para rota de login e ignora caso seja true, caso contrario ele verifica o token de login e retorna null, isso deixa ele ir para a rota principal, caso contrario ele retorna a uma resposta de não autorizado.

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';
void  main(){
 final  authJwt  =  AuthJwt(secretKey:  'secretKey');
 
 final  login  = RouteHttp.get('/login', middleware: (HttpRequest  request) async {
    final token = authJwt.generateToken({'username': 'username'});
    return Response.ok(body: '{"token":"$token"}');
 });
 
 Sparky.server(
  routes: [login],
    pipelineBefore: Pipeline()
      ..add((HttpRequest request) async {
        if (request.requestedUri.path == '/login') {
          return null;
        } else {
          if (request.headers['token'] != null) {
            if (request.headers['token'] != null &&
                authJwt.verifyToken(request.headers['token']!.first)) {
              return null;
            } else {
              return Response.unauthorized(body: 'Não autorizado');
            }
          } else {
            return Response.unauthorized(body: 'Envie o token no header');
          }
        }
      }),
 );
}
```

## Como compilar para usar da maneira mais performática

O dart é uma linguagem compilada que compila para qualquer plataforma,  com o comando abaixo passando o arquivo do seu projeto você vai conseguir um executável muito mais performático.

```bash
dart compile exe main.dart
```

## Como funciona o cache

por padrão depois que uma rota rodar ela já vai ter cache e sempre retornara a mesma resonse,
para que o código dessa rota volte a funcionar e ele entregue um valor diferente é preciso chamar a função
'onUpdate' isso diz de forma explicita que não é para usar o cache e ele vai rodar o código da rota normalmente,
assim fica mais fácil de trabalhar com cache você pode adicionar no sistema de pipeline uma lógica para controlar se
o chace deve ser usado ou não, isso te permite controlar o cache de cada rota diretamente de maneira fácil.

```dart
import  'dart:io';
import  'package:sparky/sparky.dart';
void  main(){


  final random =
    RouteHttp.get('/random', middleware: (HttpRequest request) async {
    final value = Random().nextInt(100);
    return Response.ok(body: '{value:$value}');
  });

 Sparky.server(
  routes: [login],
    pipelineBefore: Pipeline()
      ..add((HttpRequest request) async {
       random.onUpdate();
      }),
 );
}
```

## Visão para o futuro

A ideia é sempre mante-lo simples, não adicionar complexidade a ideia é nas próximas atualizações deixar maneiras simples de fazer determinadas rotas rodar em uma isolates separada a partir de uma flag, para conseguir uma performance maior e adicionar testes, o projeto é totalmente código aberto e contribuições são muito bem vindas.
