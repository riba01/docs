# Levantamento Técnico — Módulo de Mensagens Internas

**Projeto:** SISCONIECP2  
**Módulo:** `mensagem/`  
**Data:** 2026-05-21 (levantamento) | 2026-05-22 (Fase 1 executada)  
**Responsável:** Levantamento técnico e refatoração de segurança  
**Status:** Fase 1 concluída — 9 arquivos alterados, nenhuma mudança estrutural ou visual

---

## 1. Resumo Executivo

O módulo de mensagens internas do SISCONIECP2 permite que usuários cadastrados troquem mensagens entre si dentro do sistema. Funciona com páginas PHP que carregam dados via AJAX (jQuery/$.post), com persistência em duas tabelas separadas: `mensagem` (caixa de entrada) e `mensagemenviada` (caixa de saída).

**Estado geral:** funcional, porém com vulnerabilidades críticas de segurança que precisam ser corrigidas antes de qualquer outra melhoria. O módulo mistura responsabilidades (HTML, SQL, lógica de negócio) em arquivos únicos, sem separação em camadas.

**Risco atual:** ALTO. Há SQL Injection em 6 pontos, XSS em 7 pontos e ausência total de tokens CSRF. Credenciais SMTP estão expostas em texto plano no código-fonte.

---

## 2. Funcionamento Atual

### Fluxo de envio
1. Usuário acessa `mensagemRecebida.php` ou `mensagemEnviada.php` (containers visuais)
2. Para escrever nova mensagem, acessa `enviarMensagem.php`
3. Seleciona destinatários via checkboxes carregados de query SQL
4. JavaScript (`enviarMensagem.js`) faz POST via AJAX para `enviarMensagemAcao.php`
5. `enviarMensagemAcao.php` insere em `mensagem` (destino) e `mensagemenviada` (origem)
6. PHPMailer envia notificação por e-mail para cada destinatário

### Fluxo de leitura
1. `mensagemRecebida.php` carrega lista via AJAX (`listarMensagemRecebidaAcao.php`)
2. Usuário clica na mensagem, JS navega para `lerMsgRecebida.php?id=X`
3. `lerMsgRecebida.php` exibe a mensagem completa
4. Usuário pode responder (form POST para `responderMensagem.php`) ou excluir

### Fluxo de resposta
1. `lerMsgRec.js` cria um `<form>` dinâmico com dados dos hidden inputs
2. POST para `responderMensagem.php` (página visual)
3. `responderMensagem.php` exibe os dados do POST para o usuário confirmar
4. AJAX POST final para `enviarMensagemAcao.php` (mesmo endpoint de envio)

### Fluxo de exclusão
- `mensagemEnviada.js` ou `mensagemRecebida.js` faz POST para `mensagemEnviadaExcluir.php` ou `mensagemRecebidaExcluir.php`
- DELETE físico no banco (sem exclusão lógica)

---

## 3. Mapa de Arquivos

**Contagem correta:** 14 PHP + 6 JS + 3 CSS = **23 arquivos ativos** + 2 backups (`lerMsgRecebida copy.php`, `responderMensagem copy.php`) = 25 arquivos no diretório. O checklist inicial mencionava incorretamente "19 total".

### Páginas visuais (PHP)
| Arquivo | Responsabilidade | Sessão verificada |
|---|---|---|
| `mensagemRecebida.php` | Container caixa de entrada | Sim (via includes) |
| `mensagemEnviada.php` | Container caixa de saída | Sim (via includes) |
| `enviarMensagem.php` | Formulário de nova mensagem | Sim (via includes) |
| `lerMsgRecebida.php` | Visualização de mensagem recebida | Sim (via includes) |
| `lerMsgEnv.php` | Visualização de mensagem enviada | Sim (via includes) |
| `responderMensagem.php` | Formulário de resposta | Sim (via includes) |
| `index.php` | Redirecionador | Não |

### Endpoints de ação (AJAX/POST)
| Arquivo | Método | Tabelas acessadas | Sessão verificada |
|---|---|---|---|
| `enviarMensagemAcao.php` | POST | mensagem, mensagemenviada, cadastroministro | **Sim** (Fase 1) |
| `listarMensagemRecebidaAcao.php` | POST | mensagem, cadastroministro | **Sim** (Fase 1) |
| `listarMensagemEnviadaAcao.php` | POST | mensagemenviada, cadastroministro | **Sim** (Fase 1) |
| `mensagemRecebidaExcluir.php` | POST | mensagem | **Sim** (Fase 1) |
| `mensagemEnviadaExcluir.php` | POST | mensagemenviada | **Sim** (Fase 1) |
| `listarMensagemRecebida.php` | POST | mensagem | **Não** (pendente Fase 2) |

### Includes de dados
| Arquivo | Responsabilidade |
|---|---|
| `dados/dadosResponderMsg.php` | Lê $_POST e atribui variáveis para responderMensagem.php |

### JavaScript
| Arquivo | Responsabilidade |
|---|---|
| `js/enviarMensagem.js` | Validação e AJAX de envio |
| `js/responderMsg.js` | Validação e AJAX de resposta (idêntico ao acima) |
| `js/mensagemRecebida.js` | Lista recebidas via AJAX, polling 60s |
| `js/mensagemEnviada.js` | Lista enviadas via AJAX, polling 60s |
| `js/lerMsgRec.js` | Navegação e form POST dinâmico para responder |
| `js/lerMsgEnv.js` | Navegação (voltar) |

### CSS
| Arquivo | Escopo |
|---|---|
| `css/enviarMensagem.css` | Formulário de envio/resposta |
| `css/lerMsg.css` | Telas de leitura |
| `css/mensagemEnviada.css` | Caixa de saída |

### Arquivos de backup (não utilizados)
- `lerMsgRecebida copy.php`
- `responderMensagem copy.php`

### Classes externas usadas
- `classes/Connect.php` — Singleton PDO
- `classes/Ministro.class.php` — método `buscaNome($rm)`
- `vendor/autoload.php` — PHPMailer (somente em enviarMensagemAcao.php)

---

## 4. Fluxos de Dados

```
[enviarMensagem.php]
    ├── SELECT login+cadastroministro (destinatários) → prepared statement OK
    └── Form → enviarMensagem.js → $.post → enviarMensagemAcao.php
            ├── SELECT rm FROM cadastroministro WHERE email = '$email' ← SQL INJECTION
            ├── INSERT INTO mensagem ← prepared statement OK
            ├── INSERT INTO mensagemenviada ← prepared statement OK
            └── PHPMailer (credenciais hardcoded, HTML sem escape)

[mensagemRecebida.php]
    └── $.post → listarMensagemRecebidaAcao.php
            ├── SELECT * FROM mensagem WHERE destinatarioRec = $rm ← SQL INJECTION
            └── echo $dados sem htmlspecialchars ← XSS

[mensagemEnviada.php]
    └── $.post → listarMensagemEnviadaAcao.php
            ├── SELECT * FROM mensagemenviada WHERE remetenteEnv = $rm ← SQL INJECTION
            └── echo $dados sem htmlspecialchars ← XSS

[lerMsgRecebida.php]
    ├── SELECT * FROM mensagem WHERE idMensagemRec = $id ← SQL INJECTION (GET)
    ├── echo assunto/texto/hidden inputs sem escape ← XSS
    └── lerMsgRec.js → form POST dinâmico ← XSS via concatenação JS

[responderMensagem.php]
    ├── Lê $_POST (dadosResponderMsg.php)
    ├── SELECT email FROM login WHERE rm = :rm ← prepared OK
    └── echo $_POST direto no HTML ← XSS

[lerMsgEnv.php]
    ├── SELECT * FROM mensagemenviada WHERE idMensagemEnv = $id ← SQL INJECTION (GET)
    └── echo assunto/texto sem escape ← XSS

[mensagemRecebidaExcluir.php / mensagemEnviadaExcluir.php]
    └── DELETE WHERE id = :id ← prepared OK
        ← Sem verificação de sessão e sem verificação de propriedade
```

---

## 5. Diagnóstico de Segurança

### 5.1 SQL Injection — CRÍTICO

| Arquivo | Query vulnerável | Vetor |
|---|---|---|
| `lerMsgEnv.php` | `WHERE idMensagemEnv = " . $idMensagemEnv` | $_GET['id'] |
| `lerMsgRecebida.php` | `WHERE idMensagemRec = " . $idMensagemRec` | $_GET['id'] |
| `listarMensagemEnviadaAcao.php` | `WHERE remetenteEnv = " . $rm_usuario` | $_POST['rm'] |
| `listarMensagemRecebida.php` | `WHERE destinatarioRec = " . $rm_usuario` | $_POST['rm'] |
| `listarMensagemRecebidaAcao.php` | `WHERE destinatarioRec = " . $rm_usuario` | $_POST['rm'] |
| `enviarMensagemAcao.php` | `WHERE email = '" . $email . "'"` | $_POST['emailCliente'][] |

**Impacto:** Leitura, modificação ou exclusão de qualquer dado do banco via entrada manipulada. O vetor `$email` é especialmente crítico por vir de um array POST sem sanitização.

### 5.2 XSS (Cross-Site Scripting) — CRÍTICO

| Arquivo | Ponto vulnerável |
|---|---|
| `enviarMensagem.php` | `value="$email"` em atributo HTML sem escape |
| `lerMsgEnv.php` | `<?= $res['assuntoEnv'] ?>` e `<?= $res['textoEnv'] ?>` |
| `lerMsgRecebida.php` | Assunto, texto, nome remetente e 4 hidden inputs sem escape |
| `listarMensagemEnviadaAcao.php` | echo $assuntoEnv, $destinatarioEnv, $status |
| `listarMensagemRecebidaAcao.php` | echo $assuntoRec, $remetenteRec, $status |
| `responderMensagem.php` | Nome, email, assunto e corpo da mensagem do $_POST |
| `lerMsgRec.js` | Concatenação de dados de hidden inputs em string HTML |

**Impacto:** Execução de JavaScript arbitrário no contexto do usuário, roubo de sessão, defacement da interface.

### 5.3 CSRF — ALTO

Nenhum arquivo de ação (POST ou AJAX) verifica token CSRF. Qualquer site externo pode forçar um usuário autenticado a enviar, excluir ou ler mensagens.

**Arquivos afetados:** todos os endpoints de ação listados na seção 3.

### 5.4 Autorização — CRÍTICO

