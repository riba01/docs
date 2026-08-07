# Engineering Governance

## Purpose

This document defines the mandatory engineering, security, compatibility, architecture, database, UI/UX, validation, and regression rules for the SISCONIECP repository.

These rules apply to every:

- implementation;
- bug fix;
- refactoring;
- modernization;
- security correction;
- database change;
- UI/UX change;
- performance optimization;
- maintenance task;
- code review;
- documentation update;
- automated agent task.

This document complements `AGENTS.md`.

When a rule in this document conflicts with a more specific repository instruction, the most specific applicable instruction must be followed, provided that it does not weaken security, production compatibility, or data integrity.

The agent must not bypass these rules merely to reduce implementation effort.

---

# 1. Mandatory Instruction Loading

Before analyzing or modifying project files, the agent must read:

1. `AGENTS.md`
2. `.codex/skills/ui-ux-pro-max/SKILL.md`
3. `docs/ai/ENGINEERING-GOVERNANCE.md`
4. `README.md`, when present
5. `CLAUDE.md`, when applicable
6. module-specific documentation
7. nested `AGENTS.md` or `AGENTS.override.md`, when present
8. database environment documentation when SQL is involved

For database-related work, also read:

- `database/schema/README.md`
- `database/schema/production-environment.md`
- `database/schema/sisconiecp.production.schema.sql`
- `database/schema/sisconiecp.local.schema.sql`, when needed

The agent must not claim to have read or applied a file without actually reading it.

If a mandatory instruction file is missing, inaccessible, empty, or incomplete, implementation must not start until the limitation is reported.

---

# 2. Preserve Existing Work

Before modifying files:

1. Inspect the current Git status.
2. Identify modified files.
3. Identify staged files.
4. Identify untracked files.
5. Preserve existing user changes.
6. Avoid overwriting concurrent work.

Never execute without explicit authorization:

- `git reset --hard`;
- destructive `git checkout`;
- `git restore` that discards user changes;
- automatic stash operations;
- broad file deletion;
- removal of untracked files;
- history rewriting.

The agent must work with the repository as found.

Existing changes must not be silently reverted because they differ from the expected baseline.

---

# 3. Scope Control

Implement only what is required to solve the demand correctly.

Do not transform a targeted task into an unrelated project-wide refactoring.

Avoid:

- broad renaming;
- unnecessary folder restructuring;
- unrelated formatting changes;
- replacing working components without technical justification;
- rewriting complete modules to fix a small defect;
- creating duplicate abstractions.

Changes should remain focused, reviewable, and reversible.

Security problems found directly inside the affected scope should be corrected when reasonably possible.

Security findings outside the task scope may be reported without triggering uncontrolled refactoring.

---

# 4. Reuse Before Creation

Before creating a new:

- class;
- helper;
- utility;
- validator;
- repository;
- component;
- stylesheet;
- JavaScript module;
- database connection;
- CSRF implementation;
- session mechanism;
- modal;
- alert system;
- UI component;
- PDF helper;
- upload processor;
- sanitization mechanism;

search the repository for an existing equivalent solution.

Prefer reuse of existing solutions when they are secure and adequate.

Important examples include:

- `Classes\Connect`;
- existing sanitization classes;
- CSRF helpers;
- security-header implementations;
- existing PDF components;
- existing CSS design tokens;
- existing form validation patterns;
- existing database repositories;
- existing JavaScript utilities;
- existing components already used by the same module.

Do not create a second implementation merely because it appears easier.

When creating a new implementation is necessary, explain why the existing solution could not be reused.

---

# 5. PHP Version and Compatibility

All changed PHP code must target PHP 8.5 or higher.

Every changed standalone PHP file must use:

```php
<?php

declare(strict_types=1);
```

Use explicit typing wherever compatible with existing contracts:

- method parameters;
- function parameters;
- return types;
- class properties;
- constructor arguments.

Prefer modern PHP features when they improve clarity, safety, or maintainability.

Applicable features include:

- `match`;
- enums;
- `readonly`;
- nullsafe operator `?->`;
- constructor property promotion;
- attributes;
- union types;
- intersection types when appropriate;
- `never`;
- `mixed` only when unavoidable.

Do not introduce modern syntax only for cosmetic reasons.

Do not break public contracts used by legacy modules.

Before changing a public method signature, variable contract, request field, route, return shape, or class behavior, search all usages.

---

# 6. PHP Coding Standards

Follow PSR-12 where compatible with the existing repository structure.

Mandatory practices:

