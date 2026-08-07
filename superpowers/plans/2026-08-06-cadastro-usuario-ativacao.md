# Cadastro de Usuário com Link de Ativação Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize `iecp/usuario/cadastrarUsuario` and replace plaintext password delivery with a scoped, CSRF-protected, single-use activation/reset link compatible with PHP 8.5+.

**Architecture:** Keep the existing PHP/Bootstrap page shell and `password_reset_tokens` table. The new IECP-only endpoint creates a hashed, expiring token and sends a reset URL; `redefinir-senha.php` atomically creates the first `login` row or updates an existing one after the recipient chooses a password. The page uses a new `cu-*` visual layer that reuses `listarUsuario` tokens without coupling its markup to the listing table.

**Tech Stack:** PHP 8.5+, PDO/MySQL, Composer PSR-4 classes, PHPMailer 7, Bootstrap 5, existing jQuery, PHPUnit 13 when available, plain CSS/JavaScript.

## Global Constraints

- Do not send, render, or store a generated plaintext password for the activation flow.
- Derive `idIecp`, target e-mail, eligibility, and authorization from the authenticated server session/database; never trust those values from the browser.
- Validate POST, CSRF, RM, token format, expiry, and one-time use on the server.
- Hash activation tokens with SHA-256 before persistence and generate raw tokens with `random_bytes(32)`.
- Hash the chosen password with `password_hash(..., PASSWORD_ARGON2ID)`.
- Do not expose PDO exceptions, filesystem paths, SMTP credentials, raw tokens, or SQL in HTTP responses.
- Keep SMTP credentials in ignored `config/smtp.php` using the shape documented by `config/smtp.example.php`.
- Every changed SCSS file must have its corresponding CSS updated in the same change; runtime pages must load `.css`, never `.scss`.
- Preserve unrelated working-tree changes and do not modify database schemas in this plan.
- Use `php -l` for every changed PHP file, focused PHPUnit tests when PHP is available, ESLint for changed JavaScript, and `git diff --check` before completion.

---

### Task 1: Add pure activation-token rules and regression tests

**Files:**
- Create: `classes/PasswordResetToken.php`
- Create: `tests/PasswordResetTokenTest.php`

**Interfaces:**
- `Classes\PasswordResetToken::generate(): string` returns exactly 64 lowercase hexadecimal characters.
- `Classes\PasswordResetToken::hash(string $rawToken): string` returns the SHA-256 hex digest.
- `Classes\PasswordResetToken::isValidFormat(mixed $rawToken): bool` accepts only a 64-character hexadecimal string.
- `Classes\PasswordResetToken::expiresAt(?DateTimeImmutable $now = null, int $ttlSeconds = 2700): DateTimeImmutable` returns a UTC-safe application timestamp exactly `ttlSeconds` in the future.

- [ ] **Step 1: Write the failing tests** for token length/hex format, deterministic hashing, malformed token rejection, and the 45-minute expiry boundary.

  ```php
  public function test_generate_returns_a_64_character_hex_token(): void
  {
      $token = PasswordResetToken::generate();

      self::assertSame(64, strlen($token));
      self::assertMatchesRegularExpression('/\A[0-9a-f]{64}\z/', $token);
  }

  public function test_hash_is_deterministic(): void
  {
      self::assertSame(
          hash('sha256', str_repeat('a', 64)),
          PasswordResetToken::hash(str_repeat('a', 64))
      );
  }
  ```

- [ ] **Step 2: Run the focused test and confirm RED.**

  Run: `vendor/bin/phpunit tests/PasswordResetTokenTest.php`

  Expected: failure because `Classes\PasswordResetToken` does not yet exist. If PHP/PHPUnit is unavailable, record the command limitation and keep the test as the executable regression specification.

- [ ] **Step 3: Implement the minimal strict-typed class** with `random_bytes`, `bin2hex`, `hash('sha256', ...)`, `ctype_xdigit`, `DateTimeImmutable`, and explicit `InvalidArgumentException` for invalid TTL values.

- [ ] **Step 4: Run the focused test and confirm GREEN.**

  Run: `vendor/bin/phpunit tests/PasswordResetTokenTest.php`

- [ ] **Step 5: Run `composer dump-autoload`** so the new PSR-4 class is available to the endpoint and reset page.

### Task 2: Extract the shared reset-link mail configuration safely

**Files:**
- Create: `classes/PasswordResetMailer.php`
- Modify: `esqueci-senha.php:370-441`
- Modify: `config/smtp.example.php`