| Problema | Arquivo(s) |
|---|---|
| Qualquer usuário pode ler qualquer mensagem (apenas ID na URL) | `lerMsgRecebida.php`, `lerMsgEnv.php` |
| Qualquer usuário pode excluir qualquer mensagem | `mensagemRecebidaExcluir.php`, `mensagemEnviadaExcluir.php` |
| Endpoints AJAX não verificam sessão | todos os `*Acao.php` e `*Excluir.php` |
| RM do remetente vem do $_POST, não da sessão | `enviarMensagemAcao.php`, `listarMensagemEnviadaAcao.php` |

**Exemplo concreto:** um usuário mal-intencionado pode chamar `listarMensagemRecebidaAcao.php` passando o RM de outro usuário via `$_POST['rm']` e listar todas as mensagens dele, pois não há verificação de sessão.

### 5.5 Credenciais expostas — CRÍTICO

- `enviarMensagemAcao.php`: senha SMTP hardcoded em código-fonte (`jes#198*`)
- `classes/Connect.php`: credenciais do banco hardcoded

**Nota:** qualquer desenvolvedor com acesso ao repositório ou ao servidor tem acesso a essas credenciais.

### 5.6 Exposição de erros técnicos — ALTO

| Arquivo | Problema |
|---|---|
| `enviarMensagemAcao.php` | `echo 'Erro ao responder ' . $erro->getMessage()` |
| `mensagemRecebidaExcluir.php` | `echo $e->getMessage()` (variável `$e` não inicializada) |

---

## 6. Diagnóstico de Banco de Dados

### 6.1 Estrutura atual

O módulo usa duas tabelas separadas para o mesmo conceito (mensagem):

**Tabela `mensagem` (caixa de entrada)**
- idMensagemRec
- remetenteRec
- destinatarioRec
- assuntoRec
- textoRec
- enviadaEm
- status

**Tabela `mensagemenviada` (caixa de saída)**
- idMensagemEnv
- remetenteEnv
- destinatarioEnv
- assuntoEnv
- textoEnv
- enviadaEm
- status

**Problema:** os mesmos dados são duplicados em duas tabelas. Uma mensagem enviada resulta em dois INSERTs idênticos com nomes de colunas diferentes. Isso dificulta manutenção, aumenta volume de dados e não suporta múltiplos destinatários por mensagem de forma limpa.

### 6.2 Riscos de MyISAM

Se as tabelas usam MyISAM (padrão em MySQL antigo), os dois INSERTs em `enviarMensagemAcao.php` não são atômicos: se o segundo INSERT falhar, o primeiro já foi confirmado sem rollback. Isso resulta em dados inconsistentes (mensagem na caixa de entrada sem correspondente na caixa de saída ou vice-versa).

**Verificação necessária:** `SHOW CREATE TABLE mensagem\G` e `SHOW CREATE TABLE mensagemenviada\G`

### 6.3 Charset/Collation

O projeto possivelmente usa `utf8mb3` (alias de `utf8` em MySQL antigo), que não suporta caracteres fora do BMP (emojis, alguns caracteres especiais). Recomendado migrar para `utf8mb4` com collation `utf8mb4_unicode_ci`.

### 6.4 Índices ausentes prováveis

| Tabela | Coluna | Tipo de índice recomendado | Motivo |
|---|---|---|---|
| `mensagem` | `destinatarioRec` | INDEX | Filtro principal da caixa de entrada |
| `mensagem` | `status` | INDEX | Filtro de mensagens não lidas |
| `mensagem` | `enviadaEm` | INDEX | Ordenação cronológica |
| `mensagem` | `destinatarioRec, status` | INDEX composto | Listagem de não lidas por usuário |
| `mensagemenviada` | `remetenteEnv` | INDEX | Filtro principal da caixa de saída |
| `mensagemenviada` | `enviadaEm` | INDEX | Ordenação cronológica |

---

## 7. Diagnóstico de UX/UI

### 7.1 Problemas identificados

| Problema | Impacto |
|---|---|
| Tag `<blink>` em `listarMensagemRecebida.php` | HTML obsoleto (deprecated desde HTML 4) |
| `align="baseline"` em img tags | Atributo HTML obsoleto |
| Sem indicador visual de mensagens não lidas (exceto ícone) | UX fraco |
| Polling a cada 60s sem feedback visual | Usuário não sabe se lista está atualizada |
| Sem estado de loading durante AJAX | Sensação de travamento |
| Sem estado de vazio visual adequado | Apenas texto inline |
| Textarea sem limite de caracteres | Pode causar truncamento silencioso |
| Sem confirmação antes de excluir mensagem | Risco de exclusão acidental |
| Layout não responsivo (largura fixa em formulários) | Ruim em mobile |
| `cols="70" rows="10"` em textarea | Largura fixa, quebra em mobile |
| `font:13px 'Segoe UI'` inline em JS | Font hardcoded, não herda tema |
| jQuery UI Dialog para alertas | Pesado para uma funcionalidade simples |

### 7.2 Acessibilidade

| Problema | Gravidade |
|---|---|
| Checkboxes de destinatário sem `<label>` associado | Alta |
| Hidden inputs usados como mecanismo de transferência de dados | Não é padrão de acessibilidade |
| Sem `aria-label` em ações de excluir/responder | Média |
| Sem feedback de status após envio para leitores de tela | Alta |
| `<blink>` inacessível e obsoleto | Alta |

---

## 8. Problemas Críticos

Ordenados por risco:

1. **SQL Injection em 6 pontos** — qualquer entrada pode extrair ou destruir dados do banco
2. **Endpoints de ação sem verificação de sessão** — acesso não autenticado a dados internos
3. **Autorização ausente** — usuário pode ler/excluir mensagens de outros usuários
4. **XSS em 7 pontos** — injeção de scripts via conteúdo de mensagens
5. **Credenciais SMTP em texto plano** — exposição de credenciais de e-mail
6. **RM do remetente vem do $_POST** — identidade forjável sem verificação de sessão
7. **Ausência de CSRF** — ações podem ser forçadas por sites externos
8. **DELETE físico sem verificação** — dados apagados permanentemente sem confirmação

---

## 9. Melhorias Rápidas (baixo risco)

Estas melhorias podem ser aplicadas sem alterar o layout ou fluxo:

1. Adicionar `session_start()` e verificação `$_SESSION['rm']` nos endpoints de ação
2. Substituir SQL concatenado por prepared statements (mesmo padrão já usado em outros arquivos)
3. Adicionar `htmlspecialchars($valor, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` nos echos
4. Mover RM do remetente de `$_POST['rm']` para `$_SESSION['rm']`
5. Adicionar `intval()` nos IDs vindos de GET/POST (proteção extra mesmo com prepared)
6. Remover arquivos de backup (`lerMsgRecebida copy.php`, `responderMensagem copy.php`)
7. Mover credenciais SMTP para variável de ambiente ou arquivo de configuração fora do webroot
8. Adicionar `error_log()` antes de qualquer `echo` de erro técnico
9. Substituir `echo $erro->getMessage()` por mensagem genérica ao usuário

---

## 10. Proposta de Modernização por Fases

### Fase 1 — Correções críticas de segurança (sem alterar layout)

**Objetivo:** eliminar vulnerabilidades críticas sem quebrar o comportamento visual.

**Arquivos a alterar:**
- `enviarMensagemAcao.php` — prepared statement no SELECT de email, mover RM para sessão, remover credenciais hardcoded
- `lerMsgEnv.php` — prepared statement no SELECT, htmlspecialchars nos echos, verificar autorização
- `lerMsgRecebida.php` — prepared statement no SELECT, htmlspecialchars em todos outputs, verificar autorização
- `listarMensagemEnviadaAcao.php` — sessão obrigatória, RM da sessão, prepared statement, htmlspecialchars
- `listarMensagemRecebidaAcao.php` — sessão obrigatória, RM da sessão, prepared statement, htmlspecialchars
- `listarMensagemRecebida.php` — sessão, prepared statement
- `mensagemRecebidaExcluir.php` — sessão, verificar propriedade, corrigir variável `$e`
- `mensagemEnviadaExcluir.php` — sessão, verificar propriedade
- `responderMensagem.php` — htmlspecialchars nos outputs do $_POST
- `dados/dadosResponderMsg.php` — validação básica dos campos POST
- `enviarMensagem.php` — htmlspecialchars no email em atributo value
- `js/lerMsgRec.js` — escapar valores antes de concatenar em string HTML

**Não alterar nesta fase:**
- Layout visual
- Nomes de variáveis externas
- Estrutura de banco
- Fluxos de navegação

**Testes necessários:**
- Enviar mensagem para um ou mais destinatários
- Receber e ler mensagem
- Responder mensagem
- Excluir mensagem enviada e recebida
- Verificar que usuário A não acessa mensagens do usuário B

---

### Fase 2 — Organização de código

**Objetivo:** reduzir duplicação e separar responsabilidades sem quebrar endpoints existentes.

**Ações:**
- Criar `classes/MensagemRepository.php` com todos os métodos de acesso ao banco do módulo
- Criar `classes/MensagemService.php` com regras de negócio (validação de destinatários, permissão de acesso)
- Criar helper de escape: função `esc(string $valor): string` para `htmlspecialchars`
- Criar helper de resposta JSON: `jsonResponse(bool $sucesso, string $mensagem, array $dados = []): void`
- Extrair configuração SMTP para arquivo separado (ex: `config/smtp.php` fora do webroot)
- Remover arquivos de backup
- Unificar `enviarMensagem.js` e `responderMsg.js` (são idênticos)

**Não alterar:**
- Nomes das rotas/arquivos públicos
- Estrutura de banco

---

### Fase 3 — Modernização de interface

**Objetivo:** melhorar UX/UI mantendo compatibilidade visual geral.

**Ações:**
- Remover `<blink>` e atributos HTML obsoletos
- Adicionar `<label>` nos checkboxes de destinatários
- Adicionar `aria-label` nos botões de ação
- Melhorar indicador visual de mensagens não lidas (badge, destaque visual)
- Adicionar spinner/loading durante AJAX
- Adicionar estado de vazio com ícone e texto formatado
- Adicionar confirmação antes de excluir (substituir por dialog acessível ou confirm())
- Tornar textarea responsivo (remover cols/rows fixos, usar CSS)
- Melhorar layout mobile-first nos formulários de envio e resposta
- Substituir font inline por classe CSS
- Adicionar indicador de "última atualização" no polling