- `declare(strict_types=1);`;
- meaningful variable names;
- explicit return types;
- explicit visibility;
- small cohesive methods;
- early returns where they reduce nesting;
- exceptions for exceptional situations;
- no suppressed errors with `@`;
- no hidden side effects when avoidable.

Avoid:

- deeply nested conditionals;
- very large methods;
- repeated business logic;
- repeated SQL;
- magic values with unclear meaning;
- global state when a project abstraction already exists.

Comments and internal documentation must preferably be written in Portuguese.

Comments should explain:

- business rules;
- non-obvious technical decisions;
- security decisions;
- compatibility restrictions;
- legacy constraints.

Do not add comments that merely translate obvious code into natural language.

---

# 7. Database Connection

Database access must use PDO.

Reuse:

```php
Classes\Connect
```

or the existing approved equivalent.

Do not introduce:

- `mysqli`;
- direct MySQL connections;
- hard-coded credentials;
- duplicated connection classes;
- direct credentials inside PHP files.

Prepared statements are mandatory for variable or external values.

Preferred convention:

```php
$stmt
```

for PDO prepared statements.

Example:

```php
$sql = <<<'SQL'
    SELECT
        id,
        nome,
        status
    FROM tabela
    WHERE id = :id
SQL;

$stmt = $conexao->prepare($sql);

$stmt->execute([
    ':id' => $id,
]);
```

Never concatenate untrusted values directly into SQL.

---

# 8. Production Database Environment

The production database is hosted by HostGator.

Production environment:

- Database server: Percona Server
- Version: `5.7.44-48`
- Compatibility target: MySQL `5.7`
- SQL mode: `NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION`
- Server charset: `utf8`
- Server collation: `utf8_unicode_ci`

The local development environment may use MySQL 8.x.

The production database is the minimum mandatory compatibility target.

A query working locally on MySQL 8 does not prove production compatibility.

---

# 9. Database Schema Sources

Use the following source priority:

1. `database/schema/sisconiecp.production.schema.sql`
2. `database/schema/production-environment.md`
3. existing application queries and classes
4. `database/schema/sisconiecp.local.schema.sql`
5. local database inspection

Never invent:

- tables;
- fields;
- keys;
- indexes;
- relations;
- constraints;
- status values;
- engines.

Before writing SQL, confirm the real schema.

When production and local schemas differ, preserve production compatibility and report the divergence.

Schema files must never be imported automatically.

---

# 10. MySQL 5.7 Compatibility

Do not introduce SQL features exclusive to MySQL 8.

Examples of prohibited MySQL 8-only features include:

- Common Table Expressions using `WITH`;
- window functions;
- `ROW_NUMBER()`;
- `RANK()`;
- `DENSE_RANK()`;
- `LAG()`;
- `LEAD()`;
- `OVER`;
- `JSON_TABLE`;
- functional indexes;
- invisible indexes;
- `EXPLAIN ANALYZE`;
- `REGEXP_REPLACE`;
- `REGEXP_LIKE`;
- `REGEXP_SUBSTR`;
- `REGEXP_INSTR`;
- `ALTER TABLE ... RENAME COLUMN`;
- `utf8mb4_0900_*` collations;
- `NOWAIT`;
- `SKIP LOCKED`;
- MySQL 8-only expression defaults.

When renaming a column in a formally approved migration, use syntax compatible with MySQL 5.7.

Do not rely on `CHECK` constraints for critical business validation because MySQL 5.7 does not reliably enforce them.

---

# 11. SQL Mode Considerations

Production SQL mode is:

```text
NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
```

Strict SQL mode is not enabled.

Application code must therefore validate values before database execution.

Do not depend on MySQL to reject automatically:

- oversized strings;
- malformed numbers;
- invalid dates;
- zero dates;
- implicit type conversion;
- ambiguous grouped queries;
- numeric overflow;
- invalid business values.

Validation must happen in PHP.

Do not enable strict SQL mode globally or per connection as part of an unrelated refactoring.

Changing SQL mode requires a separate compatibility project with legacy audit and regression testing.

---

# 12. Charset and Unicode

The production server default charset is:

```text
utf8
```

with:

```text
utf8_unicode_ci
```

The legacy MySQL `utf8` implementation supports up to three bytes per character.

Do not assume that every Unicode character can be stored.

When a new table or column is formally introduced and production compatibility is confirmed, prefer:

```sql
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci
```

Do not use:

```text
utf8mb4_0900_ai_ci
```

or other MySQL 8-specific collations.

