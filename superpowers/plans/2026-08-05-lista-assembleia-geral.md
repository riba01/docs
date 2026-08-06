# Lista de Presença da Assembleia Geral Implementation Plan

> **For agentic workers:** Execute this plan task-by-task with verification after each task.

**Goal:** Modernize the IECP assembly attendance list while enforcing session authorization, CSRF protection, strict input validation, safe PDF rendering, accessibility, and responsive behavior.

**Architecture:** Keep the existing PHP/Bootstrap route and server-rendered member list. Extract pure request-normalization and presentation helpers into a small namespaced class so security rules can be tested without starting a session or generating a PDF. The browser submits a real form with `lista[]`; the PDF endpoint derives the church exclusively from the authenticated session and intersects submitted RMs with eligible records from that church.

**Tech Stack:** PHP 8.x, PDO, Composer autoload, PHPUnit when available, Bootstrap 5, existing jQuery only where already loaded, mPDF.

## Global Constraints

- Do not accept `idIecp` from the browser; use `$_SESSION['idIecp']` after authentication and authorization.
- Validate `csrf_token`, assembly type, ISO date, and selected RMs on the server even when the browser already validates them.
- Escape all database values before inserting them into page HTML or mPDF HTML.
- Preserve the current eligible-status filter, present/absent PDF behavior, route, and signature rows.
- Do not modify tables, dependencies, menus, unrelated documentation changes, or the existing untracked documentation plan.
- Keep local CSS compatible with the project’s existing `.scss` link behavior and honor `prefers-reduced-motion`.

---

### Task 1: Add testable assembly input rules

**Files:**
- Create: `classes/ListaAssembleiaGeral.php`
- Create: `tests/ListaAssembleiaGeralTest.php`

**Interfaces:**
- `Classes\ListaAssembleiaGeral::normalizeType(mixed $value): ?string` returns only `Ordinaria` or `Extraordinaria`.
- `Classes\ListaAssembleiaGeral::parseDate(mixed $value, ?DateTimeImmutable $today = null): ?DateTimeImmutable` accepts `Y-m-d` dates through today plus 15 days and rejects malformed dates.
- `Classes\ListaAssembleiaGeral::normalizeRms(mixed $value): array` returns unique positive integer RMs from an array and rejects scalar/comma-joined input.
- `Classes\ListaAssembleiaGeral::escapePdfText(mixed $value): string` returns safe UTF-8 HTML text for mPDF.

- [ ] **Step 1: Write failing PHPUnit cases** for valid/invalid types, strict dates including impossible dates and the +15-day boundary, duplicate/non-integer RMs, scalar legacy input, and HTML escaping.
- [ ] **Step 2: Run the focused test** with `vendor/bin/phpunit tests/ListaAssembleiaGeralTest.php`; expect failures because the class does not exist yet. If PHP/PHPUnit is unavailable, record the environment limitation and run the equivalent assertions with a temporary non-committed PHP command after implementation.
- [ ] **Step 3: Implement the minimal final class** with strict types, no database/session side effects, `DateTimeImmutable::createFromFormat('!Y-m-d', ...)`, `DateTimeImmutable::getLastErrors()` handling, and `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')`.
- [ ] **Step 4: Re-run the focused test** and require all assertions to pass.

### Task 2: Rebuild the server-rendered page

**Files:**
- Modify: `iecp/listaChamada/listaAssembleiaGeral.php`

**Interfaces:**
- Produces a form with `id="listaAssembleiaForm"`, `lista[]` checkboxes, `csrf_token`, `tipo`, and `data`.
- Provides `data-max-date` from the São Paulo server timezone and no hidden `idIecp` field.

- [ ] **Step 1: Write a prepared query** that selects only the existing eligible ministers for the authenticated `$idIecp`, binding it as `PDO::PARAM_INT` and selecting only `rm`, `nome`, `cargo`, and ordering fields needed by the view.
- [ ] **Step 2: Replace the fixed fieldset layout** with a semantic `main`, header, responsive card, configuration grid, table wrapper, selection summary, and action area.
- [ ] **Step 3: Escape `$iecp_nomeReduzido`, names, cargos, RMs, and generated IDs** with `htmlspecialchars`; associate every checkbox with a visible label and add an explicit empty state.
- [ ] **Step 4: Render the CSRF field** with `Classes\Csrf::htmlField()` and submit to the existing `painel.php?pagina=iecp/listaChamada/pdf/gerarPdfListaPresentesAssembleia` route in a new tab.
- [ ] **Step 5: Run `php -l iecp/listaChamada/listaAssembleiaGeral.php`** and inspect the rendered markup for missing labels, unescaped values, and accidental `idIecp` output.

