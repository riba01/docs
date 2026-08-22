# Portaria Document List Visual Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `coniecp/portaria/listarPortaria` into the reference document-list screen with a clear header, status control, summarized results, accessible states, responsive table/cards and preserved navigation.

**Architecture:** Keep the existing server-rendered HTML fragment endpoint and POST contract. The page shell owns the editorial layout and controls; `listarPortariaAcao.php` renders the result state and sanitized summaries; the page-specific CSS switches the result table to stacked cards below the mobile breakpoint; the existing jQuery handler remains responsible for fetching fragments and binding the consultation action.

**Tech Stack:** PHP 8+, PDO, Bootstrap already loaded by `header.php`, jQuery, existing local image icons, CSS media queries.

## Global Constraints

- Preserve session checks, access levels, POST endpoint, status values, pagination and consultation navigation.
- Do not expose the full document content in the list; show a sanitized summary limited to two visual lines.
- Use existing `Readex Pro` and `Source Sans 3` fonts and the portaria palette: `#f1f5f9`, `#ffffff`, `#0f172a`, `#475569`, `#173b8f`, `#cbd5e1`.
- No textual search in this iteration because the endpoint does not support server-side term filtering.
- Keep changes limited to the portaria list page, its action fragment, JavaScript and list-specific CSS.

---

### Task 1: Build the page shell and initial state

**Files:**
- Modify: `coniecp/portaria/listarPortaria.php`
- Create: `coniecp/portaria/css/listarPortaria.css`

**Interfaces:**
- Consumes: the existing `header.php`, `menu.php`, `listarPortaria.js` and `listarPortariaAcao.php` paths.
- Produces: `#listarPortaria` page shell with `statusPortaria`, `#resposta`, `#listaPortariaResumo`, `#listaPortariaEstado` and `#listaPortariaAtualizar` hooks.

- [ ] **Step 1: Replace the legacy fieldset-like markup with the document-list shell.**

  Add the breadcrumb, title, description, `Nova portaria` link, labeled status select, result counter, results card, live region and a neutral initial instruction. Keep `#editar` for compatibility with existing page behavior.

- [ ] **Step 2: Add the list-specific stylesheet link after the shared portaria layout link.**

  The page must load `coniecp/portaria/css/listarPortaria.css` and keep the shared `portaria-layout.css` available for typography and focus language.

- [ ] **Step 3: Create the base responsive styles.**

  Define scoped `.lista-portaria-*` rules for the page background, header, control card, results card, button, initial state and responsive spacing. Set the mobile result container to use cards while leaving the semantic table available in the markup.

- [ ] **Step 4: Verify the shell has no duplicate IDs and labels the select.**

  Run: `rtk rg -n "id=\"(statusPortaria|resposta|editar|listarPortaria)\"|for=\"statusPortaria\"" coniecp/portaria/listarPortaria.php`

  Expected: each required ID appears once and the status label points to `statusPortaria`.

### Task 2: Render summarized, accessible results

**Files:**
- Modify: `coniecp/portaria/listarPortariaAcao.php`
- Modify: `coniecp/portaria/css/listarPortaria.css`

**Interfaces:**
- Consumes: `$_POST['statusPortaria']`, `$_POST['pag']`, `Portaria::listar()`, `PortariaInputValidator` and the existing status icon paths.
- Produces: a result card containing `table.lista-portaria-table`, `.lista-portaria-status`, `.lista-portaria-summary`, `.btnPag` and `.verPortaria` controls.

- [ ] **Step 1: Add a small server-side summary helper beside `eListaPortaria()`.**

  Strip tags from the sanitized display text, collapse whitespace, decode HTML entities for the visible excerpt, and truncate to a readable limit without returning raw HTML. Keep the full sanitized HTML out of the list response.

- [ ] **Step 2: Make the count query reflect the selected status.**

  For `Todas`, count all rows. For another allowed status, bind `:statusPortaria` in `SELECT COUNT(*) FROM portaria WHERE statusPortaria = :statusPortaria`. Use the count to calculate the number of pages and expose the range in a small footer label.

- [ ] **Step 3: Replace the current wide table cells with semantic columns.**

  Use a `<caption class="sr-only">`, `scope="col"`, clear headings, a `<time datetime>` value for dates, a two-line summary wrapper, a status badge with text and existing icon, and a text-plus-icon `Visualizar` button with `aria-label="Visualizar Portaria N"`.