Do not automatically convert existing tables to another charset or collation.

---

# 13. SQL Query Quality

Avoid:

```sql
SELECT *
```

when the required fields are known.

Prefer explicit columns.

Review queries for:

- unnecessary joins;
- duplicated joins;
- N+1 patterns;
- unbounded result sets;
- missing filters;
- unnecessary sorting;
- indexes that are not used;
- functions applied to indexed columns;
- unnecessary subqueries;
- repeated queries inside loops.

Use `EXPLAIN` for relevant performance analysis.

Do not use `EXPLAIN ANALYZE`, because production must remain compatible with MySQL 5.7.

When recommending indexes, confirm existing indexes first.

Do not create duplicate or redundant indexes.

---

# 14. GROUP BY and Aggregations

New and modified aggregate queries must be deterministic.

Do not rely on the permissive production SQL mode.

Avoid queries that select nonaggregated fields without appropriate grouping.

Every selected field in an aggregate query must be:

- part of `GROUP BY`;
- aggregated;
- or validly functionally dependent in MySQL 5.7.

Queries should remain correct even if stricter SQL modes are adopted in the future.

---

# 15. Storage Engines

The legacy database contains both:

- InnoDB;
- MyISAM.

Always verify the engine of tables involved in write operations.

InnoDB supports:

- transactions;
- `COMMIT`;
- `ROLLBACK`;
- foreign keys;
- row-level locking.

MyISAM does not provide transactional rollback.

Never claim that a multi-step operation is atomic when a modified table uses MyISAM.

Do not automatically convert MyISAM tables to InnoDB.

Engine migration requires a separate task with:

- backup;
- compatibility assessment;
- foreign-key analysis;
- performance evaluation;
- deployment strategy;
- rollback strategy.

---

# 16. Transactions

Transactions are mandatory when multiple related writes must remain consistent and all affected tables support transactions.

Typical examples:

- accounting operations;
- financial entries;
- receipts;
- payments;
- monthly balances;
- transfers;
- minister registration;
- member movement;
- access control changes;
- multi-table updates.

Expected pattern:

```php
try {
    $conexao->beginTransaction();

    // Operações relacionadas.

    $conexao->commit();
} catch (Throwable $exception) {
    if ($conexao->inTransaction()) {
        $conexao->rollBack();
    }

    error_log('Erro na operação: ' . $exception->getMessage());

    // Resposta segura para o usuário.
}
```

Do not wrap simple read-only operations in transactions.

Before using transactions, inspect every participating table engine.

---

# 17. Direct Database Inspection

Direct database inspection is permitted only when a configured read-only local connection exists.

Preferred use cases:

- inspect table definitions;
- inspect indexes;
- inspect engines;
- inspect schema metadata;
- execute `EXPLAIN`;
- validate limited structural information.

Permitted operations include:

```sql
SHOW TABLES;
SHOW CREATE TABLE tabela;
DESCRIBE tabela;
SHOW COLUMNS FROM tabela;
SHOW INDEX FROM tabela;
EXPLAIN SELECT ...;
```

Queries against `information_schema` are also permitted.

Without explicit authorization, never execute through agent inspection:

```sql
INSERT;
UPDATE;
DELETE;
REPLACE;
TRUNCATE;
ALTER;
DROP;
CREATE;
RENAME;
GRANT;
REVOKE;
```

Do not connect directly to production for routine development analysis.

---

# 18. SQL Injection Prevention

Every external value used in SQL must be parameterized.

External sources include:

- `$_GET`;
- `$_POST`;
- `$_REQUEST`;
- route parameters;
- cookies;
- session values that originated from user input;
- API payloads;
- uploaded file metadata;
- headers.

Never write:

```php
$sql = "SELECT * FROM usuario WHERE id = $id";
```

Use prepared statements.

Dynamic identifiers such as column names or sort directions cannot be parameterized using normal placeholders.

They must be selected through explicit allowlists.

Example:

```php
$allowedOrder = [
    'nome' => 'nome',
    'data' => 'data',
];

$orderBy = $allowedOrder[$requestedOrder] ?? 'nome';
```

---

# 19. Input Validation

Validate all external input on the server.

Client-side validation improves UX but is not a security boundary.

Use the appropriate validation strategy for:

- integers;
- decimal values;
- dates;
- emails;
- enum-like statuses;
- IDs;
- strings;
- uploaded files;
- arrays;
- optional fields.

Do not use deprecated:

```php
FILTER_SANITIZE_STRING
```

Prefer validation plus context-specific output encoding.