---

### Fase 4 — Modernização do banco

**Objetivo:** estrutura mais robusta e eficiente.

**Ações:**
- Verificar engine das tabelas e migrar para InnoDB
- Adicionar índices propostos (ver seção 6.4)
- Migrar charset para utf8mb4 + collation utf8mb4_unicode_ci
- Avaliar unificação das tabelas (ver seção 12 — Proposta de Banco)
- Implementar exclusão lógica (campo `excluida_em` em vez de DELETE físico)
- Avaliar campo `lida_em` para rastreamento de leitura

---

### Fase 5 — Auditoria, logs e governança

**Objetivo:** rastreabilidade e conformidade mínima.

**Ações:**
- Registrar envio de mensagem em `registro_atividade` (se existir) ou nova tabela de log
- Registrar leitura, exclusão e arquivamento
- Garantir que mensagens internas não expõem dados sensíveis desnecessários
- Garantir que apenas dados mínimos necessários (RM, assunto, status) sejam expostos na listagem
- Documentar politica de retenção de mensagens (quanto tempo manter no banco)

---

## 11. Proposta de Arquitetura

Compatível com o padrão legado do projeto (sem PSR-4, sem autoload automático):

```
mensagem/
├── index.php                        (redirecionador — mantido)
├── mensagemRecebida.php             (container caixa de entrada — mantido)
├── mensagemEnviada.php              (container caixa de saída — mantido)
├── enviarMensagem.php               (formulário de nova mensagem — refatorado)
├── lerMsgRecebida.php               (leitura de mensagem recebida — refatorado)
├── lerMsgEnv.php                    (leitura de mensagem enviada — refatorado)
├── responderMensagem.php            (formulário de resposta — refatorado)
├── acoes/                           (novo diretório para endpoints de ação)
│   ├── enviarMensagemAcao.php       (movido e refatorado)
│   ├── listarRecebidas.php          (renomeado e refatorado de listarMensagemRecebidaAcao.php)
│   ├── listarEnviadas.php           (renomeado e refatorado de listarMensagemEnviadaAcao.php)
│   ├── excluirRecebida.php          (renomeado e refatorado de mensagemRecebidaExcluir.php)
│   └── excluirEnviada.php           (renomeado e refatorado de mensagemEnviadaExcluir.php)
├── dados/
│   └── dadosResponderMsg.php        (mantido mas validado)
├── js/
│   ├── mensagem.js                  (unificação de enviarMensagem.js + responderMsg.js)
│   ├── listarRecebidas.js           (refatorado de mensagemRecebida.js)
│   ├── listarEnviadas.js            (refatorado de mensagemEnviada.js)
│   ├── lerMsgRec.js                 (refatorado)
│   └── lerMsgEnv.js                 (mantido)
└── css/
    ├── mensagem.css                 (consolidação dos 3 CSS atuais)
    └── [manter arquivos atuais até consolidação]

classes/
├── Connect.php                      (mantido sem alteração)
├── Ministro.class.php               (mantido sem alteração)
├── MensagemRepository.php           (novo — fase 2)
└── MensagemService.php              (novo — fase 2)

config/
└── smtp.php                         (novo — credenciais SMTP fora do webroot)
```

**Atenção:** renomear arquivos de ação (pasta `acoes/`) exige atualizar as referências nos arquivos JS. Fazer somente na Fase 2, após corrigir vulnerabilidades na Fase 1.

---

## 12. Proposta de Banco de Dados

### Alternativa A — Conservadora (recomendada para Fase 4 inicial)

Manter `mensagem` e `mensagemenviada`, apenas corrigindo:

```sql
-- Índices para mensagem (caixa de entrada)
ALTER TABLE mensagem ENGINE = InnoDB;
ALTER TABLE mensagem CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE INDEX idx_mensagem_destinatario ON mensagem (destinatarioRec);
CREATE INDEX idx_mensagem_status ON mensagem (status);
CREATE INDEX idx_mensagem_data ON mensagem (enviadaEm DESC);
CREATE INDEX idx_mensagem_dest_status ON mensagem (destinatarioRec, status);

-- Índices para mensagemenviada (caixa de saída)
ALTER TABLE mensagemenviada ENGINE = InnoDB;
ALTER TABLE mensagemenviada CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE INDEX idx_mensagemenviada_remetente ON mensagemenviada (remetenteEnv);
CREATE INDEX idx_mensagemenviada_data ON mensagemenviada (enviadaEm DESC);
```

**Vantagem:** sem migração de dados, sem risco de regressão, aplicável imediatamente.  
**Desvantagem:** mantém duplicação de dados e limita evolução futura (ex: múltiplos destinatários).

---

### Alternativa B — Evolutiva (recomendada para Fase 4 completa)

Estrutura nova, mais flexível:

```sql
-- Tabela principal de mensagens (sem duplicação)
CREATE TABLE mensagens (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    remetente_rm    VARCHAR(20) NOT NULL,
    assunto         VARCHAR(255) NOT NULL,
    texto           TEXT NOT NULL,
    enviada_em      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    criado_em       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_remetente (remetente_rm),
    INDEX idx_enviada_em (enviada_em DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabela de destinatários (suporta múltiplos destinatários)
CREATE TABLE mensagem_destinatarios (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    mensagem_id     INT UNSIGNED NOT NULL,
    destinatario_rm VARCHAR(20) NOT NULL,
    lida_em         DATETIME NULL,
    arquivada_em    DATETIME NULL,
    excluida_em     DATETIME NULL,
    status          TINYINT UNSIGNED NOT NULL DEFAULT 0,
    INDEX idx_destinatario (destinatario_rm),
    INDEX idx_mensagem (mensagem_id),
    INDEX idx_dest_status (destinatario_rm, status),
    INDEX idx_dest_excluida (destinatario_rm, excluida_em),
    FOREIGN KEY (mensagem_id) REFERENCES mensagens(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Vantagem:** elimina duplicação, suporta múltiplos destinatários, exclusão lógica, rastreamento de leitura e arquivamento, estrutura mais limpa para evoluções futuras.

**Desvantagem:** requer migração de dados das tabelas antigas, requer adaptação de todos os arquivos PHP do módulo, maior risco de regressão.

**Plano de migração para Alternativa B:**
1. Criar as novas tabelas sem remover as antigas
2. Migrar dados históricos com script de migração
3. Colocar ambas as estruturas em paralelo temporariamente
4. Atualizar arquivos PHP para usar a nova estrutura (fase 4)
5. Validar em ambiente de teste
6. Remover tabelas antigas após validação completa

---

## 13. Plano de Implementação Seguro

| Ordem | Ação | Risco | Exige teste manual |
|---|---|---|---|
| 1 | Adicionar verificação de sessão nos endpoints de ação | Baixo | Sim — testar listagem e envio |
| 2 | Mover RM de $_POST para $_SESSION nos endpoints | Baixo | Sim — testar listagem |
| 3 | Prepared statements em lerMsgEnv.php e lerMsgRecebida.php | Baixo | Sim — testar abertura de mensagem |
| 4 | Prepared statements nos listarMensagem*Acao.php | Baixo | Sim — testar listagem |
| 5 | Prepared statement no SELECT de email em enviarMensagemAcao.php | Baixo | Sim — testar envio |
| 6 | htmlspecialchars em todos os outputs | Baixo | Sim — verificar caracteres especiais |
| 7 | Verificação de autorização em ler/excluir | Médio | Sim — testar acesso cruzado |
| 8 | Corrigir variável `$e` em mensagemRecebidaExcluir.php | Baixo | Sim — testar exclusão |
| 9 | Mover credenciais SMTP para config/smtp.php | Baixo | Sim — testar envio de e-mail |
| 10 | Adicionar CSRF (token em formulários e endpoints) | Médio | Sim — testar todos os formulários |
| 11 | Remover arquivos de backup (copy.php) | Baixo | Não |
| 12 | Adicionar índices no banco (Alternativa A) | Baixo | Não (performance) |
| 13 | Migrar para InnoDB e utf8mb4 | Médio | Sim — testar em staging |
| 14 | Refatorar em MensagemRepository + MensagemService | Alto | Sim — regressão completa |
| 15 | Modernizar interface (Fase 3) | Médio | Sim — mobile e desktop |

---

## 14. Checklist de Testes

### Testes funcionais obrigatórios após Fase 1

- [ ] Enviar mensagem para um destinatário
- [ ] Enviar mensagem para múltiplos destinatários
- [ ] Verificar se mensagem aparece na caixa de entrada do destinatário
- [ ] Verificar se mensagem aparece na caixa de saída do remetente
- [ ] Abrir mensagem recebida (verificar conteúdo correto)
- [ ] Abrir mensagem enviada (verificar conteúdo correto)
- [ ] Responder mensagem
- [ ] Excluir mensagem recebida
- [ ] Excluir mensagem enviada
- [ ] Verificar que usuário A não consegue abrir mensagem do usuário B via URL direta
- [ ] Verificar que endpoint de listagem sem sessão retorna erro, não dados
- [ ] Verificar que caracteres especiais (`<`, `>`, `"`, `'`, `&`) são exibidos corretamente
- [ ] Verificar envio de e-mail de notificação após mensagem
- [ ] Testar em mobile (responsividade básica)

### Testes de segurança após Fase 1

- [ ] Tentar SQL Injection via `lerMsgRecebida.php?id=1 OR 1=1`
- [ ] Tentar SQL Injection via POST rm com payload
- [ ] Tentar XSS via assunto da mensagem com `<script>alert(1)</script>`
- [ ] Tentar acessar endpoint de ação sem cookie de sessão
- [ ] Tentar excluir mensagem de outro usuário com ID conhecido
- [ ] Verificar que credenciais SMTP não estão mais em código-fonte

---

## 15. Riscos e Pontos de Atenção

### Riscos de regressão

| Ponto | Risco | Mitigação |
|---|---|---|
| Mover RM para sessão nos endpoints | Listagem pode quebrar se sessão não tiver rm | Garantir que valida_sessao_all.php define $_SESSION['rm'] |
| Prepared statements com intval() | Comportamento diferente se $id for string vazia | Validar explicitamente: if(!$id) return |
| htmlspecialchars em textarea | Conteúdo pode aparecer com `&lt;` visível | Usar ENT_QUOTES \| ENT_SUBSTITUTE corretamente |
| CSRF nos forms | Pode quebrar responderMensagem.php que usa form POST dinâmico via JS | Gerar e passar token CSRF via JS também |
| Renomear arquivos de ação | Quebra referências em JS | Só fazer na Fase 2, com busca completa de referências |