**Interfaces:**
- `Classes\PasswordResetMailer::__construct(array $smtp, string $baseUrl)` validates required SMTP keys and the HTTPS production base URL.
- `Classes\PasswordResetMailer::sendActivationLink(string $recipient, string $activationUrl): void` sends only a link and has no password argument.

- [ ] **Step 1: Write failing tests** for invalid SMTP configuration, invalid recipient e-mail, URL escaping, and link-only body content. The public API under test must expose only `sendActivationLink(string $recipient, string $activationUrl): void`, so the activation flow cannot pass a plaintext password to the mailer.

- [ ] **Step 2: Run the focused test and confirm RED** because the mailer class does not exist.

- [ ] **Step 3: Implement the mailer** using PHPMailer with values loaded from `config/smtp.php`, `PHPMailer::ENCRYPTION_SMTPS` or the configured secure transport, strict e-mail validation, plain-text `AltBody`, escaped HTML link, and generic exception handling that logs only server-side.

- [ ] **Step 4: Update `esqueci-senha.php`** to load the ignored `config/smtp.php` and call the shared mailer while preserving its generic response/rate-limit behavior. Remove all literal SMTP usernames/passwords from that file.

- [ ] **Step 5: Update `config/smtp.example.php`** with the complete documented keys (`host`, `user`, `pass`, `port`, `secure`, `from`, `fromName`) without real credentials.

- [ ] **Step 6: Run the mailer tests and `git diff --check`.** Confirm `rg -n "SMTP.*Password|mail\.coniecp\.com\.br|jes#"` does not find credentials in the changed reset-link flow.

### Task 3: Harden reset consumption and support first-time activation

**Files:**
- Modify: `redefinir-senha.php:76-211`
- Create: `tests/PasswordResetActivationTest.php`

**Interfaces:**
- Create `Classes\PasswordResetActivation::activateOrResetLogin(PDO $db, int $rm, string $passwordHash): void`; it must reject a non-password-hash value, select the e-mail from `cadastroministro`, insert `login (rm, email, senha, password_updated)` when no login exists, and update the existing row otherwise.

- [ ] **Step 1: Write failing tests** using an in-memory SQLite PDO schema containing `cadastroministro(rm, email, acesso)` and `login(rm, email, senha, password_updated)`. Cover both no-login and existing-login outcomes; assert `password_verify()` succeeds, `password_updated` is `1`, `cadastroministro.email` is used, and a plaintext value is rejected.

- [ ] **Step 2: Run the focused test and confirm RED.**

- [ ] **Step 3: Implement the transaction helper** with prepared statements, a server-side lookup of `cadastroministro.email`, an insert/update branch, `cadastroministro.acesso = 'liberado'` only after successful activation, and no plaintext password logging.

- [ ] **Step 4: Make token consumption atomic.** Within one transaction, lock/select the token, reject `used_at` or expired records, update the login, and mark the token used with `WHERE id = :id AND used_at IS NULL`; roll back on any failure.

- [ ] **Step 5: Preserve public recovery behavior** for existing logins, but ensure invalid, expired, or already-used links render generic messages and never reveal whether a RM exists.

- [ ] **Step 6: Run the activation tests and `php -l redefinir-senha.php`.**

### Task 4: Add the authenticated IECP activation endpoint

**Files:**
- Create: `iecp/usuario/enviarLinkAtivacao.php`
- Create: `tests/EnviarLinkAtivacaoRulesTest.php`

**Interfaces:**
- Endpoint: `POST painel.php?pagina=iecp/usuario/enviarLinkAtivacao` with JSON or form-compatible `rm` and `csrf_token`.
- Success JSON: `{ "status": "success", "message": "Link de ativação enviado para o e-mail cadastrado." }`.
- Failure JSON: generic `status: error` with HTTP 400 for invalid input, 403 for CSRF/authorization failure, 404 for an unavailable eligible RM, 405 for a non-POST request, 429 for rate limiting, and 500 for internal mail/database failure.

- [ ] **Step 1: Write failing rule tests** for method rejection, missing/invalid CSRF, non-positive/non-integer RM, cross-IECP RM, ineligible RM, and duplicate pending-token invalidation.

- [ ] **Step 2: Run the focused test and confirm RED.**

- [ ] **Step 3: Implement the endpoint guard sequence:** `declare(strict_types=1)`, secure session/auth includes, `validar_usuario_iecp.php`, JSON headers, no-store headers, POST check, `Classes\Csrf::validateToken`, and a role check matching the page’s allowed IECP admin levels.

- [ ] **Step 4: Query the target using only `$_SESSION['idIecp']`.** Require active minister status, eligible historic function, matching IECP, and no existing `login`; bind all values with PDO types.