Do not blindly alter user content during sanitization.

Validation and sanitization are different concerns.

---

# 20. Output Encoding and XSS

Escape dynamic HTML output according to context.

For ordinary HTML text:

```php
htmlspecialchars(
    $value,
    ENT_QUOTES | ENT_SUBSTITUTE,
    'UTF-8'
);
```

Prefer existing project helpers when available.

Do not double-escape content.

Do not rely on input sanitization alone to prevent XSS.

Escape when rendering.

For trusted rich HTML, use the project's established sanitization strategy.

DOMPurify should only be used when rich HTML is genuinely required and the project already uses it appropriately.

---

# 21. CSRF

Every state-changing form or endpoint must have CSRF protection.

Examples:

- create;
- update;
- delete;
- send;
- approve;
- reject;
- archive;
- cancel;
- password changes;
- financial operations;
- permissions.

Reuse the existing CSRF implementation.

Do not create duplicate token systems unnecessarily.

CSRF validation must happen on the server.

A hidden input without server validation is not CSRF protection.

---

# 22. Authentication and Authorization

Authentication verifies identity.

Authorization verifies permission.

Both are mandatory.

Never depend only on:

- hidden buttons;
- disabled controls;
- UI visibility;
- JavaScript;
- client-provided roles.

Authorization must be enforced server-side.

Before sensitive actions, validate the authenticated user's effective permissions.

Do not trust access-level information coming directly from the client.

---

# 23. Password Security

Passwords must use:

```php
password_hash()
```

with:

```php
PASSWORD_ARGON2ID
```

when supported by the environment.

Verification must use:

```php
password_verify()
```

Never:

- store plain-text passwords;
- log passwords;
- send passwords in URLs;
- expose password hashes;
- manually implement password hashing;
- use MD5 or SHA-1 for password storage.

Legacy password mechanisms discovered inside the affected scope should be carefully modernized without locking existing users out.

---

# 24. Sessions

Session handling must follow secure practices.

When appropriate:

- regenerate the session ID after authentication;
- regenerate after meaningful privilege changes;
- configure secure cookie attributes;
- protect against session fixation;
- expire inactive sessions;
- invalidate sessions on logout;
- avoid storing unnecessary sensitive information.

Do not expose session IDs.

Do not log complete session identifiers.

---

# 25. Error Handling

Never expose technical exception details directly to users.

Do not output:

- SQL messages;
- stack traces;
- filesystem paths;
- credentials;
- internal exception messages;
- configuration details.

Use generic user-facing messages.

Technical details may be sent to:

```php
error_log()
```

or an approved logging mechanism.

Example:

```php
try {
    // Operação.
} catch (Throwable $exception) {
    error_log('Falha ao processar operação: ' . $exception->getMessage());

    $mensagem = 'Não foi possível concluir a operação.';
}
```

Do not log sensitive personal or credential information.

---

# 26. File Upload Security

Uploads must validate:

- file size;
- MIME type;
- allowed extension;
- generated storage filename;
- destination path;
- path traversal;
- storage permissions.

Do not trust:

```php
$_FILES['arquivo']['type']
```

as authoritative.

Use server-side MIME detection when appropriate.

Do not allow uploaded filenames to determine final filesystem paths directly.

Generate safe names.

Files should not be executable when they are intended only for storage.

---

# 27. Content Security Policy

Do not weaken the project's Content Security Policy.

Never introduce:

```text
unsafe-inline
unsafe-eval
```

Do not add duplicate CSP headers.

Reuse the centralized CSP implementation.

Avoid introducing a second security header mechanism that conflicts with existing headers.

Security policy changes must be deliberate and reviewed.

---

# 28. JavaScript Security

Never introduce:

- `eval()`;
- `new Function()`;
- `javascript:` URLs;
- inline event handlers;
- dynamically generated executable code;
- unsafe interpolation of user-controlled content.

Do not add:

```html
onclick="" onchange="" onload=""
```

Use:

```javascript
element.addEventListener(...)
```

Do not insert untrusted values with `innerHTML`.

Prefer:

```javascript
textContent;
```

when rendering plain text.

When trusted HTML is required, use the established sanitization mechanism.

---

# 29. No Inline JavaScript

Do not introduce inline `<script>` blocks inside PHP or HTML templates.

JavaScript must live in external files.

Avoid mixing JavaScript implementation directly into PHP templates.

PHP may expose data using safe structured mechanisms such as:

- `data-*` attributes;
- JSON encoded safely;
- dedicated endpoints.

