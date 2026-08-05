# CONIECP Member Credential Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt the CONIECP member credential screen to the IECP member credential experience while preserving CONIECP's multi-IECP and endpoint behavior.

**Architecture:** Keep the existing PHP page as the server-rendered shell and update its markup to the reference screen's accessible filter/results structure. Update only the page JavaScript and stylesheet; all AJAX, delivery-registration, and PDF endpoints remain under `coniecp/credencial/`.

**Tech Stack:** PHP 8-compatible server-rendered HTML, jQuery/jQuery UI, Bootstrap Icons, existing project CSS.

## Global Constraints

- Preserve `validar_usuario_coniecp.php` and the CONIECP session context.
- Preserve the `todas` IECP option and all existing CONIECP endpoint paths.
- Keep all ten cargo IDs (`1` through `10`) available to the filter.
- Keep output escaped when rendering IECP names and values.
- Provide visible focus states, accessible labels/statuses, responsive layout, and reduced-motion support.

### Task 1: Add a structural regression test

**Files:**
- Create: `tests/credencial/gerarCredencialMembro_test.php`

- [ ] **Step 1: Write the failing test**

Create a CLI test that reads the three CONIECP screen files and exits non-zero unless the page has the search field and ten cargo values, the JS has only CONIECP runtime routes plus accent-insensitive member filtering, and the CSS has responsive focus/reduced-motion rules.

- [ ] **Step 2: Run the test to verify it fails**

Run: `php tests/credencial/gerarCredencialMembro_test.php`
Expected: FAIL because the current page exposes only five cargo controls and has no search field/filter implementation.

### Task 2: Port the reference screen structure with CONIECP differences

**Files:**
- Modify: `coniecp/credencial/gerarCredencialMembro.php`

- [ ] **Step 1: Replace the legacy screen markup**

Keep the session validation, escaped IECP query, menu, header/footer, and hidden `cadastradoPor`. Replace the body controls with the reference's status stack, filter card, three status radio cards, ten cargo checkboxes, PDF action, result heading, and name-search field. Keep `0` and `todas` options and escape each database value.

- [ ] **Step 2: Run the PHP syntax check**

Run: `php -l coniecp/credencial/gerarCredencialMembro.php`
Expected: `No syntax errors detected`.

### Task 3: Port interactions and retain CONIECP routes

**Files:**
- Modify: `coniecp/credencial/js/gerarCredencialMembro.js`

- [ ] **Step 1: Implement reference interactions**

Keep the CONIECP list, delivery, and PDF paths. Add robust datepicker setup after AJAX rendering, accent-insensitive local member search/count, loading/error feedback, select-all behavior, validation, and event handlers for all filter controls.

- [ ] **Step 2: Run the structural test**

Run: `php tests/credencial/gerarCredencialMembro_test.php`
Expected: FAIL only if a required route, search behavior, or accessibility contract is still missing.

### Task 4: Align the visual system and responsive behavior

**Files:**
- Modify: `coniecp/credencial/css/gerarCredencialMembro.css`

- [ ] **Step 1: Apply the reference visual language**

Style the new `gcm-*` structure with the existing purple/gold accessible palette, stable hover/focus states, responsive filter/result layout, visible status banners, and reduced-motion rules. Ensure member cards and date controls fit at mobile widths.

- [ ] **Step 2: Run all verification checks**

Run: `php tests/credencial/gerarCredencialMembro_test.php`, `php -l coniecp/credencial/gerarCredencialMembro.php`, and `npx eslint coniecp/credencial/js/gerarCredencialMembro.js`.
Expected: all applicable checks pass; if ESLint rejects legacy globals/configuration, report the exact existing configuration issue separately.