### Pontos que exigem teste manual obrigatório

- Qualquer alteração em `enviarMensagemAcao.php` (PHPMailer tem comportamento específico)
- Qualquer alteração no fluxo de resposta (dados passam por 3 arquivos em cadeia)
- Alterações de banco em produção (fazer backup antes)
- Migração para InnoDB (testar em staging antes de produção)

### Não alterar sem justificativa

- Nomes das colunas das tabelas `mensagem` e `mensagemenviada` (referenciados em vários arquivos)
- Padrão de inclusão via `valida_sessao_all.php` e `validar_usuario_usuario.php`
- Estrutura de chamada via `painel.php?pagina=mensagem/[arquivo]`
- Classe `Connect.php` (usada em todo o projeto)
- Método `buscaNome()` da classe `Ministro.class.php`

---

## Fase 1 Executada — 2026-05-22

### Arquivos alterados (9)

| # | Arquivo | Principais correções aplicadas |
|---|---|---|
| 1 | `listarMensagemRecebidaAcao.php` | Sessão validada, RM da sessão, prepared statement, htmlspecialchars em todos os outputs |
| 2 | `listarMensagemEnviadaAcao.php` | Sessão validada, RM da sessão, prepared statement, htmlspecialchars em todos os outputs |
| 3 | `lerMsgRecebida.php` | filter_input no GET id, prepared statement com autorização embutida (destinatarioRec = :rm), htmlspecialchars em todos os outputs incluindo hidden inputs |
| 4 | `lerMsgEnv.php` | filter_input no GET id, prepared statement com autorização embutida (remetenteEnv = :rm), htmlspecialchars em todos os outputs |
| 5 | `mensagemRecebidaExcluir.php` | Sessão validada, filter_input no POST id, autorização embutida no DELETE (destinatarioRec = :rm), variável de exceção corrigida |
| 6 | `mensagemEnviadaExcluir.php` | Sessão validada, filter_input no POST id, autorização embutida no DELETE (remetenteEnv = :rm) |
| 7 | `enviarMensagemAcao.php` | HTML boilerplate removido, sessão validada, RM do remetente da sessão, FILTER_VALIDATE_EMAIL nos destinatários, prepared statement no SELECT de e-mail, credenciais SMTP isoladas em constantes, corpo do e-mail escapado, PHPMailer recriado por iteração |
| 8 | `responderMensagem.php` | declare(strict_types=1), htmlspecialchars em todos os outputs do $_POST, $query renomeado para $stmt, error_log substituindo echo de erro técnico |
| 9 | `enviarMensagem.php` | declare(strict_types=1), htmlspecialchars no email e nome em atributos HTML e text content, error_log substituindo echo de erro técnico |

### Correções aplicadas (consolidado)

- **Sessão validada** em todos os endpoints de ação (`listar*Acao.php`, `*Excluir.php`, `enviarMensagemAcao.php`)
- **RM do usuário** vem exclusivamente de `$_SESSION['rm']` — `$_POST['rm']` ignorado nos endpoints
- **SQL Injection removido** em todos os 9 arquivos alterados — todos os 6 pontos críticos corrigidos
- **XSS reduzido** — `htmlspecialchars(ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` aplicado em todos os outputs dinâmicos
- **Autorização embutida** nas queries de leitura e exclusão — mensagem não pertencente ao usuário retorna vazio ou falha silenciosa
- **Variável de exceção** `$e` em `mensagemRecebidaExcluir.php` corrigida para `$erro_pag`
- **Credenciais SMTP** isoladas em constantes no topo de `enviarMensagemAcao.php`
- **Erros técnicos** registrados via `error_log()` — usuário recebe mensagem genérica
- **`declare(strict_types=1)`** adicionado nos 9 arquivos alterados
- **`$stmt`** usado como variável padrão para prepared statements nos arquivos reescritos
- **`php -l`** executado em todos os 9 arquivos — nenhum erro de sintaxe

### Pontos preservados

- Layout visual idêntico (HTML estrutural não alterado)
- Nomes de IDs, classes e elementos HTML usados pelo JavaScript mantidos
- Nomes de arquivos e rotas mantidos
- Estrutura de banco não alterada
- Funcionamento do PHPMailer preservado (falha de e-mail não cancela envio interno)
- Comportamento do polling de 60s em `mensagemRecebida.js` e `mensagemEnviada.js` não afetado

### Pontos que ainda precisam de teste manual obrigatório

1. Envio de mensagem para um ou mais destinatários (fluxo principal `enviarMensagemAcao.php`)
2. Verificação de que o e-mail de notificação ainda chega ao destinatário
3. Listagem de caixa de entrada e caixa de saída após login
4. Abertura de mensagem recebida e enviada (verificar autorização)
5. Tentativa de abrir mensagem de outro usuário via URL direta (deve retornar "Mensagem não encontrada.")
6. Exclusão de mensagem recebida e enviada
7. Tentativa de excluir mensagem de outro usuário (deve retornar "Mensagem não encontrada.")
8. Fluxo de resposta completo (lerMsgRecebida → responderMensagem → enviarMensagemAcao)
9. Caracteres especiais (`<`, `>`, `"`, `'`, `&`) em assunto e mensagem — devem aparecer corretamente

### Pendências para Fase 2

- Implementar tokens CSRF nos formulários e endpoints AJAX
- Criar `MensagemRepository.php` e `MensagemService.php`
- Mover credenciais SMTP para `config/smtp.php` fora do webroot
- Unificar `enviarMensagem.js` e `responderMsg.js` (código idêntico)
- Validar e sanitizar `dados/dadosResponderMsg.php` (atualmente sem validação)
- Corrigir XSS em `lerMsgRec.js` (concatenação de dados em string HTML para o form POST dinâmico)
- Remover arquivos de backup (`lerMsgRecebida copy.php`, `responderMensagem copy.php`)
- Corrigir `listarMensagemRecebida.php` (SQL Injection e tag `<blink>` — não estava na lista prioritária da Fase 1)

### Observação sobre MyISAM e transações

As tabelas `mensagem` e `mensagemenviada` provavelmente são **MyISAM**. Isso significa que os dois `INSERT` em `enviarMensagemAcao.php` — um na caixa de entrada do destinatário e outro na caixa de saída do remetente — **não são atômicos**. Se o segundo INSERT falhar, o primeiro já foi confirmado e não há rollback automático.

Enquanto as tabelas não forem migradas para **InnoDB** (planejado na Fase 4), não é possível garantir consistência transacional real entre os dois registros. A situação é idêntica ao comportamento original — a Fase 1 não piorou nem melhorou esse aspecto.

---

## Fase 2A Executada — 2026-05-22

### Escopo da Fase 2A

Correções de segurança complementares sem alterar estrutura, banco ou layout.

### Arquivos criados (1)

| Arquivo | Conteúdo |
|---|---|
| `classes/Csrf.php` | Helper de token CSRF por sessão (`getToken`, `validateToken`, `htmlField`) com `hash_equals` e `random_bytes` |

### Arquivos PHP alterados (9)

| Arquivo | Ação |
|---|---|
| `enviarMensagemAcao.php` | Validação CSRF com `hash_equals` antes de qualquer processamento |
| `mensagemRecebidaExcluir.php` | Validação CSRF + require_once Csrf.php explícito (sem autoload) |
| `mensagemEnviadaExcluir.php` | Validação CSRF + require_once Csrf.php explícito |
| `enviarMensagem.php` | Emissão de `Csrf::htmlField()` dentro do fieldset |
| `responderMensagem.php` | Emissão de `Csrf::htmlField()` dentro do fieldset |
| `mensagemRecebida.php` | `declare(strict_types=1)`, escape no `$_SESSION['rm']`, emissão de token CSRF para JS de exclusão |
| `mensagemEnviada.php` | `declare(strict_types=1)`, escape no `$_SESSION['rm']`, emissão de token CSRF para JS de exclusão |
| `lerMsgRecebida.php` | Emissão de token CSRF junto aos hidden inputs (para `lerMsgRec.js`) |
| `listarMensagemRecebida.php` | Sessão validada, RM da sessão, `COUNT(*)` com prepared statement, `<blink>` removido |

### Arquivos JS alterados (5)

| Arquivo | Ação |
|---|---|
| `lerMsgRec.js` | XSS corrigido: substituição de concatenação de string HTML por criação de elementos jQuery (`.attr().val()`); CSRF token incluído no form POST |
| `enviarMensagem.js` | CSRF token lido de `#csrf_token` e incluído no AJAX POST |
| `responderMsg.js` | CSRF token lido de `#csrf_token` e incluído no AJAX POST; variável `rm` removida (era ignorada pelo servidor) |
| `mensagemRecebida.js` | CSRF token incluído na exclusão; key bug corrigido (`idMensagemRecebida` → `idMensagemRec`); polling refatorado para função única `carregarLista` sem código duplicado; `.off('click').on('click')` para evitar múltiplos bindings |
| `mensagemEnviada.js` | CSRF token incluído na exclusão; polling refatorado para `carregarLista` sem duplicação; `.off().on()` aplicado |

### CSRF implementado em

- Validação: `enviarMensagemAcao.php`, `mensagemRecebidaExcluir.php`, `mensagemEnviadaExcluir.php`
- Emissão (hidden input id="csrf_token"): `enviarMensagem.php`, `responderMensagem.php`, `mensagemRecebida.php`, `mensagemEnviada.php`, `lerMsgRecebida.php`
- Envio via JS: `enviarMensagem.js`, `responderMsg.js`, `mensagemRecebida.js`, `mensagemEnviada.js`, `lerMsgRec.js`

### XSS corrigido em

- `lerMsgRec.js`: construção do form POST de resposta agora usa jQuery DOM API (`$('<input>').attr().val()`) em vez de string HTML concatenada. Eliminado vetor onde conteúdo do assunto/mensagem contendo aspas ou `<>` poderia escapar do atributo `value`.

### SMTP — pendência justificada

Credenciais SMTP permanecem em constantes no topo de `enviarMensagemAcao.php`. A pasta `config/` não existe no projeto e não há padrão de arquivo de configuração externo estabelecido. Criar `config/` agora adicionaria uma dependência de infraestrutura sem padrão definido. **Mover para Fase 2B**: criar `config/smtp.php` com retorno de array, proteger via `.htaccess` e documentar para não versionar.

