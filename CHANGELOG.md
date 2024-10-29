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
