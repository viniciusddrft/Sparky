# Sparky — Revisão de Qualidade das Entregas

**Data:** 2026-04-03 (atualizado em 2026-04-03)
**Base:** branch `main`
**Testes:** 188/188 passando | Análise estática: 0 issues

---

## Resumo Executivo

| Entrega | Nota | Bloqueador? |
|---|---|---|
| Parser Multipart | 4.2/5 | ~~Parcial~~ **Corrigido** |
| SSE/Streaming | 4.2/5 | Não |
| Tratamento de Erros | 4.5/5 | Não |
| Dependency Injection | 4.3/5 | ~~Parcial~~ **Corrigido** |
| Test Utilities | 4.5/5 | Não |
| Suporte a Isolates | 4.2/5 | ~~Sim~~ **Corrigido** |
| Security Headers | 4.0/5 | Não |

**Veredicto:** ~~Isolates era o único bloqueador real para publicação.~~ Todos os bloqueadores de isolates foram corrigidos. Multipart e DI têm problemas menores que merecem atenção antes de uma release estável, mas não bloqueiam publicação.

---

## 1. Parser Multipart Robusto — 4.2/5

**Status:** ~~Funcional, mas com limitações notáveis.~~ **Corrigido.** Bug de header unquoted resolvido, cobertura de testes expandida.

### Pontos fortes
- Binary-safe com `Uint8List`
- Arquitetura limpa e bem separada (`MultipartData`, `UploadedFile`, parser)
- API pública via `request.getMultipartData()`
- 15 testes unitários e de integração

### Problemas corrigidos

#### ~~Bug no parsing de headers~~ — CORRIGIDO
`_extractHeaderParam()` agora suporta ambos os formatos per RFC 2046:
```
Content-Disposition: form-data; name="file"; filename="photo.jpg"   // ✅ quoted
Content-Disposition: form-data; name=file; filename=photo.jpg       // ✅ unquoted
```
A implementação tenta quoted primeiro (prioridade) e faz fallback para unquoted.

#### ~~Cobertura de testes incompleta~~ — CORRIGIDO
6 novos testes adicionados:
- Parâmetros unquoted
- Mix de quoted e unquoted no mesmo header
- Parts sem Content-Disposition (ignoradas corretamente)
- Upload de arquivo vazio (0 bytes)
- Múltiplos arquivos com mesmo field name (map guarda último, fileList guarda todos)
- Campos com caracteres especiais e emojis

### Problemas remanescentes (minor)
- Body inteiro é carregado em memória antes de processar — não adequado para uploads multi-GB. O código tem comentário reconhecendo isso como otimização futura.
- Boundary aparecendo dentro do conteúdo do arquivo não é testado (edge case raro)

---

## 2. Streaming de Response (SSE) — 4.2/5

**Status:** Boa implementação, pronta para uso.

### Pontos fortes
- Headers SSE corretos (`text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`)
- Wire protocol compliant (field ordering, multi-line data com `data:` prefix, blank line termination)
- Dual API: `Response.sse()` para eventos e `Response.stream()` para streaming raw
- 11+ testes dedicados

### Problemas encontrados

#### Sem tratamento de erro em streams (medium risk)
Se o stream lança exceção ou o cliente desconecta durante a transmissão, não há catch nem cleanup. Streams com erro propagam exceções não tratadas.

#### Gzip + SSE (edge case)
O servidor aplica gzip em streams SSE se o cliente aceitar. Gzip pode causar buffering que atrasa a entrega de eventos em tempo real. Não há teste validando essa interação.

#### Funcionalidades SSE ausentes (low impact)
- Sem suporte a comments SSE (`:comment`)
- Sem handling do header `Last-Event-ID` para reconexão
- Evento com `data: ''` (vazio) não testado

---

## 3. Tratamento de Erros Estruturado — 4.5/5

**Status:** Implementação sólida e bem testada. Pronta para produção.

