# Listagem de usuários — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atualizar a listagem de usuários do SWGA com o padrão visual institucional existente, mantendo a lógica funcional atual.

**Architecture:** A página PHP continuará responsável por consultar e renderizar os dados. O markup receberá uma estrutura namespaceada `lu-*`, o CSS isolará o novo visual e o JavaScript continuará delegando busca, ordenação, paginação e ações ao DataTables/jQuery existentes.

**Tech Stack:** PHP procedural, Bootstrap 5, Bootstrap Icons, jQuery, DataTables 2.x, CSS responsivo.

## Global Constraints

- Preservar a consulta SQL, as colunas e os endpoints de edição/exclusão.
- Não adicionar dependências novas.
- Usar ícones Bootstrap já carregados pelo `header.php`; não usar emojis como ícones.
- Manter contraste acessível, foco visível e tabela utilizável em telas estreitas.

### Task 1: Estrutura visual da página

**Files:**
- Modify: `iecp/usuario/listarUsuario.php`

**Interfaces:**
- Consumes: `$result`, `$idIecp` e variáveis de sessão já disponíveis.
- Produces: markup `lu-wrapper`, `lu-main`, `lu-page-header`, `lu-summary`, `lu-table-card` e `#lu-search` para o CSS e o JavaScript.

- [ ] **Step 1: Criar os dados derivados dos cards-resumo**

  Antes do markup, contar em PHP os registros liberados, bloqueados e sem `dataVisita`, mantendo `$result` intacto para a tabela.

- [ ] **Step 2: Reorganizar o markup sem alterar os valores funcionais**

  Adicionar cabeçalho, cards-resumo, toolbar com campo `#lu-search`, cartão da tabela e estados visuais. Manter os valores `rm` nos botões `.edit` e `.del`.

- [ ] **Step 3: Aplicar escape de saída nos textos dinâmicos**

  Usar `htmlspecialchars(..., ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` nos nomes, e-mails e IECP exibidos no novo markup.

### Task 2: Estilo responsivo da listagem

**Files:**
- Modify: `iecp/usuario/css/listarUsuario.css`

**Interfaces:**
- Consumes: classes `lu-*` emitidas pela página.
- Produces: visual institucional, estados de foco/hover, badges de acesso, ações e breakpoints responsivos.

- [ ] **Step 1: Substituir o CSS legado por regras namespaceadas `lu-*`**

  Definir variáveis locais, fundo, cabeçalho, cards, toolbar, tabela e controles DataTables sem estilos globais que contaminem outras páginas.

- [ ] **Step 2: Estilizar busca e paginação do DataTables**

  Alinhar `.dt-container`, `.dt-search`, `.dt-input`, `.dt-length`, `.dt-info` e `.dt-paging` ao padrão visual com foco visível e transições de 150–300ms.

- [ ] **Step 3: Adicionar breakpoint móvel e movimento reduzido**

  Usar rolagem horizontal somente dentro do cartão da tabela, reduzir padding em telas estreitas e respeitar `prefers-reduced-motion`.

### Task 3: Comportamento e integração DataTables

**Files:**
- Modify: `iecp/usuario/js/listarUsuario.js`
- Modify: `iecp/usuario/listarUsuario.php`

**Interfaces:**
- Consumes: `#listarUsuario`, `#lu-search`, `.edit` e `.del`.
- Produces: busca customizada, inicialização única do DataTables, mensagens em português e ações de edição/exclusão preservadas.

- [ ] **Step 1: Remover a inicialização duplicada e centralizar o comportamento**

  Manter uma única inicialização DataTables e usar `#lu-search` como campo de busca externo, sem quebrar ordenação, paginação ou tradução pt-BR.

- [ ] **Step 2: Preservar as ações existentes com feedback de interação**

  Manter confirmação antes do POST de exclusão e envio do formulário de edição, adicionando apenas estados de foco e `aria-label`.

- [ ] **Step 3: Validar a tabela quando não houver registros**

  Garantir que o DataTables mostre uma mensagem legível no estado vazio e que os cards-resumo exibam zero sem warnings PHP.

### Task 4: Verificação

**Files:**
- Test: `iecp/usuario/listarUsuario.php`
- Test: `iecp/usuario/css/listarUsuario.css`
- Test: `iecp/usuario/js/listarUsuario.js`

- [ ] **Step 1: Executar lint PHP**

  Run: `rtk php -l iecp/usuario/listarUsuario.php`

  Expected: `No syntax errors detected`.

- [ ] **Step 2: Revisar diff e referências de classes**

  Run: `rtk git diff --check` e `rtk git diff -- iecp/usuario/listarUsuario.php iecp/usuario/css/listarUsuario.css iecp/usuario/js/listarUsuario.js`.

  Expected: nenhum whitespace error e somente mudanças da tela de usuários, além dos documentos de design/plano.

- [ ] **Step 3: Confirmar assets e seletores principais**

  Run: `rtk rg -n "lu-(wrapper|page-header|summary|toolbar|table-card)|#lu-search|#listarUsuario" iecp/usuario/listarUsuario.php iecp/usuario/css/listarUsuario.css iecp/usuario/js/listarUsuario.js`.

  Expected: todos os pontos de integração aparecem nos arquivos correspondentes.