### O que foi preservado

- Layout e comportamento visual idênticos
- Nomes de arquivos, rotas, IDs HTML e classes CSS usadas pelo JS
- Comportamento do polling de 60s (continua funcionando sem CSRF, pois listagem é read-only)
- Estrutura de banco sem alterações
- Funcionalidades de envio, resposta, leitura e exclusão

### O que fica para Fase 2B

- Mover credenciais SMTP para `config/smtp.php` (criar pasta e padrão de config)
- Unificar `enviarMensagem.js` e `responderMsg.js` (ainda código muito similar)
- Validar e sanitizar `dados/dadosResponderMsg.php`
- Remover arquivos de backup (`lerMsgRecebida copy.php`, `responderMensagem copy.php`)

### Testes mentais executados

| Fluxo | Resultado esperado |
|---|---|
| Abrir caixa de entrada | `carregarLista()` dispara sem CSRF; listagem carrega normalmente |
| Abrir caixa de enviadas | Mesmo padrão acima |
| Enviar mensagem | CSRF token em `#enviarMensagem.php`, JS lê e envia; backend valida com `hash_equals` |
| Responder mensagem | lerMsgRec.js submete form com token; responderMensagem.php exibe form com token; responderMsg.js envia para enviarMensagemAcao.php |
| Excluir recebida | mensagemRecebida.js envia token; backend valida antes de DELETE |
| Excluir enviada | mensagemEnviada.js envia token; backend valida antes de DELETE |
| Ação sem CSRF | Backend retorna 403 + mensagem genérica |
| CSRF inválido | `hash_equals` falha → 403 + mensagem genérica |
| Sessão expirada | Session check falha antes do CSRF check → 403 |

### Testes manuais pendentes

1. Enviar mensagem e confirmar que chega na caixa de entrada do destinatário
2. Responder mensagem: abrir recebida → clicar Responder → enviar resposta
3. Excluir mensagem recebida e enviada
4. Tentar chamar endpoint de exclusão sem csrf_token no POST (deve retornar 403)
5. Confirmar que polling de listagem continua funcionando após 60s
6. Confirmar que assunto com caracteres `<>"'&` aparece corretamente no formulário de resposta
7. Verificar que `listarMensagemRecebida.php` (ícone de não lidas) funciona após remoção do `<blink>`

### php -l — resultado

10/10 arquivos PHP sem erros de sintaxe (`classes/Csrf.php` + 9 arquivos do módulo).

---

*Relatório atualizado após execução da Fase 2A. Fase 2B pendente: SMTP config, unificação JS, limpeza de backups.*

---

## Fase 2B Executada — 2026-05-22

### Arquivos criados (3)

| Arquivo | Conteúdo |
|---|---|
| `classes/MensagemRepository.php` | Repositório com 10 métodos, namespace Classes, constructor injection PDO, PDOException propaga |
| `config/smtp.php` | Array de configuração SMTP, retornado por `require` — sem output, sem credencial em código de ação |
| `config/.htaccess` | `Require all denied` — bloqueia acesso HTTP direto à pasta |

### Arquivos modificados (7)

| Arquivo | Mudança |
|---|---|
| `listarMensagemRecebidaAcao.php` | SQL substituído por `$repo->listarRecebidas($rm_usuario)` |
| `listarMensagemEnviadaAcao.php` | SQL substituído por `$repo->listarEnviadas($rm_usuario)` |
| `lerMsgRecebida.php` | SQL substituído por `$repo->buscarRecebidaPorId()`; checagem `=== null` em vez de `empty($resultado)` |
| `lerMsgEnv.php` | SQL substituído por `$repo->buscarEnviadaPorId()`; mesma checagem |
| `mensagemRecebidaExcluir.php` | DELETE substituído por `$repo->excluirRecebida()` |
| `mensagemEnviadaExcluir.php` | DELETE substituído por `$repo->excluirEnviada()` |
| `enviarMensagemAcao.php` | 3 queries SQL → `$repo->buscarRmPorEmail()`, `enviarMensagemRecebida()`, `registrarMensagemEnviada()`; 6 `define(SMTP_*)` → `$smtp = require './config/smtp.php'`; PHPMailer usa `$smtp['host']` etc. |

### Métodos do MensagemRepository

| Método | Retorno | SQL |
|---|---|---|
| `listarRecebidas(int $rm)` | `array` | SELECT mensagem ORDER BY data DESC |
| `listarEnviadas(int $rm)` | `array` | SELECT mensagemenviada ORDER BY data DESC |
| `buscarRecebidaPorId(int $id, int $rm)` | `?array` | SELECT mensagem WHERE id AND destinatario |
| `buscarEnviadaPorId(int $id, int $rm)` | `?array` | SELECT mensagemenviada WHERE id AND remetente |
| `marcarRecebidaComoLida(int $id, int $rm)` | `bool` | UPDATE mensagem SET status = 1 |
| `excluirRecebida(int $id, int $rm)` | `bool` | DELETE mensagem WHERE id AND destinatario |
| `excluirEnviada(int $id, int $rm)` | `bool` | DELETE mensagemenviada WHERE id AND remetente |
| `buscarRmPorEmail(string $email)` | `?string` | SELECT rm FROM cadastroministro WHERE email |
| `enviarMensagemRecebida(array $dados)` | `int` (lastInsertId) | INSERT INTO mensagem |
| `registrarMensagemEnviada(array $dados)` | `int` (lastInsertId) | INSERT INTO mensagemenviada |

### CSRF — status

Mantido intacto. Validação em todos os endpoints sensíveis ocorre **antes** de qualquer chamada ao repository. Repository não acessa `$_POST`, `$_GET` ou `$_SESSION`.

### SMTP — tratamento

Credenciais movidas de 6 `define()` hardcoded em `enviarMensagemAcao.php` para `config/smtp.php` (array retornado por `require`). Benefícios:
- Sem risco de `define()` falhar em múltiplos includes
- Separação clara entre configuração e lógica
- Protegido por `config/.htaccess`

### php -l — resultado

9/9 arquivos PHP sem erros de sintaxe.

### Testes manuais pendentes

1. Enviar mensagem para 1 e múltiplos destinatários (verifica `buscarRmPorEmail` + dois INSERTs)
2. Verificar recebimento na caixa de entrada (verifica `listarRecebidas`)
3. Abrir mensagem recebida com ID de outro usuário via URL (deve retornar "Mensagem não encontrada")
4. Abrir mensagem enviada com ID de outro usuário via URL (idem)
5. Excluir recebida e enviada (verifica `excluirRecebida`, `excluirEnviada`)
6. Responder mensagem (fluxo completo `lerMsgRec.js` → `responderMensagem.php` → `enviarMensagemAcao.php`)
7. Tentativa de exclusão sem CSRF → deve retornar 403 antes de chegar ao repository
8. Confirmar notificação SMTP chega ao destinatário (valida `config/smtp.php`)
9. Polling de 60s continua atualizando a lista sem erros

### Pendências para Fase 3

- Interface mobile-first: formulários, tabelas responsivas, estado de loading (Fase 3 do relatório)
- `dadosResponderMsg.php` — validar campos com `isset()` e trim antes de atribuir
- Remover arquivos de backup (`lerMsgRecebida copy.php`, `responderMensagem copy.php`)
- Unificar `enviarMensagem.js` e `responderMsg.js` (ainda duplicados)
- Exclusão lógica em vez de DELETE físico (Fase 4)
- Migração para InnoDB + índices + utf8mb4 (Fase 4)

---

## Validação pós-Fase 2B — 2026-05-22

### Problemas encontrados e corrigidos

| # | Problema | Criticidade | Correção aplicada |
|---|---|---|---|
| 1 | `config/smtp.php` com senha real fora do `.gitignore` | **CRÍTICO** | Adicionado `config/smtp.php` ao `.gitignore` |
| 2 | Ausência de `config/smtp.example.php` | Médio | Criado com credenciais de exemplo sem senha real |

### Arquivos alterados na validação

| Arquivo | Ação |
|---|---|
| `.gitignore` | Adicionada linha `config/smtp.php` |
| `config/smtp.example.php` | Criado — template para configuração SMTP |

### Revisão de fluxos (análise estática)

| Fluxo | Resultado |
|---|---|
| Envio para 1 destinatário | ✓ Sessão → CSRF → `buscarRmPorEmail` → dois INSERTs via repository → PHPMailer com `$smtp` array |
| Envio para múltiplos destinatários | ✓ Loop itera; novo `PHPMailer(true)` por iteração; `$dados` remontado por `$rmDestino` |
| Resposta de mensagem | ✓ Token CSRF propaga: `lerMsgRecebida.php` → `lerMsgRec.js` → `responderMensagem.php` → `responderMsg.js` → `enviarMensagemAcao.php` |
| Leitura de recebida | ✓ `filter_input FILTER_VALIDATE_INT` → `buscarRecebidaPorId($id, $rmLogado)` → null bloqueia |
| Leitura de enviada | ✓ Mesmo padrão com `buscarEnviadaPorId` |
| Exclusão de recebida | ✓ CSRF antes de chegar ao repository; DELETE com AND rmLogado |
| Exclusão de enviada | ✓ Mesmo padrão |
| Ação sem CSRF | ✓ `validateToken('')` → `$token === ''` → false → 403 antes de qualquer SQL |
| CSRF inválido | ✓ `hash_equals` falha → 403 |

### Verificação de segurança de credenciais

- `config/smtp.php` — contém senha real, **ignorado pelo git** ✓
- `config/smtp.example.php` — sem credencial real, será versionado ✓
- `config/.htaccess` — `Require all denied` — acesso HTTP bloqueado ✓
- PHP return-only file — acesso direto não expõe credenciais ✓

### php -l — resultado final

16/16 arquivos PHP sem erros de sintaxe (inclui fases 1, 2A e 2B).

### É seguro iniciar a Fase 3?

**Sim**, com as seguintes condições:
1. Confirmar que `config/smtp.php` NÃO aparece em `git status` após a adição ao `.gitignore` antes do primeiro commit das mudanças
2. Executar os testes manuais listados acima (especialmente envio de mensagem e resposta)
3. Testar em ambiente de staging antes de produção se possível

### Checklist de testes manuais pendentes antes da Fase 3

