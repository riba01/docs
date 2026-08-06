# Unificação das listagens de membros — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estender `iecp/membro/listarMembroFoto` para oferecer filtros por situação capazes de reproduzir as listagens de membros, ex-membros e ministros, sem remover as rotas existentes até que a paridade seja comprovada.

**Architecture:** A listagem atual permanecerá como o modo padrão e continuará usando exatamente o conjunto de status vigente. A nova capacidade será adicionada de forma compatível, expondo `idStatusMinistro` e o nome da situação para filtros; indicadores, PDFs e ações continuarão isolados por contexto. As páginas antigas permanecerão disponíveis como fallback durante a validação.

**Tech Stack:** PHP procedural, PDO/MySQL, Bootstrap 5, Bootstrap Icons, jQuery, JavaScript existente da listagem, ECharts e mPDF.

## Global Constraints

- Não alterar o resultado padrão atual de `listarMembroFoto` (`1,4,5,6,9,10,11,12,14`).
- Não alterar inicialmente as consultas de `indicadoresSecretaria.php`.
- Não remover nem redirecionar inicialmente `iecp/ministro/listarMinistro` ou `iecp/membro/listarExMembro`.
- Preservar os PDFs especializados: membros, ex-membros e ministros.
- Preservar ficha individual, transferências, auditoria e permissões existentes.
- Não tratar status `8`, `9` ou `14` por inferência; usar as regras de compatibilidade documentadas neste plano.

## Regras de compatibilidade

| Modo da nova listagem | Regra equivalente existente | Uso |
|---|---|---|
| Membros | `idStatusMinistro IN (1,4,5,6,9,10,11,12,14)` | Modo padrão atual de `listarMembroFoto` |
| Ex-membros | `idStatusMinistro IN (2,3,7,13,14)` | Reproduz `listarExMembro` |
| Ministros | `idCargo < 6 AND idStatusMinistro NOT IN (2,3,7,13)` | Reproduz `listarMinistro` |
| Todos | `idStatusMinistro BETWEEN 1 AND 14` | Consulta ampla, sem substituir os modos especializados |

Status cadastrados no sistema:

- `1` ativo
- `2` desligado
- `3` excluído
- `4` disciplinado
- `5` em licença
- `6` enfermo
- `7` falecido
- `8` em movimentação
- `9` transferido
- `10` período probatório
- `11` sob investigação
- `12` aguardando parecer
- `13` inativo
- `14` jubilado

## Mapa de arquivos

**Arquivos a modificar na primeira etapa:**

- `iecp/membro/dados/listarMembros.php` — ampliar os dados da listagem com situação, sem alterar o modo padrão.
- `iecp/membro/listarMembroFoto.php` — adicionar seletor de situação/contexto e preservar o filtro atual como default.
- `iecp/membro/js/listarMembros.js` — filtrar cartões, atualizar contadores e selecionar o PDF correto por contexto.
- `iecp/membro/css/listarMembroFoto.css` — estilizar o filtro e os badges de situação.

**Arquivos que devem permanecer inalterados inicialmente:**

- `iecp/ministro/listarMinistro.php`
- `iecp/ministro/dados/listarMinistro.php`
- `iecp/membro/listarExMembro.php`
- `iecp/membro/dados/listarExMembros.php`
- `iecp/membro/dados/indicadoresSecretaria.php`
- `iecp/membro/pdf/gerarListaMembros.php`
- `iecp/membro/pdf/gerarListaExMembros.php`
- `iecp/ministro/pdf/gerarListaMinistro.php`

### Task 1: Criar a fonte de dados compatível

**Files:**
- Modify: `iecp/membro/dados/listarMembros.php`

**Interfaces:**
- Consumes: `$idIecp`, `$conexao`, regras de status atuais e tabelas de cargo/congregação.
- Produces: registros com `rm`, nome, foto, cargo, função, congregação, `idStatusMinistro` e `status`.

- [ ] **Step 1: Adicionar `idStatusMinistro` e `status` ao SELECT**

  Incluir `statusministro` com JOIN pela chave `idStatusMembro`, sem trocar o conjunto de status padrão da consulta.

- [ ] **Step 2: Garantir que o conjunto padrão permaneça idêntico**

  Manter `IN (1,4,5,6,9,10,11,12,14)` no modo atual e comparar a quantidade de RMs antes/depois.

- [ ] **Step 3: Preparar a consulta ampla sem torná-la o padrão**

  Implementar uma seleção explícita de modo, validada por uma lista fixa de regras; nunca interpolar status recebido diretamente do usuário.

### Task 2: Adicionar filtros de situação na tela

**Files:**
- Modify: `iecp/membro/listarMembroFoto.php`
- Modify: `iecp/membro/css/listarMembroFoto.css`