### Task 3: Implement accessible browser behavior

**Files:**
- Modify: `iecp/listaChamada/js/lista.js`

- [ ] **Step 1: Replace the jQuery UI dialog flow** with a small form controller that writes field errors and status into existing `aria-live` regions and focuses the first invalid control.
- [ ] **Step 2: Implement select-all behavior** using `.checked` and `.indeterminate`, update the selected count on every checkbox change, and keep the master control synchronized.
- [ ] **Step 3: Validate selected members, allowed type, non-empty date, and the server-provided maximum date** on submit; prevent submission when invalid.
- [ ] **Step 4: On valid submit, disable the button, set `aria-busy`, announce “Gerando PDF…” and allow the native form target to open the PDF without string-building hidden HTML.
- [ ] **Step 5: Run `npx eslint iecp/listaChamada/js/lista.js`** and fix only errors attributable to this file.

### Task 4: Apply responsive and accessible visual styles

**Files:**
- Modify: `iecp/listaChamada/css/lista.scss`

- [ ] **Step 1: Add scoped page tokens** for `#F8FAFC`, `#1E293B`, `#2563EB`, and `#F97316`, with a system font fallback and visible borders.
- [ ] **Step 2: Style the card, form controls, buttons, focus-visible states, table wrapper, checkbox rows, empty state, errors, and status without inline styles or layout-shifting hover transforms.
- [ ] **Step 3: Add breakpoints for 375/768/1024px behavior, contain table overflow, and keep touch targets at least 44px where practical.
- [ ] **Step 4: Add a reduced-motion media query and verify no local rule removes focus outlines without a replacement.

### Task 5: Harden the PDF endpoint and preserve output

**Files:**
- Modify: `iecp/listaChamada/pdf/gerarPdfListaPresentesAssembleia.php`

- [ ] **Step 1: Resolve the project root from `__DIR__`** and require `valida_sessao_all.php` plus `validar_usuario_iecp.php` before processing POST data, so direct endpoint access receives the same authorization checks.
- [ ] **Step 2: Reject non-POST requests and invalid CSRF tokens** using `Classes\Csrf::validateToken()` with HTTP 403 and a generic error page.
- [ ] **Step 3: Read the church ID only from the validated session**, normalize the posted fields through `ListaAssembleiaGeral`, and return HTTP 400 for invalid input without exposing internals.
- [ ] **Step 4: Query IECP and eligible ministers with prepared statements**, intersect submitted RMs with the query result, and ensure no record from another church can enter either present or absent output.
- [ ] **Step 5: Escape formatted names, cargos, type labels, and dates before concatenating mPDF HTML; preserve present/faltoso pages, headers, footers, and signature lines.
- [ ] **Step 6: Load the stylesheet using an absolute `__DIR__`-derived path and use a safe date-only filename.
- [ ] **Step 7: Run `php -l iecp/listaChamada/pdf/gerarPdfListaPresentesAssembleia.php` and the focused PHPUnit suite.

### Task 6: Verify the complete change

**Files:**
- Modify: none unless verification exposes a scoped defect.

- [ ] **Step 1: Run `php -l` for every modified PHP file** and `npx eslint iecp/listaChamada/js/lista.js`.
- [ ] **Step 2: Run `git diff --check` and review `git diff --stat`; confirm the unrelated docs change and `docs/superpowers/plans/2026-08-05-unificacao-listagens-membros.md` remain untouched.
- [ ] **Step 3: Exercise the page manually in WAMP at 375, 768, 1024, and 1440px:** empty selection, select-all, partial selection, invalid type/date, valid PDF generation, and keyboard-only flow.
- [ ] **Step 4: Exercise endpoint tampering cases:** omit CSRF, post another `idIecp`, submit a foreign/unknown RM, use comma-joined `lista`, malformed date, and HTML in a fixture name; verify rejection or safe text output.
- [ ] **Step 5: Capture the exact commands and results in the final handoff, then use the finishing-development-branch workflow before claiming completion.