- [ ] **Step 5: Invalidate pending tokens, generate/hash the new token, insert only the hash with expiry/IP/user-agent metadata, and build the reset URL from a configured HTTPS base URL.** Never accept e-mail or `idIecp` from the request.

- [ ] **Step 6: Send the link with `PasswordResetMailer`, return generic JSON, and log operational failures without raw tokens or credentials.**

- [ ] **Step 7: Run the endpoint rule tests and `php -l iecp/usuario/enviarLinkAtivacao.php`.**

### Task 5: Rebuild the cadastro page to match the user-list visual system

**Files:**
- Modify: `iecp/usuario/cadastrarUsuario.php`
- Modify: `iecp/usuario/css/cadastrarUsuario.css`
- Modify: `iecp/usuario/js/cadastrarUsuario.js`

**Interfaces:**
- Render a semantic form with `id="cadastroUsuarioForm"`, a scoped select `#rm`, `csrf_token`, `#salvar`, `#carregando`, and `#sucesso`.
- The page must not render `senha`, `novaSenha`, a password generator, an `idIecp` field, or an e-mail value as an authority-bearing form field.

- [ ] **Step 1: Write a focused markup regression check** that fails while the old page contains `id="senha"`, calls the legacy endpoint, or lacks `Csrf::htmlField()`.

- [ ] **Step 2: Run the check and confirm RED.**

- [ ] **Step 3: Refactor the PHP view** with strict types, a safe versioned CSS/JS path, prepared eligible-minister query using the validated session IECP, escaped option values/text, semantic labels, empty state, CSRF field, and accessible status regions.

- [ ] **Step 4: Replace `cadastrarUsuario.css`** with scoped `cu-*` styles derived from `listarUsuario.css`: same navy tokens, light background, card borders/shadows, visible `:focus-visible`, responsive one-column mobile layout, 44px controls, and `prefers-reduced-motion`. Keep the file as CSS and do not add a SCSS-only source without its paired CSS.

- [ ] **Step 5: Replace the legacy JavaScript** with a small controller that reads the CSRF field, validates a selected RM, sends only `{rm, csrf_token}`, disables the button during `fetch`, parses JSON safely, uses `.text()`/`textContent` for messages, and restores the button after completion.

- [ ] **Step 6: Run the markup check, `php -l iecp/usuario/cadastrarUsuario.php`, and `npx eslint iecp/usuario/js/cadastrarUsuario.js`.**

### Task 6: Remove the old create-password dependency and hardcoded secret from the path

**Files:**
- Modify: `meus-dados/cadastrarUsuarioAcao.php`
- Modify: `iecp/usuario/js/editarUsuario.js` only if the shared endpoint contract requires an explicit link action.

- [ ] **Step 1: Write a static regression test** that fails if the new cadastro route still references `meus-dados/cadastrarUsuarioAcao`, sends `novaSenha`, or if the changed endpoint contains a literal SMTP password.

- [ ] **Step 2: Run the check and confirm RED** against the current legacy references.

- [ ] **Step 3: Remove the cadastro-specific legacy branch** or make it return a generic migration response without accepting a plaintext password; keep unrelated self-service behavior unchanged unless the endpoint cannot be safely separated.

- [ ] **Step 4: Replace any remaining SMTP literals in the touched endpoint** with the shared ignored config and a reset-link action, without exposing the password in an e-mail.

- [ ] **Step 5: Run the static regression check and `php -l meus-dados/cadastrarUsuarioAcao.php`.**

### Task 7: Complete verification and handoff

**Files:**
- Modify: none unless a verification exposes a scoped defect.

- [ ] **Step 1: Run the complete focused test command** covering token rules, activation transaction rules, mailer rules, endpoint rules, and page static checks.

- [ ] **Step 2: Run `php -l` for every changed PHP file** and `npx eslint iecp/usuario/js/cadastrarUsuario.js`.

- [ ] **Step 3: Run `git diff --check`, inspect `git diff --stat`, and search changed files for SMTP secrets, raw tokens, `novaSenha`, and `idIecp` request trust.

- [ ] **Step 4: Manually exercise WAMP** at 375, 768, 1024, and 1440px: empty state, valid selection, duplicate-click prevention, valid link request, expired link, reused link, first-time login creation, password reset, keyboard navigation, and generic error states.

- [ ] **Step 5: Confirm the deployment prerequisite:** production has `config/smtp.php` outside version control and the existing `password_reset_tokens` table; report either prerequisite explicitly if unavailable.

- [ ] **Step 6: Review the final diff against the approved design and use the finishing-development-branch workflow before making completion claims.**