**Interfaces:**
- Consumes: resultados com `idStatusMinistro` e `status`.
- Produces: filtro de modo/situação com default compatível e badge visual por registro.

- [ ] **Step 1: Adicionar filtro “Contexto da lista”**

  Opções mínimas: `Membros`, `Ex-membros`, `Ministros` e `Todos`; selecionar `Membros` por padrão.

- [ ] **Step 2: Adicionar filtro individual de situação**

  Exibir os 14 status cadastrados, com texto legível e valor inteiro validado.

- [ ] **Step 3: Exibir o status nos cartões**

  Mostrar o nome da situação com badge; não usar apenas cor para distinguir status.

- [ ] **Step 4: Preservar o painel da secretaria**

  O painel e seus KPIs devem continuar baseados nas consultas próprias de `indicadoresSecretaria.php`, independentemente do filtro visual selecionado.

### Task 3: Preservar ações e PDFs por contexto

**Files:**
- Modify: `iecp/membro/js/listarMembros.js`

**Interfaces:**
- Consumes: modo selecionado, status dos cartões e IDs ocultos do operador/IECP.
- Produces: ficha individual preservada e PDF especializado conforme o modo.

- [ ] **Step 1: Manter a ficha individual para qualquer status**

  Continuar enviando `rm` para `iecp/ministro/ficha-Ministro/fichaMinistro`.

- [ ] **Step 2: Mapear PDFs sem alterar os geradores**

  - `Membros` → `iecp/membro/pdf/gerarListaMembros`
  - `Ex-membros` → `iecp/membro/pdf/gerarListaExMembros`
  - `Ministros` → `iecp/ministro/pdf/gerarListaMinistro`
  - `Todos` → desabilitar inicialmente ou criar um PDF específico posteriormente

- [ ] **Step 3: Preservar auditoria**

  Registrar a finalidade real do modo selecionado e não reutilizar a descrição “lista de obreiros” para todos os contextos.

### Task 4: Paridade com as páginas legadas

**Files:**
- Test: `iecp/membro/listarMembroFoto.php`
- Test: `iecp/ministro/listarMinistro.php`
- Test: `iecp/membro/listarExMembro.php`
- Test: PDFs correspondentes

- [ ] **Step 1: Comparar conjuntos de RMs**

  Para uma IECP de teste, comparar os RMs do modo `Membros` com `listarMembroFoto`, do modo `Ex-membros` com `listarExMembro` e do modo `Ministros` com `listarMinistro`.

- [ ] **Step 2: Verificar duplicidade**

  Garantir que cada RM apareça uma única vez por modo, mesmo com múltiplas funções históricas.

- [ ] **Step 3: Comparar totais por cargo e situação**

  Validar total geral, cargos, status e congregações; investigar qualquer diferença antes de alterar o menu.

- [ ] **Step 4: Testar ações manuais**

  Validar ficha, PDFs, filtros, paginação visual, painel, status `8`, `9` e `14`, além de larguras de 375px, 768px e desktop.

### Task 5: Compatibilidade de rotas e descontinuação gradual

**Files:**
- Modify only after Task 4 passes: `menus/menu_iecp.php`
- Modify only after Task 4 passes: `menus/menu_iecp copy.php`, se ainda for usado
- Modify only after Task 4 passes: `menus/backup/menu_iecp.php`, se ainda for usado

- [ ] **Step 1: Manter as rotas legadas durante o piloto**

  Não remover links nem arquivos enquanto a nova tela estiver em validação.

- [ ] **Step 2: Alterar o menu para atalhos filtrados**

  Depois da paridade, apontar “Listar Ministros” e “Listar Ex-Membros” para a nova tela com contexto explícito, mantendo as URLs antigas funcionando.

- [ ] **Step 3: Adicionar redirecionamentos compatíveis**

  Redirecionar somente após confirmar que links externos continuam abrindo o contexto correto.

- [ ] **Step 4: Remover páginas somente com evidência**

  A remoção só poderá ocorrer depois de confirmar ausência de referências externas, integrações e operações específicas.

## Rollback

- Reverter o menu para as rotas originais.
- Desativar o filtro unificado mantendo o modo `Membros` atual.
- Restaurar os arquivos legados somente se a validação mostrar perda de registros ou ações.
- Não excluir dados, PDFs ou rotas durante a primeira entrega.

## Critérios de aceite

- O modo padrão retorna exatamente os mesmos RMs de `listarMembroFoto`.
- O modo `Ex-membros` retorna exatamente os mesmos RMs de `listarExMembro`.
- O modo `Ministros` respeita cargo e status da listagem legada.
- Os três PDFs continuam gerando o conjunto correto.
- O painel da secretaria mantém os mesmos indicadores.
- Ficha individual, transferência e auditoria continuam funcionando.
- Nenhuma rota legada é removida antes da validação de paridade.
