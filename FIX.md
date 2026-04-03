# Relatório de Review Técnico — Sparky

Este documento detalha os pontos de atenção, débitos técnicos e bugs identificados durante o review das funcionalidades marcadas como concluídas no `PLAN.md`.

---

## Análise de Prontidão para Produção

### 1. Parser Multipart Robusto (`lib/src/multipart/multipart.dart`)
*   **Status:** Funcional e "binary-safe".
*   **Débito Técnico:** O parser carrega o corpo inteiro da requisição na memória (`getRawBodyBytes`) antes do processamento. Uploads muito grandes podem consumir memória excessiva.
    *   **Mitigação existente:** O guard `maxBodySize` já rejeita bodies acima do limite com 413 antes de carregar, o que previne OOM em cenários configurados corretamente.
    *   **Melhoria futura:** Migrar para parser streaming com escrita direta em disco para uploads grandes.
*   **Alarme Falso:** A extração de parâmetros via Regex (`_extractHeaderParam`) é segura, pois browsers modernos sempre enviam valores entre aspas em `multipart/form-data`.

### 2. Streaming de Response (SSE) & `Response.stream`
*   **Status:** ✅ **Corrigido**.
*   **Melhoria realizada:** O `SseEvent.encode()` agora utiliza `RegExp(r'\r\n|\r|\n')` para garantir a normalização de qualquer tipo de quebra de linha no payload de dados.

### 3. Tratamento de Erros Estruturado (`lib/src/errors/http_exception.dart`)
*   **Status:** ✅ **Pronto para Produção**.

### 4. Dependency Injection (DI) (`lib/src/extensions/http_request.dart`)
*   **Status:** ✅ **Corrigido/Otimizado**.
*   **Melhoria realizada:** Substituído o uso de listas simples por `BytesBuilder(copy: false)` na leitura interna de bytes, reduzindo drasticamente as realocações de memória em requisições com corpo.

### 5. Test Utilities (`lib/src/testing/test_client.dart`)
*   **Status:** ✅ **Corrigido**.
*   **Melhoria realizada:** Adicionado o campo `bodyBytes` ao `TestResponse`. O cliente agora lê a resposta como bytes brutos antes de decodificar para String, permitindo testes de arquivos binários (imagens, PDFs, etc.) sem corrupção de dados.

### 6. Suporte a Isolates (`lib/src/sparky_server.dart`)
*   **Status:** ✅ **Pronto para Produção**.
*   **Alarme Falso:** O código já possui validação que impede o uso de `port: 0` com múltiplos isolates, garantindo que o usuário defina uma porta fixa para compartilhamento de socket seguro.

### 7. Security Headers (Helmet-style)
*   **Status:** ✅ **Pronto para Produção**.

---

## Resumo de Ações

| # | Ponto | Veredicto | Status |
|---|-------|-----------|--------|
| 1 | Multipart memória | Trade-off de design (mitigado) | Planejado (Streaming) |
| 2 | SSE quebra de linha | Corrigido para robustez total | **Concluído** ✅ |
| 3 | Error handling | Pronto para produção | **Concluído** ✅ |
| 4 | Otimização `BytesBuilder`| Memória mais eficiente | **Concluído** ✅ |
| 5 | TestResponse Bytes | Suporte a binários nos testes | **Concluído** ✅ |
| 6 | Isolates porta | Alarme falso (já validado) | **Concluído** ✅ |
| 7 | Security headers | Pronto para produção | **Concluído** ✅ |

O Sparky agora possui uma base sólida e testável tanto para dados textuais quanto binários, com uma gestão de memória otimizada para o modelo atual.