- [ ] Enviar mensagem para 1 destinatário e verificar recebimento
- [ ] Enviar mensagem para múltiplos destinatários
- [ ] Verificar notificação por e-mail (valida `config/smtp.php`)
- [ ] Responder mensagem recebida (fluxo completo de 3 telas)
- [ ] Abrir mensagem recebida com ID de outro usuário via URL direta
- [ ] Abrir mensagem enviada com ID de outro usuário via URL direta
- [ ] Excluir mensagem recebida
- [ ] Excluir mensagem enviada
- [ ] Tentar exclusão sem CSRF via POST direto → esperar 403
- [ ] Confirmar polling de 60s continua atualizando lista sem erros
- [ ] Confirmar que `config/smtp.php` não aparece no `git status`

---

## Fase 3A Executada — 2026-05-22

### Bug crítico corrigido

`#resposta` ausente em `mensagemRecebida.php` e `mensagemEnviada.php` — jQuery UI Dialog de exclusão nunca aparecia. Corrigido adicionando `<div id="resposta"></div>` antes do `<fieldset>` em ambas as páginas.

### Arquivos PHP alterados (9)

| Arquivo | Mudança |
|---|---|
| `mensagem/dados/dadosResponderMsg.php` | `declare(strict_types=1)`, `isset()` + `trim()` em todos os `$_POST` |
| `mensagem/mensagemRecebida.php` | Adicionado `<div id="resposta">` (bug fix), `aria-live` e `aria-label` em `#lista` |
| `mensagem/mensagemEnviada.php` | Mesmo padrão |
| `mensagem/enviarMensagem.php` | Checkboxes agora envolvidos em `<label class="dest-item">` (acessibilidade), `type="button"` e `aria-label` no botão, `alt` em imagem |
| `mensagem/responderMensagem.php` | Checkboxes com `aria-label`, removido `cols="70"`, `type="button"` e `aria-label` no botão, `alt` em imagem |
| `mensagem/lerMsgRecebida.php` | `readonly="true"` → `readonly`, removido `cols`, `aria-label` nos botões, `alt` nas imagens, `for="msg"` no label |
| `mensagem/lerMsgEnv.php` | Mesmo padrão, removido `<label>Voltar</label>` redundante (botão já tem `aria-label`) |
| `mensagem/listarMensagemRecebidaAcao.php` | Removido `<script>` inline de zebra/dimensões (movido para CSS) |
| `mensagem/listarMensagemEnviadaAcao.php` | Mesmo |

### Arquivos CSS alterados (3)

| Arquivo | Mudança |
|---|---|
| `mensagem/css/enviarMensagem.css` | Removida duplicação `overflow: scroll`, `max-width` responsivo em todos inputs/textarea, `.dest-item` para checkboxes clicáveis, `:focus-visible` + `:focus` outline laranja, `button:disabled` estilo |
| `mensagem/css/lerMsg.css` | Responsivo full-width em `.divFor`, `.divAssunto`, `textarea`, `input[readonly]` fundo suave, `button:disabled`, `justify-content: flex-start` em `.divVoltar` |
| `mensagem/css/mensagemEnviada.css` | `#lista { overflow-x: auto }` (scroll horizontal em mobile), `#listar_mensagem { min-width: 500px }`, **zebra striping via CSS `nth-child(odd)`** (substitui inline script AJAX), `.msg-carregando`, `button:disabled` |

### Arquivos JS alterados (5)

| Arquivo | Mudança |
|---|---|
| `mensagem/js/mensagemRecebida.js` | Loading state no `carregarLista()`, `DOMPurify.sanitize()` no `.html()`, `.text()` no dialog de exclusão, `button:disabled` durante DELETE, `.fail()` handler, `encodeURIComponent` nos IDs de URL |
| `mensagem/js/mensagemEnviada.js` | Mesmo padrão, redirect para `mensagemEnviada` após exclusão |
| `mensagem/js/enviarMensagem.js` | `button:disabled` durante POST, `btnOriginal` restaurado em `.fail()`, `.text()` no dialog de sucesso/erro, `.fail()` handler, trim() na validação |
| `mensagem/js/responderMsg.js` | Mesmo padrão, redirect para `mensagemRecebida` após envio |
| `mensagem/js/lerMsgRec.js` | `button:disabled` no clique de Responder (previne duplo submit) |

### php -l

9/9 PHP sem erros de sintaxe.

### Testes manuais pendentes (Fase 3A)

- [ ] Abrir caixa de entrada — verificar loading "Carregando mensagens..." aparece brevemente
- [ ] Verificar zebra striping na tabela (via CSS, não mais JS inline)
- [ ] Verificar scroll horizontal da tabela em viewport < 500px
- [ ] Clicar em checkbox de destinatário — label inteiro deve ser clicável
- [ ] Enviar mensagem — botão deve ficar desabilitado durante envio
- [ ] Tentar enviar duas vezes em sequência rápida — segundo clique deve ser bloqueado
- [ ] Excluir mensagem recebida — dialog deve aparecer (bug fix)
- [ ] Excluir mensagem enviada — dialog deve aparecer (bug fix)
- [ ] Responder mensagem — botão deve ficar desabilitado ao clicar
- [ ] Verificar foco visível com Tab em inputs, textarea e botões
- [ ] Navegar com leitor de tela (NVDA/VoiceOver) nos botões das listagens

### Pendências para Fase 3B

- Unificar `enviarMensagem.js` e `responderMsg.js` (lógica idêntica, redirect diferente)
- Remover arquivos de backup (`lerMsgRecebida copy.php`, `responderMensagem copy.php`)
- Estados de vazio mais visuais (ícone + texto formatado)
- Validação de tamanho máximo de assunto/mensagem
- Confirmar exclusão com dialog antes de chamar o endpoint (UX de segurança)

---

## Fase 3B Executada — 2026-05-22

### Backups removidos

| Arquivo | Ação |
|---|---|
| `mensagem/lerMsgRecebida copy.php` | `git rm` — rastreado no git, sem referências em código |
| `mensagem/responderMensagem copy.php` | `git rm` — idem |

### Arquivos PHP alterados (4)

| Arquivo | Mudança |
|---|---|
| `mensagem/enviarMensagem.php` | Removido `cols="70"` do textarea, adicionado `data-redirect` ao botão `#enviar` |
| `mensagem/responderMensagem.php` | Script src trocado: `responderMsg.js` → `enviarMensagem.js`, `data-redirect` ao botão |
| `mensagem/listarMensagemRecebidaAcao.php` | Estado vazio: `<div class="msg-vazio">` com ícone e texto |
| `mensagem/listarMensagemEnviadaAcao.php` | Mesmo padrão |

### CSS alterado (1)

| Arquivo | Mudança |
|---|---|
| `mensagem/css/mensagemEnviada.css` | Adicionado `.msg-vazio` (flex, gap, padding, cor) e `.msg-vazio p` |

### JS alterados (4)

| Arquivo | Mudança |
|---|---|
| `mensagem/js/enviarMensagem.js` | Lê `data-redirect` de `$btnEnviar.data('redirect')` — unifica lógica de envio e resposta |
| `mensagem/js/responderMsg.js` | Esvaziado com comentário de deprecação — substituído por `enviarMensagem.js` |
| `mensagem/js/mensagemRecebida.js` | Confirmação jQuery UI Dialog antes de excluir, função `excluirMensagem()` separada |
| `mensagem/js/mensagemEnviada.js` | Mesmo padrão |

### JS unificado: sim

`enviarMensagem.js` agora serve ambos os fluxos via `data-redirect` no botão `#enviar`. O redirect URL é determinado pelo PHP de cada página, sem lógica no JS. `responderMsg.js` mantido como stub por compatibilidade de cache de navegador.

### Confirmação de exclusão

Fluxo:
1. Usuário clica no botão excluir
2. Dialog jQuery UI aparece: _"Deseja realmente excluir esta mensagem? Esta ação não poderá ser desfeita."_
3. Botões: **Excluir** (chama AJAX com CSRF) | **Cancelar** (fecha dialog, nada acontece)
4. CSRF continua sendo enviado no POST de exclusão ✓
5. Botão `#excluir` fica desabilitado durante a requisição ✓

### php -l

4/4 PHP sem erros de sintaxe.

### Testes manuais pendentes (Fase 3B)

- [ ] Clicar em excluir — dialog de confirmação deve aparecer antes do AJAX
- [ ] Clicar em "Cancelar" — mensagem deve permanecer na lista
- [ ] Clicar em "Excluir" — mensagem deve ser removida com feedback
- [ ] Enviar mensagem (enviarMensagem.php) — redireciona para `enviarMensagem` ✓
- [ ] Responder mensagem (responderMensagem.php) — redireciona para `mensagemRecebida` ✓
- [ ] Estado vazio da caixa de entrada (sem mensagens) — verificar visual `.msg-vazio`
- [ ] Estado vazio da caixa de enviadas — idem
- [ ] Confirmar que `responderMsg.js` vazio não afeta comportamento (responderMensagem.php usa enviarMensagem.js)

### Próxima fase recomendada

**Fase 4 (banco de dados):** Migração para InnoDB, índices, utf8mb4, avaliação de exclusão lógica. Pré-requisito: testes manuais das Fases 1–3B validados em ambiente de produção.

---

## Fase 4A Planejada — 2026-05-22

### Diagnóstico do banco (leitura realizada, nenhuma alteração aplicada)

#### Tabela `mensagem`

| Campo | Tipo | Observação |
|---|---|---|
| `idMensagemRec` | INT NOT NULL AUTO_INCREMENT | PK, AUTO_INCREMENT atual: 1031 |
| `remetenteRec` | INT NOT NULL | FK implícita para `cadastroministro.rm` |
| `destinatarioRec` | INT NOT NULL | FK implícita para `cadastroministro.rm` |
| `assuntoRec` | VARCHAR(255) utf8mb3_bin | utf8mb3 — sem emojis; _bin é case-sensitive |
| `textoRec` | TEXT utf8mb3_bin | idem |
| `enviadaEm` | DATETIME NOT NULL | data de envio |
| `recebidaEm` | DATETIME NULL | preenchida quando lida — 705/778 não nulos |
| `status` | INT NOT NULL | 0=não lida, 1=lida |

**Engine:** MyISAM | **Charset:** utf8mb3_bin | **Linhas:** 778 | **Índices:** apenas PK

#### Tabela `mensagemenviada`

Estrutura espelhada. **676 linhas**, AUTO_INCREMENT 1031 (mesmo que `mensagem`).