Use secure JSON encoding when transferring PHP data to JavaScript.

---

# 30. Modern JavaScript

Prefer modern browser APIs.

Use:

- `const`;
- `let`;
- `fetch`;
- `async/await`;
- `addEventListener`;
- ES modules when compatible;
- `AbortController` when cancellation is useful;
- `FormData`;
- Constraint Validation API where applicable.

Do not introduce jQuery into new functionality unless the affected legacy module already depends on it and replacing it would create unnecessary risk.

Existing jQuery can be modernized incrementally when the demand requires it.

---

# 31. UI/UX Skill

The following skill is mandatory:

```text
.codex/skills/ui-ux-pro-max/SKILL.md
```

It must be considered in every task.

For interface-related work, it must be actively applied.

The skill must not override the existing SISCONIECP visual identity.

Reuse existing:

- colors;
- typography;
- spacing;
- buttons;
- tables;
- forms;
- cards;
- navigation;
- icons;
- visual feedback patterns.

Do not redesign unrelated screens merely because a UI task exists.

---

# 32. UI Consistency

Before creating a new visual pattern, search for an existing equivalent component.

Maintain consistency between modules.

Avoid:

- random color variations;
- inconsistent border radius;
- duplicate button styles;
- conflicting spacing systems;
- arbitrary typography;
- unnecessary visual effects.

Prefer established design tokens and CSS variables when present.

---

# 33. Responsive Design

Every interface change must be evaluated on:

- desktop;
- tablet;
- mobile.

Avoid:

- fixed widths that overflow;
- uncontrolled horizontal scrolling;
- overlapping content;
- clipped controls;
- excessively small touch targets;
- inaccessible tables.

Use:

- CSS Grid;
- Flexbox;
- responsive units;
- controlled breakpoints.

Do not solve structural problems by hiding overflowing content.

---

# 34. Accessibility

Follow WCAG principles when modifying interfaces.

At minimum:

- use semantic HTML;
- associate labels with inputs;
- preserve keyboard navigation;
- provide visible focus;
- maintain adequate contrast;
- provide meaningful button labels;
- provide accessible validation feedback;
- avoid color-only communication;
- use ARIA only when native semantics are insufficient.

Interactive elements must remain usable without a mouse.

---

# 35. Forms

Forms must provide:

- associated labels;
- appropriate input types;
- clear required-state indication;
- server-side validation;
- client-side UX validation where useful;
- field-level feedback;
- form-level error feedback when appropriate;
- CSRF protection for state changes.

Do not clear valid form data unnecessarily after a validation failure.

Sensitive forms should avoid autocomplete behaviors that create security risk, but do not disable autocomplete indiscriminately.

---

# 36. Tables

Tables must remain readable and accessible.

Use:

- semantic `<table>`;
- `<thead>`;
- `<tbody>`;
- `<th>`;
- correct header associations.

On smaller screens, use a controlled responsive strategy.

Do not create uncontrolled page-level horizontal overflow.

For large datasets, consider:

- pagination;
- server-side filtering;
- lazy loading;
- limited result sets.

Do not load thousands of records into the browser unnecessarily.

---

# 37. User Feedback States

Relevant UI flows should consider:

- loading;
- empty;
- error;
- success;
- disabled;
- unauthorized;
- blocked;
- no results.

Do not leave users without feedback during asynchronous operations.

Avoid duplicate submissions.

When appropriate, disable the submit action while a request is running.

Re-enable it safely after completion or failure.

---

# 38. SCSS and CSS

When SCSS exists for an affected stylesheet, maintain SCSS and compiled CSS synchronization.

Runtime pages must reference `.css`, never `.scss`.

If a compiler is unavailable:

1. update the source carefully;
2. ensure corresponding CSS receives the required change;
3. report the limitation;
4. verify runtime CSS.

Do not use inline styles.

Prefer reusable CSS classes.

---

# 39. CSS Quality

Use modern CSS.

Prefer:

- Grid;
- Flexbox;
- custom properties;
- responsive sizing;
- logical grouping.

Avoid excessive:

- `!important`;
- deeply nested selectors;
- duplicated rules;
- magic pixel values;
- specificity escalation.

Microanimations should remain subtle and functional.

Respect:

```css
@media (prefers-reduced-motion: reduce);
```

when animations are introduced.

---

# 40. Dependency Management

Before using a dependency:

1. inspect `composer.json` or `package.json`;
2. confirm the installed version;
3. confirm compatibility with the runtime;
4. prefer existing dependencies.

