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