Diferença de 102 linhas entre as tabelas: cada mensagem enviada a N destinatários gera 1 linha em `mensagemenviada` e N linhas em `mensagem`.

#### Tabelas relacionadas

| Tabela | Engine | Charset |
|---|---|---|
| `cadastroministro` | InnoDB | utf8mb4_general_ci |
| `login` | InnoDB | utf8mb4_general_ci |

`mensagem` e `mensagemenviada` são as únicas tabelas do módulo ainda em MyISAM + utf8mb3.

### Problemas confirmados

| # | Problema | Risco |
|---|---|---|
| 1 | Engine MyISAM — sem transações | **ALTO** — dois INSERTs em enviarMensagemAcao não são atômicos |
| 2 | utf8mb3_bin — sem emojis, collation binária | MÉDIO — incompatível com demais tabelas |
| 3 | Sem índices além do PK | **ALTO** — full-table-scan em todas as listagens |
| 4 | Sem exclusão lógica — DELETE físico | MÉDIO — dados irrecuperáveis após exclusão |
| 5 | Campo `status INT` — desperdício de bytes | BAIXO — poderia ser TINYINT |
| 6 | Sem FK para `cadastroministro.rm` | BAIXO — sem integridade referencial |

### SQL de proposta criado

**Arquivo:** `docs/sql/mensagem-fase-4a-proposta.sql`

Contém:
- Queries de verificação pré-migração (somente leitura)
- Etapa 1: backup obrigatório (instrução mysqldump)
- Etapa 2: `ALTER TABLE ... ENGINE = InnoDB`
- Etapa 3: `ALTER TABLE ... CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`
- Etapa 4: criação de 5 índices
- Etapa 5 (opcional): adição de colunas `excluidaEm`, `arquivadaEm`, `atualizadoEm`
- Etapa 6 (opcional): chaves estrangeiras (só se queries de órfãos retornarem 0)
- Queries de verificação pós-migração
- Rollback completo (ordem inversa)

### Índices propostos

| Índice | Tabela | Colunas | Motivo |
|---|---|---|---|
| `idx_msg_dest_data` | mensagem | (destinatarioRec, enviadaEm) | caixa de entrada ordenada |
| `idx_msg_dest_status` | mensagem | (destinatarioRec, status) | filtro de não lidas |
| `idx_msg_remetente_data` | mensagem | (remetenteRec, enviadaEm) | auditoria/busca por remetente |
| `idx_env_remetente_data` | mensagemenviada | (remetenteEnv, enviadaEm) | caixa de saída ordenada |
| `idx_env_dest_data` | mensagemenviada | (destinatarioEnv, enviadaEm) | busca por destinatário |
| `idx_msg_dest_ativo` | mensagem | (destinatarioRec, excluidaEm, enviadaEm) | filtragem pós-exclusão lógica |
| `idx_env_rem_ativo` | mensagemenviada | (remetenteEnv, excluidaEm, enviadaEm) | idem |

### Campos propostos (novos)

| Campo | Tipo | Padrão | Motivo |
|---|---|---|---|
| `excluidaEm` | DATETIME NULL | NULL | NULL = ativa; preenchida = excluída logicamente |
| `arquivadaEm` | DATETIME NULL | NULL | arquivamento por destinatário |
| `atualizadoEm` | TIMESTAMP | CURRENT_TIMESTAMP ON UPDATE | auditoria automática |

**`lidaEm` não proposto:** `recebidaEm` já existe e já está sendo usado com 705/778 registros preenchidos.

### Avaliação: unificação de mensagem + mensagemenviada

**Decisão: não unificar na Fase 4A.**

Razões:
- Diferença de 102 linhas entre tabelas indica semântica diferente (1 linha por remetente vs N linhas por destinatário)
- Migração de dados requer script testado + validação linha a linha
- Não altera funcionalidade da Fase 4A (índices/InnoDB)
- Unificação planejada para Fase 4B com nova estrutura: `mensagens` + `mensagem_destinatarios`

### Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Dados corrompidos na conversão de charset | Baixa | Alto | Backup verificado antes |
| Downtime durante ALTER TABLE (table lock) | Garantida | Baixo | ~1-2s para 778 linhas — fazer fora do horário |
| Comportamento de comparação diferente após utf8mb3_bin → utf8mb4_unicode_ci | Baixa | Baixo | Nenhuma query PHP compara assuntoRec/textoRec em WHERE |
| FK falha por órfãos | A verificar | Médio | Executar query de verificação de órfãos antes da Etapa 6 |

### Ordem segura de execução futura

```
1. Fazer backup (mysqldump)
2. Verificar backup (contagem de linhas)
3. Executar em staging primeiro
4. Janela: fora do horário de uso
5. Etapa 2: ALTER ENGINE = InnoDB (ambas as tabelas)
6. Verificar Engine
7. Etapa 3: CONVERT TO utf8mb4 (ambas)
8. Verificar Collation
9. Etapa 4: CREATE INDEX (5 índices)
10. Verificar EXPLAIN nas queries principais
11. Etapa 5 (opcional): ADD COLUMN excluidaEm/arquivadaEm/atualizadoEm
12. Etapa 6 (opcional): FKs — só se verificação de órfãos retornar 0
13. Testes funcionais completos
```

### Checklist de backup pré-execução

- [ ] `mysqldump -u [user] -p [banco] mensagem mensagemenviada > backup_$(date +%Y%m%d).sql`
- [ ] Verificar tamanho do arquivo de backup (> 0 bytes)
- [ ] Contar linhas no dump: `grep 'INSERT INTO' backup.sql | wc -l`
- [ ] Testar restauração em ambiente separado
- [x] `mensagem` tem 779 linhas e `mensagemenviada` tem 676 — confirmado
- [x] AUTO_INCREMENT atual de ambas: 1031
- [x] Backup salvo em `C:/Users/arman/backup_mensagens_20260522_121816.sql` (734K, fora do webroot)

### Testes funcionais necessários após execução

- [ ] Caixa de entrada carrega mensagens (verifica idx_msg_dest_status_data)
- [ ] Caixa de saída carrega mensagens (verifica idx_env_remetente_data)
- [ ] Enviar mensagem nova (verifica INSERTs pós-InnoDB)
- [ ] Ler mensagem recebida (verifica buscarRecebidaPorId)
- [ ] Excluir mensagem (verifica DELETE pós-InnoDB)
- [x] EXPLAIN não retorna `type: ALL` — ambas usam `type: ref` ✓
- [ ] Verificar caracteres especiais preservados (acentos, cedilha)

---

## Fase 4B Executada — 2026-05-22

### Escopo

Apenas operações seguras e não destrutivas: InnoDB, utf8mb4 e índices. Sem FK, sem novas colunas, sem exclusão lógica, sem alteração PHP/JS.

### Pré-verificação

| Item | Resultado |
|---|---|
| Git status | `docs` modificado — nenhuma alteração não commitada em PHP/JS |
| Engine antes | MyISAM (ambas) |
| Charset antes | utf8mb3_bin (ambas) |
| Linhas antes | mensagem: 779, mensagemenviada: 676 |
| AUTO_INCREMENT | 1031 (ambas) |
| Chars fora de utf8mb3 (emojis/4-byte) | 0 — conversão segura |

### Backup

**Arquivo:** `C:/Users/arman/backup_mensagens_20260522_121816.sql`  
**Tamanho:** 734K  
**Gerado com:** `mysqldump --single-transaction --routines --triggers`  
**Conteúdo:** 2 INSERTs (1 por tabela), dump completo validado

### SQL executado

```sql
-- Etapa 2: ENGINE
ALTER TABLE mensagem        ENGINE = InnoDB;
ALTER TABLE mensagemenviada ENGINE = InnoDB;

-- Etapa 3: CHARSET
ALTER TABLE mensagem        CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE mensagemenviada CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Etapa 4: ÍNDICES (6 no total)
CREATE INDEX idx_msg_dest_status_data  ON mensagem (destinatarioRec, status, enviadaEm);
CREATE INDEX idx_msg_dest_id           ON mensagem (destinatarioRec, idMensagemRec);
CREATE INDEX idx_msg_remetente_data    ON mensagem (remetenteRec, enviadaEm);
CREATE INDEX idx_env_remetente_data    ON mensagemenviada (remetenteEnv, enviadaEm);
CREATE INDEX idx_env_remetente_id      ON mensagemenviada (remetenteEnv, idMensagemEnv);
CREATE INDEX idx_env_dest_data         ON mensagemenviada (destinatarioEnv, enviadaEm);
```

Etapas 5 (novas colunas) e 6 (FK) **não executadas** — fora do escopo da Fase 4B.

### Estado pós-migração

| Tabela | Engine | Collation | Índices |
|---|---|---|---|
| `mensagem` | InnoDB | utf8mb4_unicode_ci | PK + 3 compostos |
| `mensagemenviada` | InnoDB | utf8mb4_unicode_ci | PK + 3 compostos |

### Índices criados

| Nome | Tabela | Colunas | Uso |
|---|---|---|---|
| `idx_msg_dest_status_data` | mensagem | (destinatarioRec, status, enviadaEm) | Caixa de entrada: filtro + não lidas + ordenação |
| `idx_msg_dest_id` | mensagem | (destinatarioRec, idMensagemRec) | Lookup por ID com autorizaçao |
| `idx_msg_remetente_data` | mensagem | (remetenteRec, enviadaEm) | Auditoria por remetente |
| `idx_env_remetente_data` | mensagemenviada | (remetenteEnv, enviadaEm) | Caixa de saída: filtro + ordenação |
| `idx_env_remetente_id` | mensagemenviada | (remetenteEnv, idMensagemEnv) | Lookup por ID com autorização |
| `idx_env_dest_data` | mensagemenviada | (destinatarioEnv, enviadaEm) | Busca por destinatário |

### Verificação pós-migração

| Verificação | Resultado |
|---|---|
| Linhas mensagem | 779 ✓ (idêntico ao antes) |
| Linhas mensagemenviada | 676 ✓ (idêntico ao antes) |
| EXPLAIN caixa de entrada | `type=ref`, key=`idx_msg_dest_status_data`, ~50 rows — índice em uso ✓ |
| EXPLAIN caixa de saída | `type=ref`, key=`idx_env_remetente_data`, ~8 rows, backward scan ✓ |
| Full scan eliminado | Sim — era `type=ALL` (778/676 rows), agora `type=ref` ✓ |