Do not add a new dependency when native functionality or an existing dependency is sufficient.

Do not update dependency versions automatically unless required by the demand.

Avoid unintended modifications to lock files.

Review known vulnerabilities when dependency work is part of the task.

---

# 41. Composer and PHP Dependencies

Before relying on a package API, verify the installed version.

Do not assume current online documentation matches the project's installed dependency.

Important examples include:

- mPDF;
- HTMLPurifier;
- PHPUnit;
- Composer packages related to security.

Use the API supported by the installed project version.

---

# 42. Performance

Performance improvements must be based on actual bottlenecks or obvious inefficiencies.

Review:

- repeated SQL;
- N+1 queries;
- excessive file access;
- repeated expensive computations;
- unnecessary loops;
- oversized responses;
- unbounded result sets;
- repeated DOM manipulation.

Use caching when it produces a concrete benefit.

Potential strategies include:

- Redis;
- HTTP cache;
- ETag;
- `Last-Modified`;
- application-level caching.

Do not introduce caching without an invalidation strategy.

---

# 43. Financial and Accounting Data

Financial operations require additional care.

Relevant changes must preserve:

- amounts;
- dates;
- accounting classification;
- entry type;
- institution ownership;
- receipt associations;
- balance calculations;
- historical traceability.

Do not use floating-point arithmetic for new monetary application logic when exact decimal arithmetic is required.

Database legacy columns may use `double`, but new or migrated financial schema should prefer appropriate `DECIMAL` types.

Do not alter financial precision silently.

---

# 44. Church Accounting

When implementing accounting features for churches or religious institutions, consider:

- Livro Diário;
- Livro Razão;
- Balancete;
- Balanço Patrimonial;
- demonstrações contábeis;
- dízimos;
- ofertas;
- doações;
- despesas;
- patrimônio;
- accountability;
- tax immunity or exemption records.

Applicable accounting requirements must respect the project's established business model and relevant Brazilian accounting standards.

Do not invent accounting classifications without confirming the project's chart of accounts and business rules.

---

# 45. Legacy Behavior

The repository contains legacy procedural PHP and legacy database structures.

Modernization must be incremental.

Do not break working functionality merely to make code appear architecturally modern.

Before refactoring legacy code:

1. identify callers;
2. identify request parameters;
3. identify session dependencies;
4. identify included files;
5. identify variables expected by templates;
6. identify database contracts;
7. identify JavaScript dependencies;
8. identify returned HTML or JSON structures.

Preserve observable behavior unless changing it is part of the demand.

---

# 46. Security Modernization

When insecure legacy code lies directly in the modification path, modernize it when feasible.

Examples:

- SQL string concatenation to prepared statements;
- unsafe output to escaped output;
- inline JS to external JS;
- missing CSRF;
- direct exception output to safe error handling;
- insecure password handling;
- unvalidated identifiers.

Do not leave newly modified code using insecure patterns merely because the surrounding legacy code still contains them.

---

# 47. Avoid Security Theater

Security controls must provide real protection.

Examples of invalid security practices include:

- sanitizing an integer instead of validating it;
- CSRF hidden input without server verification;
- role checking only in JavaScript;
- escaping SQL instead of using prepared statements;
- hiding buttons instead of enforcing authorization;
- adding CSP while keeping `unsafe-inline` unnecessarily;
- checking only file extension during uploads.

Implement effective controls.

---

# 48. Business Rules

Do not change business rules without explicit demand.

When code behavior appears unusual:

1. search the repository;
2. inspect related classes;
3. inspect database structures;
4. inspect documentation;
5. inspect historical patterns.

Do not "correct" behavior based solely on assumptions.

If business logic is ambiguous, preserve current behavior unless the requested change clearly requires otherwise.

---

# 49. Implementation Sequence

For each demand:

1. Read mandatory instructions.
2. Inspect Git status.
3. Identify affected files.
4. Inspect dependencies.
5. Inspect existing equivalent solutions.
6. Inspect database schema when applicable.
7. Inspect security implications.
8. Inspect compatibility implications.
9. Inspect UI/UX implications.
10. Determine regression risks.
11. Present a concise plan for complex work.
12. Implement focused changes.
13. Review the diff.
14. Execute applicable validation.
15. Check for regressions.
16. Report results accurately.

---

# 50. Validation Requirements

Every changed PHP file must be syntax checked when PHP is available.

Example:

```bash
php -l caminho/do/arquivo.php
```

When JavaScript changes:

- run the configured ESLint command;
- verify syntax;
- verify runtime behavior when possible.

When CSS or SCSS changes:

- verify syntax;
- verify synchronization;
- inspect responsive behavior.

When SQL changes:

- verify MySQL 5.7 compatibility;
- inspect real tables;
- use `EXPLAIN` when performance is relevant;
- ensure no MySQL 8-only syntax exists.

Do not run unrelated massive validations when a focused validation is sufficient, unless project policy requires broader checks.

---

# 51. Security Searches

When applicable, inspect the changed scope for:

```text
unsafe-inline
unsafe-eval
eval(
new Function(
onclick=
onchange=
onload=
javascript:
<script
style=
mysqli
```

Also inspect for:

- concatenated SQL;
- hard-coded credentials;
- raw exception output;
- direct stack trace output;
- unsafe `innerHTML`;
- duplicated CSP headers.

Do not blindly replace search results.

Review findings in context.

---

# 52. Regression Checklist

Before considering a task complete, verify as applicable:

- PHP syntax remains valid.
- JavaScript lint passes.
- Routes still work.
- Includes remain correct.
- Namespaces remain valid.
- Composer autoload remains valid.
- Request parameters remain compatible.
- Response structures remain compatible.
- SQL fields actually exist.
- SQL works with MySQL 5.7.
- No MySQL 8-only resource was introduced.
- Authentication still works.
- Authorization still works.
- CSRF remains functional.
- Session flow remains valid.
- CSP was not weakened.
- UI layout remains usable.
- Mobile layout remains usable.
- Keyboard navigation remains usable.
- Existing user changes remain preserved.
- No credentials were committed.
- No schema file was accidentally executed.
- No unnecessary dependency was introduced.
- No MyISAM operation was falsely described as transactional.

---

# 53. Manual Testing

When a local runtime is available, manually exercise the affected flow when practical.

Test relevant cases such as:

- valid input;
- invalid input;
- missing input;
- empty results;
- unauthorized access;
- expired session;
- duplicate submission;
- server error;
- network error;
- loading state;
- success state.

Do not claim manual testing when the application could not actually be executed.

---

# 54. Automated Tests

When tests already exist for the affected module, execute them.

Do not treat ad hoc files such as:

```text
teste.php
Testa1.php
```

as a formal automated suite unless the repository explicitly defines them as such.

If no automated test infrastructure exists, do not create an entire framework unless required by the demand.

Add focused tests when the existing project infrastructure supports them and the change benefits from coverage.

---

# 55. Static Analysis and Audits

Use available project tooling when applicable.

Possible tools include:

- PHPStan;
- PHPUnit;
- Composer validation;
- Composer audit;
- ESLint;
- Prettier;
- CSP scans;
- npm audit;
- project-specific validators.

Do not invent commands.

Inspect project configuration first.

If a tool is not installed, report that fact instead of claiming validation.

---

# 56. Documentation

Document changed code where necessary.

Update documentation when changes affect:

- public behavior;
- configuration;
- environment requirements;
- database structure;
- API contracts;
- security processes;
- user workflows.

Do not create documentation merely to increase file count.

Keep documentation accurate and maintainable.

---

# 57. Database Schema Maintenance

When the database structure changes through an approved process:

1. update `sisconiecp.production.schema.sql` when production is updated;
2. update `sisconiecp.local.schema.sql` when local schema changes;
3. update `production-environment.md` if production characteristics change;
4. review schema diffs;
5. ensure no real records are included;
6. ensure no secrets are included.

Schema dumps stored in the repository must contain structure only.

Never commit full production data dumps.

---

# 58. Sensitive Data

The repository must not expose:

- database passwords;
- API secrets;
- private keys;
- access tokens;
- session tokens;
- password reset tokens;
- personal data dumps;
- financial record dumps;
- production backups.

Configuration containing local secrets must be excluded through `.gitignore`.

Do not echo secrets in terminal commands when a safer configuration file is available.

---

# 59. Logging

Logs must support troubleshooting without exposing sensitive data.

Never log unnecessarily:

- passwords;
- tokens;
- full session IDs;
- complete CPF values;
- full financial records;
- authentication secrets.

Use useful context such as:

- operation name;
- internal identifier where safe;
- error category;
- technical exception message when it does not expose sensitive content.

User-facing messages must remain generic.

---

# 60. Destructive Operations

Destructive operations require explicit user authorization.

Examples:

- deleting files;
- removing database objects;
- dropping columns;
- truncating tables;
- deleting records;
- resetting Git;
- removing dependencies;
- mass renaming.

