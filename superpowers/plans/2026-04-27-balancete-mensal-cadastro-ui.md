# Balancete Mensal Cadastro UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reestruturar a tela de cadastro de balancete mensal para ficar visualmente consistente com a listagem moderna, sem alterar IDs, endpoints, permissões ou regras financeiras.

**Architecture:** A página PHP vai trocar a tabela antiga por um card responsivo com cabeçalho, instruções e formulário em blocos. O JavaScript continuará chamando `carregaMes` e `incluirBalancete`, mas vai adicionar estados de loading, disabled e feedback visual. O CSS será incremental, com classes específicas do cadastro para evitar impacto em outras telas.

**Tech Stack:** PHP procedural, jQuery, CSS incremental no módulo `iecp/tesouraria/balanceteMensal`, Bootstrap grid já existente no layout geral.

---

### Task 1: Reestruturar a view do cadastro

**Files:**
- Modify: `iecp/tesouraria/balanceteMensal/cadastrarBalanceteMensal.php`

- [ ] **Step 1: Preserve the existing session/auth/bootstrap includes and the hidden `idIecp` contract**

```php
include_once('valida_sessao_all.php');
include_once('validar_usuario_iecp.php');
include_once('header.php');
```

- [ ] **Step 2: Replace the table layout with a responsive card that keeps `#ano`, `#mes`, `#salvar`, and `#idIecp` intact**

```php
<div id="bal-cadastro" class="bal-cadastro-shell">
  <div class="bal-cadastro-card">
    <div class="filtro-header bal-cadastro-header">
      <span class="filtro-icon">
        <span class="material-symbols-outlined">account_balance</span>
      </span>
      <div>
        <h6 class="filtro-titulo">Cadastrar Balancete Mensal</h6>
        <span class="filtro-subtitulo">Selecione o ano e o mês disponível para iniciar um novo balancete.</span>
      </div>
    </div>
    ...
  </div>
</div>
```

- [ ] **Step 3: Add feedback, helper text, and a button bar that is readable on mobile**

```php
<div id="cadBalanceteFeedback" class="bal-cadastro-feedback" role="status" aria-live="polite"></div>
<div class="bal-cadastro-actions">
  <button id="salvar" type="button" class="bal-cadastro-button">
    <span class="material-symbols-outlined" aria-hidden="true">check_circle</span>
    <span class="bal-cadastro-button__label">Salvar balancete</span>
  </button>
</div>
```

### Task 2: Improve the interactive flow

**Files:**
- Modify: `iecp/tesouraria/balanceteMensal/js/cadastrarBalanceteMensal.js`

- [ ] **Step 1: Keep the same endpoints and field IDs while adding loading and disabled states**

```javascript
$.post('painel.php?pagina=iecp/tesouraria/balanceteMensal/carregaMes', { ano, idIecp }, function (dados) {
  $("#mes").prop("disabled", false).html(dados);
});
```

- [ ] **Step 2: Add inline validation, button locking, and friendly feedback for success and error states**

```javascript
setFeedback('success', 'Balancete cadastrado com sucesso.');
setSavingState(true);
$.post('painel.php?pagina=iecp/tesouraria/balanceteMensal/incluirBalancete', { ano, mes, idIecp, statusBalancete })
  .done(function (dados) { ... });
```

- [ ] **Step 3: Reset the month select safely after a successful insert without changing backend contracts**

```javascript
resetMes(true);
$("#ano").val("0").trigger("change");
```

### Task 3: Add isolated CSS for the cadastro card

**Files:**
- Modify: `iecp/tesouraria/balanceteMensal/css/styles.css`

- [ ] **Step 1: Add only cadastro-specific selectors and responsive breakpoints**

```css
.bal-cadastro-shell { ... }
.bal-cadastro-card { ... }
.bal-cadastro-grid { ... }
```

- [ ] **Step 2: Style validation, loading, and action states without touching shared module rules**

```css
.bal-cadastro-feedback--error { ... }
.bal-cadastro-feedback--success { ... }
.bal-cadastro-button.is-loading { ... }
```

### Task 4: Verify the flow locally

**Files:**
- No code changes expected

- [ ] **Step 1: Run syntax checks on the touched PHP file**

```powershell
php -l iecp\tesouraria\balanceteMensal\cadastrarBalanceteMensal.php
```

- [ ] **Step 2: Inspect the updated page in desktop and mobile widths**

```powershell
php -S 127.0.0.1:3015 -t .
```

- [ ] **Step 3: Confirm that `carregaMes` and `incluirBalancete` still receive the same payload**

```javascript
{ ano, mes, idIecp, statusBalancete }
```