### Pontos fortes
- 12 exception types (`BadRequest`, `NotFound`, `Unauthorized`, `Forbidden`, `Conflict`, `UnprocessableEntity`, `TooManyRequests`, `MethodNotAllowed`, `InternalServerError`, `BadGateway`, `ServiceUnavailable`) + base `HttpException`
- Mapeamento automático para HTTP status codes via const constructor
- JSON padronizado: `{"errorCode": "XXX", "message": "...", ...details}`
- Campo `details` opcional para informações adicionais
- Extensibilidade documentada (exemplo de `PaymentRequired` no código)
- **28 testes** cobrindo todos os tipos, custom exceptions, details e fallback

### Problemas encontrados

#### Catch-all silencioso (minor)
Blocos `catch (_) {}` suprimem falhas de `response.close()`. Se o response falha ao fechar, nenhum log é gerado.

#### Status codes ausentes (minor)
Faltam: `410 Gone`, `413 Payload Too Large`, `415 Unsupported Media Type`. Mitigado pelo fato de que `HttpException(status, message)` permite instanciação direta com qualquer status code.

---

## 4. Dependency Injection por Request — 4.3/5

**Status:** ~~API limpa e funcional, mas com limitação de type erasure que precisa ser documentada.~~ **Corrigido.** Problema de type erasure reavaliado — não existe em Dart. Testes expandidos, comportamento de override documentado.

### Pontos fortes
- API intuitiva: `provide<T>()`, `read<T>()`, `tryRead<T>()`
- Constraint `T extends Object` previne valores nulos
- Implementação mínima (26 linhas) sem bloat
- Funciona corretamente com isolates (cada isolate tem seu próprio Expando)
- Tipos genéricos são preservados em runtime (Dart não sofre type erasure como Java)
- 8 testes cobrindo fluxos principais e edge cases

### Problemas corrigidos

#### ~~Type erasure com generics~~ — FALSO POSITIVO
Reavaliado: Dart **preserva** tipos genéricos em runtime. `List<String>` e `List<int>` são chaves `Type` distintas. O problema reportado inicialmente não existe — verificado com testes que confirmam armazenamento independente de tipos genéricos.

#### ~~Override silencioso não documentado~~ — CORRIGIDO
Comportamento de override agora documentado no doc comment de `provide<T>()`. Chamar `provide<T>()` duas vezes com o mesmo tipo sobrescreve o valor anterior — isso é intencional e útil para cenários onde um middleware mais específico precisa substituir um valor default.

#### ~~Testes ausentes~~ — CORRIGIDO
Novos testes adicionados:
- Override de mesmo tipo (confirma que último valor prevalece)
- Tipos genéricos independentes (`List<String>` e `List<int>` coexistem)
- `tryRead` antes e depois de `provide`

### Problemas remanescentes (minor)
- Sem mecanismo de proteção contra override acidental (por design — simplicidade)
- Testes de herança de tipos (subclass registrada, superclass lida) não cobertos

---

## 5. Test Utilities — 4.5/5

**Status:** Excelente qualidade. Pronta para uso.

### Pontos fortes
- API intuitiva para todos os métodos HTTP (`get`, `post`, `put`, `patch`, `delete`, `head`)
- Auto JSON-encode de `Map`/`List` com `Content-Type` automático
- Port 0 (OS-assigned) para testes paralelos sem conflito
- Logging desabilitado por padrão (`LogConfig.none`)
- Cleanup adequado: fecha `HttpClient` e aguarda shutdown do server
- Extensamente dogfooded nos próprios testes do framework
- Factory methods flexíveis: `.boot()` e `.from()`

### Problemas encontrados

#### allowMalformed: true (minor)
Decodificação UTF-8 usa `allowMalformed: true`, silenciando erros de encoding. Pode mascarar problemas em testes.

#### Funcionalidades ausentes (nice-to-have)
- Sem helper para query parameters (requer construção manual do path)
- Sem suporte direto para multipart/form-data
- Método HEAD existe mas não tem teste dedicado no grupo de test client

---

## 6. Suporte a Isolates — 4.2/5

**Status:** ~~BLOQUEADOR~~ **Corrigido.** Todos os problemas críticos foram resolvidos.