Do not infer permission for destructive actions from a generic modernization request.

---

# 61. Database Migrations

Do not execute database migrations automatically unless the demand explicitly authorizes it.

Before proposing migration SQL:

1. confirm production version;
2. inspect table engine;
3. inspect current indexes;
4. inspect data type;
5. inspect affected code;
6. consider rollback;
7. consider downtime;
8. consider data conversion.

Migration SQL must remain compatible with Percona Server 5.7.44-48 unless the production environment is formally upgraded.

---

# 62. Production Safety

Never perform routine development work directly against production.

Production operations require explicit authorization.

The preferred workflow is:

1. inspect versioned production schema;
2. develop locally;
3. validate against MySQL 5.7 compatibility;
4. test locally;
5. review diff;
6. deploy through the project's approved process.

Do not use production as a test environment.

---

# 63. External Libraries and CDN Resources

Before adding external CDN resources, verify whether the project already includes the dependency locally.

Prefer existing local dependencies when practical.

Do not introduce external scripts without considering:

- CSP;
- Subresource Integrity;
- privacy;
- availability;
- version pinning;
- dependency risk.

Do not weaken CSP merely to load a new frontend dependency.

---

# 64. TinyMCE and Rich Text

When modifying flows that use TinyMCE:

- inspect the project's installed TinyMCE version;
- preserve existing configuration when possible;
- do not trust HTML solely because it came from TinyMCE;
- sanitize rich content on the server according to project policy;
- preserve CSP compatibility;
- avoid inline initialization when external JavaScript can be used.

Do not introduce a second rich-text editor without a specific requirement.

---

# 65. PDF Generation

When modifying PDF generation:

- reuse existing PDF helpers;
- inspect the installed mPDF version;
- verify encoding;
- use UTF-8 consistently;
- avoid passing malformed strings;
- reuse centralized headers and footers;
- avoid duplicate PDF layout logic.

Do not depend on undocumented behavior from newer mPDF versions if the project has an older installed version.

---

# 66. Existing User Changes

Existing user modifications always take precedence over assumptions about repository state.

When a target file already contains unrelated modifications:

- preserve them;
- modify only the required area;
- inspect the final diff carefully.

Do not normalize or rewrite unrelated code just because the file is already open.

---

# 67. No False Claims

The agent must never state:

- "tested successfully";
- "build passed";
- "lint passed";
- "skill applied";
- "database verified";
- "production compatible";
- "manual flow validated";

unless the corresponding validation actually occurred.

When a validation was not possible, say:

- what was not validated;
- why it could not be validated;
- what remains to be checked.

Accuracy is more important than appearing complete.

---

# 68. Final Response

The final response for implementation tasks must follow the structure defined in `AGENTS.md`.

At minimum it must cover:

## Resultado

Summarize objectively what was implemented.

## Arquivos alterados

List every file changed and its purpose.

## Soluções reutilizadas

Identify existing project solutions reused.

## Segurança

Describe relevant security controls and corrections.

## Compatibilidade

Describe:

- PHP 8.5 compatibility;
- dependency compatibility;
- MySQL 5.7 compatibility;
- production versus local database considerations.

## Validações executadas

List only validations that were actually executed.

Include their real outcomes.

## Possíveis pendências

List only actual limitations or unresolved risks.

Do not manufacture pending tasks merely to fill the section.

---

# 69. Definition of Done

A task is not considered complete until all applicable conditions below have been evaluated:

- mandatory instructions were read;
- existing user changes were preserved;
- scope remained controlled;
- existing solutions were reused when appropriate;
- PHP code is compatible with PHP 8.5+;
- SQL is compatible with production MySQL 5.7;
- PDO prepared statements are used;
- relevant security controls are applied;
- CSP was not weakened;
- no insecure inline JavaScript was introduced;
- UI/UX requirements were evaluated;
- accessibility was considered;
- database engines were checked where relevant;
- transactions are only claimed where effective;
- changed code was validated using available tools;
- regression risks were reviewed;
- final diff was inspected;
- unresolved limitations were reported accurately.

---

# 70. Core Principle

Prefer a solution that is:

1. secure;
2. compatible with production;
3. consistent with existing project architecture;
4. reusable;
5. maintainable;
6. performant;
7. accessible;
8. easy to validate;
9. minimally disruptive.

Modernization is encouraged, but never at the cost of:

- breaking production;
- weakening security;
- changing business rules unintentionally;
- losing user work;
- creating unnecessary complexity.