- [ ] **Step 4: Replace the inline empty output with a structured empty state.**

  Return a neutral result card containing an icon, a heading and a contextual message that names the selected status. Keep the response HTML safe through `eListaPortaria()`.

- [ ] **Step 5: Style table rows, status variants, summary clamp and pagination.**

  Add hover/focus feedback without layout shift, visible status variants for active/elaboration/archived/cancelled and touch-sized pagination controls. At the mobile breakpoint, hide the table header and expose each cell through `data-label` pseudo-labels.

- [ ] **Step 6: Run PHP syntax validation for the fragment.**

  Run: `php -l coniecp/portaria/listarPortariaAcao.php`

  Expected: `No syntax errors detected`.

### Task 3: Connect loading, error and consultation interactions

**Files:**
- Modify: `coniecp/portaria/js/listarPortaria.js`
- Modify: `coniecp/portaria/css/listarPortaria.css`

**Interfaces:**
- Consumes: `#statusPortaria`, `#resposta`, `#listaPortariaEstado`, `.btnPag` and `.verPortaria` emitted by the page/fragment.
- Produces: `POST coniecp/portaria/listarPortariaAcao.php` with `{statusPortaria, pag}` and navigation to `painel.php?pagina=coniecp/portaria/consultarPortaria` with `idPortaria`.

- [ ] **Step 1: Add one reusable `carregarPortarias(pagina)` function.**

  Set `aria-busy="true"`, show a loading message in `aria-live`, disable the select and pagination while the request is active, post the selected status and page, then restore controls in `.always()`.

- [ ] **Step 2: Handle request errors visibly.**

  Render a structured error message with a retry button that calls `carregarPortarias(1)`; do not leave a spinner or blank area after a failed request.

- [ ] **Step 3: Bind pagination and consultation buttons after every fragment replacement.**

  Use delegated events on `#resposta` so newly rendered controls work without duplicate handlers. Preserve the current form-post navigation behavior for consultation.

- [ ] **Step 4: Load the initial neutral state without an invalid request.**

  The page should wait for an intentional status choice; if the user picks `0`, restore the instructional state rather than posting an invalid status.

- [ ] **Step 5: Validate JavaScript syntax.**

  Run: `node --check coniecp/portaria/js/listarPortaria.js`

  Expected: process exits successfully with no syntax output.

### Task 4: Verify the complete visual and functional flow

**Files:**
- Verify: `coniecp/portaria/listarPortaria.php`
- Verify: `coniecp/portaria/listarPortariaAcao.php`
- Verify: `coniecp/portaria/js/listarPortaria.js`
- Verify: `coniecp/portaria/css/listarPortaria.css`

**Interfaces:**
- Consumes: the local WAMP-served application and an authorized session with portaria access.
- Produces: evidence that the reference list works at desktop and mobile widths.

- [ ] **Step 1: Run PHP validation for both changed PHP files.**

  Run: `php -l coniecp/portaria/listarPortaria.php && php -l coniecp/portaria/listarPortariaAcao.php`

  Expected: both files report no syntax errors.

- [ ] **Step 2: Exercise the status flow manually.**

  In WAMP, open `painel.php?pagina=coniecp/portaria/listarPortaria`, choose `Ativo`, `Em Elaboração`, `Arquivado`, `Cancelada` and `Todas`, verify loading/result/empty states, move between pages and open `Visualizar`.

- [ ] **Step 3: Check responsive layouts at 375px, 768px, 1024px and 1440px.**

  Confirm no horizontal overflow, mobile cards expose all fields, desktop keeps aligned columns and actions stay reachable.

- [ ] **Step 4: Check keyboard and reduced-motion behavior.**

  Tab through the select, CTA, pagination and row actions; verify focus rings and that `prefers-reduced-motion: reduce` removes transitions.

- [ ] **Step 5: Inspect the final diff and leave unrelated work untouched.**

  Run: `rtk git diff --check -- coniecp/portaria/listarPortaria.php coniecp/portaria/listarPortariaAcao.php coniecp/portaria/js/listarPortaria.js coniecp/portaria/css/listarPortaria.css`

  Expected: no whitespace errors and no changes outside the scoped files plus the design documentation.
