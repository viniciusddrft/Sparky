## 1.0.5

- Melhoria no sistema de busca de rotas antes a cada request ele fazia um lop de complexidade O(N) para achar a rota correta e executala, agora todas rotas são precarregadas no inicio da função em um map e acessadas diretamente com a complecidade O(1) o que entrega mais performace é mais perceptivel em casos de grandes números de rotas.

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