### Pontos fortes
- `shared: true` para port sharing correto via kernel (SO_REUSEPORT)
- Handshake com `SendPort`/`ReceivePort` para comunicação
- Validação: rejeita port 0 com múltiplos isolates
- Factory pattern top-level evita problemas de serialização de closures
- Testes cobrindo happy path e cenários de falha

### Problemas corrigidos

#### ~~Await infinito no completer~~ — CORRIGIDO
`completer.future` agora tem `.timeout(Duration(seconds: 10))`. Se o worker não responde em 10s, o isolate é killed e lança `TimeoutException`.

#### ~~Sem error handling no spawn~~ — CORRIGIDO
Todo o loop de spawn está dentro de `try/catch` com rollback. Se qualquer worker falhar, todos os isolates já criados recebem signal de shutdown, são killed, e o main server é fechado antes de propagar o erro.

#### ~~Race condition no shutdown~~ — CORRIGIDO
`SparkyCluster.close()` agora usa `addOnExitListener` para aguardar cada isolate terminar (até 5s de timeout). Só faz `kill()` forçado se exceder o timeout.

#### ~~Sem canal de erro~~ — CORRIGIDO
`Isolate.spawn()` agora recebe `onError: receivePort.sendPort`. Erros nos workers são enviados como `[error, stackTrace]` e completam o completer com erro, propagando para o main isolate e ativando o rollback.

#### ~~ReceivePort leak~~ — CORRIGIDO
O `ReceivePort` é fechado tanto no path de sucesso quanto no path de timeout/erro.

### Problemas remanescentes (minor)
- Sem mecanismo de restart automático de workers que crasham em runtime (após startup bem-sucedido)
- Sem métricas de health dos workers

---

## 7. Security Headers (Helmet-style) — 4.0/5

**Status:** Implementação sólida. Pronta para uso com ressalva nos testes.

### Pontos fortes
- 11 headers de segurança implementados
- Defaults alinhados com best practices e Helmet v7:
  - CSP: `default-src 'self'`
  - HSTS: 180 dias com `includeSubDomains`
  - X-Frame-Options: `DENY`
  - X-XSS-Protection: `0` (correto para browsers modernos)
  - Referrer-Policy, X-DNS-Prefetch-Control, CORP/COOP/COEP, X-Permitted-Cross-Domain-Policies
- Totalmente configurável: cada header pode ser customizado ou desabilitado (`null`)
- Documentação excelente com rationale de segurança

### Problemas encontrados

#### Testes superficiais (should-fix)
Apenas 2 assertions (status code + presença de 2 headers). Não valida:
- Valores dos headers
- Configurações customizadas
- Headers desabilitados via `null`
- Os outros 9 headers

#### Funcionalidades ausentes (nice-to-have)
- Sem modo `Content-Security-Policy-Report-Only` para CSP
- Sem header `Permissions-Policy` (alternativa moderna)

---

## Plano de Ação Recomendado

### ~~Antes de publicar (must-fix)~~ — CONCLUÍDO
1. ~~**Isolates:** Adicionar timeout no completer, try-catch no spawn, graceful shutdown com await, canal de erro~~ — **FEITO**

### ~~Antes de publicar (should-fix)~~ — CONCLUÍDO
2. ~~**Multipart:** Corrigir regex de `_extractHeaderParam()` para aceitar parâmetros sem aspas~~ — **FEITO**
3. ~~**DI:** Documentar limitação de type erasure com generics~~ — **FEITO** (type erasure não existe em Dart; override documentado; testes adicionados)

### Antes de release estável (should-fix)
4. **Security Headers:** Expandir testes para cobrir todos os 11 headers e configurações custom
5. **SSE:** Adicionar tratamento de erro em streams

### Melhorias futuras (nice-to-have)
6. **Multipart:** Streaming parser para uploads grandes
7. ~~**DI:** Warning em override silencioso~~ — Override é por design, documentado
8. **SSE:** Suporte a comments e `Last-Event-ID`
9. **Test Utilities:** Helper para query params e multipart
10. **Isolates:** Restart automático de workers que crasham em runtime