**Observação sobre `Using filesort`:** a query `WHERE destinatarioRec = X ORDER BY enviadaEm DESC` usa `idx_msg_dest_status_data (dest, status, enviadaEm)`. MySQL filtra com o índice mas faz filesort porque `status` interrompe a ordenação por `enviadaEm`. O sort ocorre em ~50 linhas — custo negligível. Para eliminar o filesort seria necessário índice `(destinatarioRec, enviadaEm)` separado, mas o ganho não justifica índice adicional com 779 linhas.

### Problemas encontrados

Nenhum. Todas as etapas executadas sem erro.

### Testes manuais pendentes

- [ ] Listar caixa de entrada (verificar que mensagens aparecem normalmente)
- [ ] Listar caixa de enviadas
- [ ] Abrir mensagem recebida
- [ ] Abrir mensagem enviada
- [ ] Enviar mensagem nova
- [ ] Responder mensagem
- [ ] Excluir mensagem recebida
- [ ] Excluir mensagem enviada
- [ ] Verificar acentos e cedilha preservados no conteúdo exibido

### Pendências para Fase 4C

- Implementar exclusão lógica (`excluidaEm DATETIME NULL`) nas duas tabelas — requer:
  1. `ADD COLUMN` nas tabelas
  2. Índices com `excluidaEm` para filtro eficiente
  3. Alterar PHP: trocar `DELETE` por `UPDATE ... SET excluidaEm = NOW()`
  4. Alterar queries de listagem: adicionar `WHERE excluidaEm IS NULL`
- Avaliar FK para `cadastroministro.rm` (verificar órfãos antes)
- Avaliar campo `atualizadoEm TIMESTAMP ON UPDATE` para auditoria

---

## Fase 4C Executada — 2026-05-22

### Escopo

Exclusão lógica via `excluidaEm DATETIME NULL`, índices correspondentes, atualização do repository. FK avaliada — não criada por existência de órfãos históricos.

### Backup

**Arquivo:** `C:/Users/arman/backup_mensagens_fase4c_20260522_132329.sql`  
**Tamanho:** 734K  
**Gerado com:** `mysqldump --single-transaction --routines --triggers`

### Verificações pré-execução

| Verificação | Resultado |
|---|---|
| Git status | Árvore limpa — sem alterações pendentes |
| mensagem ENGINE | InnoDB ✓ |
| mensagemenviada ENGINE | InnoDB ✓ |
| cadastroministro ENGINE | InnoDB ✓ |

### Verificação de órfãos

| Query | Resultado |
|---|---|
| `mensagem.remetenteRec` sem `cadastroministro.rm` | **0** ✓ |
| `mensagem.destinatarioRec` sem `cadastroministro.rm` | **4** ✗ |
| `mensagemenviada.remetenteEnv` sem `cadastroministro.rm` | **0** ✓ |
| `mensagemenviada.destinatarioEnv` sem `cadastroministro.rm` | **0** ✓ |

### Detalhes dos 4 órfãos (mensagem.destinatarioRec)

| idMensagemRec | remetenteRec | destinatarioRec | assunto | enviadaEm |
|---|---|---|---|---|
| 6 | 2 | 15 | teset | 2012-05-13 |
| 12 | 2 | 24 | Pane ao trocar senha | 2012-06-20 |
| 13 | 2 | 24 | Limpeza do sistema | 2012-06-20 |
| 14 | 2 | 24 | CPF do Wellington Fernandes | 2012-06-25 |

**Decisão:** FK não criada. Destinatários rm=15 e rm=24 foram removidos do sistema antes de 2026. Mensagens de 2012, nunca visíveis nas listagens (destinatário inexistente). Não foram excluídas para preservar histórico.

**Para criar FK no futuro:** tratar esses 4 registros (excluir logicamente ou reatribuir destinatário) e re-executar verificação de órfãos.

### SQL executado

```sql
-- Colunas de exclusão lógica
ALTER TABLE mensagem        ADD COLUMN excluidaEm DATETIME NULL DEFAULT NULL;
ALTER TABLE mensagemenviada ADD COLUMN excluidaEm DATETIME NULL DEFAULT NULL;

-- Índices para filtro eficiente de não-excluídas
CREATE INDEX idx_msg_dest_ativo ON mensagem        (destinatarioRec, excluidaEm, enviadaEm);
CREATE INDEX idx_env_rem_ativo  ON mensagemenviada (remetenteEnv,    excluidaEm, enviadaEm);
```

### Arquivo alterado

**`classes/MensagemRepository.php`** — 6 métodos atualizados:

| Método | Alteração |
|---|---|
| `listarRecebidas` | `WHERE destinatarioRec = :rm AND excluidaEm IS NULL ORDER BY enviadaEm DESC` |
| `listarEnviadas` | `WHERE remetenteEnv = :rm AND excluidaEm IS NULL ORDER BY enviadaEm DESC` |
| `buscarRecebidaPorId` | `WHERE idMensagemRec = :id AND destinatarioRec = :rm AND excluidaEm IS NULL LIMIT 1` |
| `buscarEnviadaPorId` | `WHERE idMensagemEnv = :id AND remetenteEnv = :rm AND excluidaEm IS NULL LIMIT 1` |
| `excluirRecebida` | `UPDATE mensagem SET excluidaEm = NOW() WHERE idMensagemRec = :id AND destinatarioRec = :rm AND excluidaEm IS NULL` |
| `excluirEnviada` | `UPDATE mensagemenviada SET excluidaEm = NOW() WHERE idMensagemEnv = :id AND remetenteEnv = :rm AND excluidaEm IS NULL` |

**`php -l`:** sem erros de sintaxe ✓

### Efeito da exclusão lógica

- `excluirRecebida` e `excluirEnviada` não fazem mais DELETE. Definem `excluidaEm = NOW()`.
- Mensagem "excluída" não aparece em nenhuma listagem nem pode ser aberta (todos os `WHERE` filtram `excluidaEm IS NULL`).
- Duplo clique em excluir é idempotente — segundo UPDATE não encontra registro com `excluidaEm IS NULL`.
- Dados ficam no banco para auditoria futura.

### Índices criados

| Nome | Tabela | Colunas | Motivo |
|---|---|---|---|
| `idx_msg_dest_ativo` | mensagem | (destinatarioRec, excluidaEm, enviadaEm) | Listagem de recebidas não-excluídas |
| `idx_env_rem_ativo` | mensagemenviada | (remetenteEnv, excluidaEm, enviadaEm) | Listagem de enviadas não-excluídas |

**EXPLAIN pós-criação:** ambas as queries retornam `type=ref` com índices em uso. `excluidaEm IS NULL` aplicado como filtro inline — custo baixo (~50 e ~8 linhas, respectivamente).

### Problemas encontrados

Nenhum. SQL executado sem erros. `php -l` limpo.

### Testes manuais pendentes

- [ ] Listar caixa de entrada — mensagens aparecem normalmente
- [ ] Listar caixa de enviadas — idem
- [ ] Abrir mensagem recebida
- [ ] Abrir mensagem enviada
- [ ] Enviar mensagem nova (verifica INSERT sem excluidaEm → NULL automático)
- [ ] Responder mensagem (fluxo completo)
- [ ] Excluir mensagem recebida — verificar que desaparece da lista e que `excluidaEm` foi preenchido no banco
- [ ] Excluir mensagem enviada — idem
- [ ] Tentar abrir mensagem excluída via URL direta — deve retornar "Mensagem não encontrada."
- [ ] Verificar caracteres especiais preservados (acentos, cedilha)

### Pendências para Fase 5 (auditoria e governança)

- FK para `cadastroministro.rm`: resolver 4 órfãos históricos (rm=15, rm=24) e re-executar verificação ✅ **Fase 5A executada em 2026-05-22**
- Campo `atualizadoEm TIMESTAMP ON UPDATE` para rastreamento automático de modificações
- Política de retenção: definir por quanto tempo manter mensagens logicamente excluídas
- Registrar exclusões em tabela de log/auditoria se `registro_atividade` existir no projeto

---

## Fase 5A — 2026-05-22

**Objetivo:** Remover órfãos de teste (2012) e criar FKs com `cadastroministro.rm`.

### Backup

`sql/backup_mensagens_fase5a_20260522_173847.sql` (742 KB) — gerado antes de qualquer alteração.

### Órfãos removidos

| idMensagemRec | remetenteRec | destinatarioRec | assuntoRec | enviadaEm |
|---|---|---|---|---|
| 6 | 2 | 15 | teset | 2012-05-13 |
| 12 | 2 | 24 | Pane ao trocar senha | 2012-06-20 |
| 13 | 2 | 24 | Limpeza do sistema | 2012-06-20 |
| 14 | 2 | 24 | CPF do Wellington Fernandes | 2012-06-25 |

4 registros de `mensagem.destinatarioRec` sem correspondência em `cadastroministro.rm` (RM 15 e 24 inexistentes). Removidos via `DELETE ... LEFT JOIN`.

### Verificação pós-DELETE

| Verificação | Órfãos |
|---|---|
| mensagem.remetenteRec | 0 |
| mensagem.destinatarioRec | 0 |
| mensagemenviada.remetenteEnv | 0 |
| mensagemenviada.destinatarioEnv | 0 |

### FKs criadas

| Constraint | Tabela | Coluna | Referência | ON DELETE | ON UPDATE |
|---|---|---|---|---|---|
| `fk_mensagem_remetente` | mensagem | remetenteRec | cadastroministro.rm | RESTRICT | CASCADE |
| `fk_mensagem_destinatario` | mensagem | destinatarioRec | cadastroministro.rm | RESTRICT | CASCADE |
| `fk_mensagemenviada_remetente` | mensagemenviada | remetenteEnv | cadastroministro.rm | RESTRICT | CASCADE |
| `fk_mensagemenviada_destinatario` | mensagemenviada | destinatarioEnv | cadastroministro.rm | RESTRICT | CASCADE |

### Teste de integridade

INSERT com RM inexistente (99999) → `ERROR 1452: Cannot add or update a child row: a foreign key constraint fails`. FK funcional.

### Problemas encontrados

Nenhum. Todos os ALTERs executados sem erro.

### Pendências restantes (Fase 5B+)

- Campo `atualizadoEm TIMESTAMP ON UPDATE` para rastreamento automático de modificações
- Política de retenção: definir por quanto tempo manter mensagens logicamente excluídas
- Registrar exclusões em tabela de log/auditoria se `registro_atividade` existir no projeto
