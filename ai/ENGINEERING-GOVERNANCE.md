# Engineering Governance

## Purpose

This document defines the mandatory engineering, security, compatibility, architecture, database, UI/UX, quality, testing, deployment, and regression rules for the SISCONIECP repository.

It is intentionally focused on **how the software must be built and evolved**. Operational instructions for automated agents — instruction loading, Git safety, task sequencing, command execution, destructive actions, and final-response format — belong in `AGENTS.md`.

The architectural direction combines modern PHP 8.5 practices, object-oriented design, SOLID, established design patterns, Composer/PSR standards, secure-by-design engineering, and incremental modernization suitable for a legacy PHP application.

Its object-design philosophy is intentionally aligned with the enduring ideas popularized in _PHP Objects, Patterns, and Practice_: responsibilities before patterns, explicit collaboration, encapsulation, low coupling, composition, and patterns applied only when they solve a concrete design problem.

---

# 1. Engineering Scope and Normative Language

This document is the source of truth for how SISCONIECP software should be designed, implemented, secured, tested, evolved, and operated.

It complements `AGENTS.md`:

- `AGENTS.md` defines **how an automated agent must work in the repository**.
- this document defines **how the software itself must be built and evolved**.

The following terms are normative:

- **MUST / MUST NOT**: mandatory rule. Exceptions require an explicit technical reason and must not weaken security, production compatibility, data integrity, or established business rules.
- **SHOULD / SHOULD NOT**: preferred rule. Deviations are acceptable when justified by the affected legacy context or a simpler and safer design.
- **MAY**: optional practice that can be adopted when it provides concrete value.

Engineering decisions must prefer solutions that are secure, compatible with production, clear, testable, maintainable, minimally disruptive, and proportionate to the problem being solved.

---

# 2. Reuse Before Creation

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

# 3. PHP Version and Compatibility

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

# 4. PHP Coding Standards

Follow PSR-12 where compatible with the existing repository structure.

Mandatory practices:

- `declare(strict_types=1);`;- meaningful variable names;
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

# 5. Composer, PSR-4, and Autoloading

Composer is the standard dependency manager for PHP code in this repository.

For code already autoloaded by Composer, preserve the existing namespace and directory conventions.

For new object-oriented modules or classes that can be introduced without breaking legacy contracts:

- prefer Composer autoloading;
- prefer PSR-4-compatible namespaces and paths;
- do not create manual `require`/`include` chains when an existing Composer autoload path can solve the problem safely;
- do not reorganize legacy procedural entry points solely to obtain PSR-4 compliance;
- verify the actual `composer.json` mapping before creating namespaces or moving classes;
- preserve public class names and legacy filenames when external callers depend on them.

`composer.json` and `composer.lock` are part of the dependency contract.

Production installation should use the locked dependency graph. Dependency updates must be deliberate and reviewed, not an incidental side effect of unrelated work.

---

# 6. Object-Oriented Design

Object-oriented code must model responsibilities and collaboration, not merely move procedural code into classes.

Prefer objects that:

- have a clear reason to exist;
- own a cohesive responsibility;
- expose intention-revealing behavior;
- protect their own valid state when practical;
- collaborate through explicit dependencies;
- minimize knowledge of unrelated infrastructure.

Avoid classes that simultaneously perform HTTP handling, SQL construction, validation, authorization, business rules, file I/O, e-mail delivery, rendering, and logging.

A class should not become a generic container for unrelated utility methods merely because those methods are used by the same screen or module.

Do not introduce object-oriented abstractions when a small, local procedural change is safer and more consistent with the legacy module. Modernization must reduce complexity, not relocate it.

---

# 7. Encapsulation and Invariants

Business invariants should be enforced as close as practical to the code that owns the affected state.

Prefer behavior that expresses the domain:

```php
$document->approve($approvedBy);
```

over unrestricted state mutation such as:

```php
$document->status = 'approved';
```

when the operation has business rules that must always be preserved.

Objects should not expose mutable internal state unnecessarily.

When a value must always satisfy a rule, prefer construction or factory methods that reject invalid states instead of allowing invalid instances to circulate through the application.

UI restrictions are not invariants. A hidden or disabled control never replaces server-side enforcement.

---

# 8. SOLID Principles

SOLID is a design guide, not a requirement to create abstractions for every class.

### Single Responsibility Principle

A class or module should have one primary reason to change. Split responsibilities when they evolve independently or make testing, security, or comprehension materially harder.

### Open/Closed Principle

Prefer extension through stable seams when variation is expected. Do not create speculative extension points for hypothetical future requirements.

### Liskov Substitution Principle

Implementations must preserve the behavioral expectations of the contracts they implement or extend.

### Interface Segregation Principle

Prefer small, role-specific contracts over broad interfaces that force consumers to depend on methods they do not use.

### Dependency Inversion Principle

High-level business behavior should not depend unnecessarily on low-level infrastructure details. Introduce contracts when they isolate meaningful volatility, improve testability, or protect domain/application code from infrastructure coupling.

SOLID must not be used as justification for unnecessary class proliferation in simple or legacy flows.

---

# 9. Composition, Inheritance, Interfaces, and Contracts

Prefer composition over inheritance when behavior can be assembled from collaborators.

Use inheritance only when the subtype genuinely preserves an **is-a** relationship and the parent contract is intentionally designed for extension.

Use interfaces when they provide a real boundary, such as:

- interchangeable infrastructure implementations;
- repositories;
- external-service gateways;
- policies;
- strategies;
- test seams.

Do not create one-interface-per-class mechanically.

Public contracts include more than PHP interfaces. They also include:

- public method signatures;
- routes;
- request parameters;
- JSON response shapes;
- session keys;
- template variables;
- database result shapes;
- event payloads;
- filenames and include paths used by legacy code.

Preserve these contracts unless the requested change explicitly requires their evolution and all callers are assessed.

---

# 10. Dependency Injection and Dependency Direction

Dependencies should be explicit whenever practical.

Prefer constructor injection for required collaborators in object-oriented code:

```php
final class UserService
{
    public function __construct(
        private UserRepository $users,
        private AuditLogger $audit,
    ) {
    }
}
```

Avoid creating infrastructure dependencies deep inside business methods when the dependency can be supplied explicitly.

Service locators, globals, static mutable state, and hidden singleton dependencies should not be introduced into new code unless required by an established legacy integration boundary.

Dependency direction should favor business logic depending on stable contracts rather than low-level implementation details.

Do not introduce a dependency injection container merely to modernize a small legacy module. Adopt DI incrementally where it provides concrete value.

---

# 11. Entities, Value Objects, Enums, and Immutable Data

Use the smallest model that accurately expresses the domain.

### Entities

Use entities when identity and lifecycle matter independently from current attribute values.

### Value Objects

Consider Value Objects for values with meaningful validation, behavior, or invariants, such as money, e-mail addresses, document identifiers, percentages, date ranges, or coordinates.

A Value Object should normally be valid from construction onward and should preferably be immutable.

### Enums

Use PHP enums for closed sets of values when they improve correctness and the existing storage/API contract can support them safely.

Do not introduce enums solely to wrap arbitrary database strings when unknown legacy values may exist.

### Readonly and immutability

Use `readonly` for DTOs and value-like objects when mutation is not required. Immutability should reduce accidental state changes, not make simple code harder to use.

---

# 12. DTOs and Data Boundaries

Use DTOs when data crosses a meaningful boundary and a typed contract improves clarity or validation.

Appropriate boundaries include:

- HTTP request to application logic;
- application service to rendering/API response;
- integration payload to internal model;
- command or job input;
- complex repository result consumed by multiple callers.

DTOs must not become a second domain model containing duplicated business rules.

Do not create DTOs for every trivial function call. Arrays remain acceptable for small, local, stable legacy contracts when replacing them would add more complexity than safety.

---

# 13. Application Services, Use Cases, and Domain Services

Significant operations should have an identifiable application-level responsibility.

Examples include creating a user, approving a document, registering a payment, transferring a member, generating a certificate, or closing an accounting period.

Application services or use-case classes may coordinate:

- authorization results;
- domain behavior;
- repositories;
- transactions;
- external services;
- audit events.

They should not absorb presentation concerns such as HTML rendering.

Domain services should be used only when important business behavior does not naturally belong to a single entity or value object.

Do not create `*Service` classes as generic dumping grounds for unrelated methods.

---

# 14. Repository Pattern and Persistence Boundaries

Repositories may be used to separate persistence concerns from business/application behavior when that separation provides real value.

A repository should represent persistence operations meaningful to its consumer rather than expose arbitrary SQL-building capabilities.

Example:

```php
interface UserRepository
{
    public function findById(int $id): ?User;

    public function findByEmail(string $email): ?User;

    public function save(User $user): void;
}
```

Repository abstractions are not mandatory for every table or query.

For small legacy screens, a focused existing data-access class may remain preferable.

Do not create a repository layer that simply mirrors every PDO method without creating a useful boundary.

---

# 15. Design Patterns

Design patterns are reusable solutions to recurring design problems. They are tools, not architectural goals.

Patterns that may be appropriate include:

- Repository;
- Strategy;
- Factory;
- Adapter;
- Facade;
- Command;
- State;
- Observer / Domain Events;
- Specification;
- Decorator;
- Template Method.

Before applying a pattern:

1. identify the concrete design problem;
2. confirm that an existing project solution does not already solve it;
3. prefer the simplest pattern that reduces coupling or clarifies variation;
4. ensure the pattern remains understandable to future maintainers;
5. avoid adding abstractions for hypothetical requirements.

A system is not better because it contains more patterns.

---

# 16. Layered Architecture and Module Boundaries

SISCONIECP is a legacy application and does not require every module to be reorganized into a textbook architecture.

For new modules or material refactorings, prefer separation of concerns equivalent to the following conceptual layers when useful:

```text
Presentation
    ↓
Application
    ↓
Domain

Infrastructure implements or supports boundaries required by the inner layers.
```

Typical responsibilities:

- **Presentation**: HTTP, forms, controllers, views, response formatting.
- **Application**: use-case orchestration and application workflows.
- **Domain**: business rules, invariants, entities, value objects, domain services.
- **Infrastructure**: PDO/MySQL, filesystem, mail, HTTP integrations, cache, external services.

These are conceptual boundaries, not a mandatory directory rewrite.

New code should improve separation of responsibilities inside the existing module architecture. Structural reorganization must be justified by the requested scope, risk, and long-term benefit.

---

# 17. Database Connection

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

# 18. Production Database Environment

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

# 19. Database Schema Sources

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

# 20. MySQL 5.7 Compatibility

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

# 21. SQL Mode Considerations

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

# 22. Charset and Unicode

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

# 23. SQL Query Quality

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

# 24. GROUP BY and Aggregations

New and modified aggregate queries must be deterministic.

Do not rely on the permissive production SQL mode.

Avoid queries that select nonaggregated fields without appropriate grouping.

Every selected field in an aggregate query must be:

- part of `GROUP BY`;
- aggregated;
- or validly functionally dependent in MySQL 5.7.

Queries should remain correct even if stricter SQL modes are adopted in the future.

---

# 25. Storage Engines

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

# 26. Transactions

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

# 27. SQL Injection Prevention

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

# 28. Input Validation

Validate all external input on the server.

Prefer validation at clear application boundaries and reuse established validators or request-validation mechanisms instead of scattering incompatible validation rules across endpoints. Domain invariants must still be enforced by the code that owns the invariant.

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

# 29. Output Encoding and XSS

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

# 30. CSRF

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

# 31. Authentication and Authorization

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

# 32. RBAC, Policies, and Resource Authorization

Role-based access control may be used where existing project roles map naturally to permissions, but authorization must not rely only on role names when the operation also depends on ownership, institution, tenant, status, or resource context.

Prefer centralized policy-style checks for sensitive resource operations when this can be integrated without duplicating the existing permission system.

Authorization should answer both:

- whether the user has the capability to perform the type of action;
- whether the user may perform it on the specific resource being targeted.

Deny by default for privileged actions.

Server-side permission checks remain authoritative. Client-side visibility exists only for UX.

---

# 33. Password Security

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

# 34. Sessions

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

# 35. Error Handling

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

# 36. File Upload Security

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

# 37. Content Security Policy

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

# 38. JavaScript Security

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

# 39. No Inline JavaScript

Do not introduce inline `<script>` blocks inside PHP or HTML templates.

JavaScript must live in external files.

Avoid mixing JavaScript implementation directly into PHP templates.

PHP may expose data using safe structured mechanisms such as:

- `data-*` attributes;
- JSON encoded safely;
- dedicated endpoints.

Use secure JSON encoding when transferring PHP data to JavaScript.

---

# 40. Modern JavaScript

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

# 41. UI Consistency

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

# 42. Responsive Design

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

# 43. Accessibility

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

# 44. Forms

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

# 45. Tables

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

# 46. User Feedback States

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

# 47. SCSS and CSS

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

# 48. CSS Quality

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

# 49. Dependency Management

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

# 50. Composer and PHP Dependencies

Before relying on a package API, verify the installed version.

Do not assume current online documentation matches the project's installed dependency.

Important examples include:

- mPDF;
- HTMLPurifier;
- PHPUnit;
- Composer packages related to security.

Use the API supported by the installed project version.

---

# 51. Secrets and Configuration Management

Secrets must not be stored in source code.

Use environment-specific protected configuration or an approved secrets mechanism for:

- database credentials;
- API keys;
- encryption keys;
- private keys;
- access tokens;
- third-party credentials.

Local secret files such as `.env` must remain excluded from version control. Example configuration files may be versioned only with non-secret placeholders.

Production and development configuration must remain separable without editing application source code.

Do not expose secrets through exception messages, HTML, JavaScript bundles, URLs, logs, generated documentation, shell history, or committed fixtures.

---

# 52. Performance

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

Production PHP should use OPcache when supported by the hosting environment and when its configuration can be managed safely. Do not hard-code environment-specific OPcache assumptions into application logic.

---

# 53. Financial and Accounting Data

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

# 54. Church Accounting

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

# 55. Legacy Behavior

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

# 56. Security Modernization

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

# 57. Avoid Security Theater

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

# 58. Business Rules

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

# 59. Validation Requirements

Every changed PHP file should be syntax checked as part of the applicable quality gate.

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

# 60. Regression Checklist

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

# 61. Manual Testing

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

# 62. Automated Tests

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

# 63. Static Analysis and Audits

Use available project tooling when applicable.

Possible tools include:

- PHPStan;
- PHPUnit;
- PHPCS when configured;
- PHP-CS-Fixer when configured;
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

For new or modernized PHP tooling, prefer a single authoritative coding-standard workflow based on PSR-12. Do not introduce PHPCS, PHP-CS-Fixer, Prettier PHP, or another formatter in conflicting configurations.

---

# 64. CI/CD and Quality Gates

Automated delivery should prevent known-bad changes from advancing when project infrastructure supports it.

A mature pipeline should evaluate, as applicable:

```text
Composer validation
    ↓
Dependency installation from lock file
    ↓
Coding standards
    ↓
Static analysis
    ↓
Unit tests
    ↓
Integration / endpoint tests
    ↓
Dependency and security audits
    ↓
Build / packaging
    ↓
Deployment
    ↓
Migration step when explicitly planned
    ↓
Health verification
```

Quality gates should block merge or deployment for relevant failures such as syntax errors, failing tests, material static-analysis regressions, broken builds, or unresolved critical security findings.

Do not invent pipeline commands that are not configured in the repository.

For legacy areas without full automation, improve coverage incrementally rather than pretending the gate exists.

---

# 65. Documentation

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

# 66. Database Schema Maintenance

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

# 67. Sensitive Data

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

# 68. Logging

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

# 69. Database Migrations

Database schema changes must be versioned and planned deliberately.

Before designing migration SQL:

1. confirm the production database version;
2. inspect the affected table engine;
3. inspect current indexes and constraints;
4. inspect data types and nullability;
5. inspect affected application code and legacy contracts;
6. consider rollback and forward-fix strategies;
7. consider lock duration and downtime;
8. consider data conversion and backfill requirements;
9. confirm Percona Server 5.7 / MySQL 5.7 compatibility.

Migration SQL must remain compatible with Percona Server 5.7.44-48 unless the production environment is formally upgraded.

Destructive migration steps require explicit deployment planning, backup considerations, and a verified recovery strategy.

Do not rely on MySQL 5.7 `CHECK` constraints for critical business validation.

---

# 70. Production Safety

Production must not be used as a routine development or exploratory test environment.

The preferred engineering workflow is:

1. inspect the versioned production schema and environment contract;
2. develop locally;
3. validate MySQL 5.7 / Percona compatibility;
4. test locally or in an approved non-production environment;
5. review the final diff and migration plan;
6. deploy through the approved process;
7. verify application health and critical flows after deployment.

Production changes must be deliberate, traceable, and recoverable.

---

# 71. Backups, Restore, Deployment, and Rollback

Production-impacting changes must consider recoverability.

For data and schema changes, define when applicable:

- what must be backed up;
- backup timing;
- retention;
- restore procedure;
- expected RPO and RTO for critical data;
- migration rollback or forward-fix strategy;
- application rollback strategy;
- compatibility between old and new application versions during deployment.

A backup is not considered reliable solely because a backup file exists. Restore procedures for important systems should be tested periodically through an approved operational process.

Prefer backward-compatible database evolution for risky deployments. When practical, use an expand → migrate → contract approach instead of destructive one-step schema changes.

Never assume a down migration can recover data removed by a destructive migration.

---

# 72. External Libraries and CDN Resources

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

# 73. TinyMCE and Rich Text

When modifying flows that use TinyMCE:

- inspect the project's installed TinyMCE version;
- preserve existing configuration when possible;
- do not trust HTML solely because it came from TinyMCE;
- sanitize rich content on the server according to project policy;
- preserve CSP compatibility;
- avoid inline initialization when external JavaScript can be used.

Do not introduce a second rich-text editor without a specific requirement.

---

# 74. PDF Generation

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

# 75. Definition of Done

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

# 76. Core Principle

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

---

# 77. Mandatory OWASP Security Baseline

All new or modified code must be evaluated against the risks applicable to its execution path.

The current project baseline is **OWASP Top 10:2025**:

1. A01:2025 — Broken Access Control
2. A02:2025 — Security Misconfiguration
3. A03:2025 — Software Supply Chain Failures
4. A04:2025 — Cryptographic Failures
5. A05:2025 — Injection
6. A06:2025 — Insecure Design
7. A07:2025 — Authentication Failures
8. A08:2025 — Software or Data Integrity Failures
9. A09:2025 — Security Logging and Alerting Failures
10. A10:2025 — Mishandling of Exceptional Conditions

Project security review must additionally consider, when applicable:

- Cross-Site Scripting (XSS);
- SQL Injection;
- Cross-Site Request Forgery (CSRF);
- Insecure Direct Object Reference (IDOR);
- Mass Assignment;
- Path Traversal;
- unsafe file upload;
- Open Redirect;
- insecure CORS configuration;
- session fixation and session hijacking;
- horizontal and vertical privilege escalation;
- SSRF and unsafe outbound requests;
- sensitive data exposure;
- dependency and build-chain integrity;
- exceptional conditions that can leave partial, inconsistent, or fail-open state.

This section does not replace the detailed controls in this document. It makes their review mandatory whenever the corresponding risk is applicable.

Security-sensitive work is not complete merely because the normal functional path works.

Security failures should fail closed whenever practical.

---

# 78. OWASP Top 10 Proactive Controls

Whenever technically applicable and compatible with the repository architecture, implementations must follow the OWASP Top 10 Proactive Controls:

1. C1: Implement Access Control

   https://top10proactive.owasp.org/the-top-10/c1-accesscontrol/

2. C2: Use Cryptography to Protect Data

   https://top10proactive.owasp.org/the-top-10/c2-crypto/

3. C3: Validate all Input & Handle Exceptions

   https://top10proactive.owasp.org/the-top-10/c3-validate-input-and-handle-exceptions/

4. C4: Address Security from the Start

   https://top10proactive.owasp.org/the-top-10/c4-secure-architecture/

5. C5: Secure By Default Configurations

   https://top10proactive.owasp.org/the-top-10/c5-secure-by-default/

6. C6: Keep your Components Secure

   https://top10proactive.owasp.org/the-top-10/c6-use-secure-dependencies/

7. C7: Secure Digital Identities

   https://top10proactive.owasp.org/the-top-10/c7-secure-digital-identities/

8. C8: Leverage Browser Security Features

   https://top10proactive.owasp.org/the-top-10/c8-leverage-browser-security-features/

9. C9: Implement Security Logging and Monitoring

   https://top10proactive.owasp.org/the-top-10/c9-security-logging-and-monitoring/

10. C10: Stop Server Side Request Forgery

    https://top10proactive.owasp.org/the-top-10/c10-stop-server-side-request-forgery/

Reference:

https://top10proactive.owasp.org/the-top-10/

These controls must be applied proportionally to the affected functionality.

The agent must prefer an existing secure repository implementation over introducing a parallel implementation solely to satisfy a control differently.

When a proactive control is relevant but cannot be applied because of a confirmed legacy, runtime, compatibility, or architectural constraint, the agent must:

1. preserve existing security;
2. avoid introducing a weaker workaround;
3. document the limitation accurately;
4. recommend the smallest compatible mitigation when appropriate.

---

# 79. Cryptography and Sensitive Data Protection

Cryptographic protection must use established, maintained platform or library primitives.

Never implement custom cryptographic algorithms or proprietary password protection mechanisms.

When cryptography is required:

- use algorithms and APIs appropriate for the data and threat model;
- use cryptographically secure randomness for security-sensitive tokens;
- do not use predictable identifiers as security tokens;
- do not hard-code encryption keys;
- do not store keys beside encrypted data when that defeats the protection model;
- keep secrets out of source code, logs, URLs, frontend bundles, HTML, and client-visible configuration;
- use authenticated encryption when application-level encryption is required and supported by the approved project stack;
- use constant-time or platform-provided verification mechanisms for secrets when applicable;
- preserve key rotation capability when designing new encrypted storage.

For password storage, the password rules already defined in this document remain authoritative.

For data in transit:

- prefer HTTPS for authenticated or sensitive traffic;
- never deliberately downgrade secure transport;
- do not disable TLS certificate verification to make integrations work;
- do not accept insecure TLS configuration merely as a development shortcut.

For sensitive data:

- collect only what is necessary;
- return only what the current user and operation require;
- avoid exposing complete sensitive identifiers where partial masking is sufficient;
- avoid placing sensitive values in query strings;
- avoid copying sensitive values unnecessarily across session, DOM, JavaScript, logs, temporary files, exports, or caches.

Encryption does not replace access control.

Hashing does not replace encryption where recovery of the original value is required.

Encoding such as Base64 is not encryption.

---

# 80. Server-Side Request Forgery and Outbound Requests

Any functionality that causes the server to access a URL, hostname, IP address, webhook, remote file, external API, callback, image, document, or other network resource must be reviewed for SSRF.

When the destination is influenced directly or indirectly by user-controlled data:

- prefer explicit allowlists of permitted hosts or services;
- restrict allowed schemes, normally to https when appropriate;
- reject unexpected URL schemes;
- prevent access to localhost and loopback destinations unless explicitly required;
- prevent access to private, link-local, reserved, multicast, and internal network ranges unless explicitly required by the business rule;
- protect cloud or infrastructure metadata endpoints;
- validate redirects and do not assume the original host remains the final destination;
- set connection and response timeouts;
- define reasonable response-size limits;
- avoid forwarding arbitrary authentication headers or internal credentials;
- do not return raw internal network errors to the user;
- validate the expected content type when downloading remote resources;
- avoid using user-controlled URLs directly in shell commands.

When feasible, perform validation after DNS resolution and account for DNS rebinding risks.

Do not implement SSRF protection using only string-prefix checks.

Outbound requests must follow the least-privilege principle.

---

# 81. Secure-by-Default Configuration and Browser Security

New security-relevant configuration must be secure by default.

Prefer:

- deny by default;
- least privilege;
- explicit enablement of optional privileged features;
- restrictive CORS;
- secure cookie attributes;
- centralized security headers;
- minimal exposure of server and framework information;
- disabled debug output in production;
- disabled directory listing when not intentionally required;
- explicit upload and request limits;
- explicit timeout limits for external operations.

When the project architecture supports them, review the applicability and consistency of:

- Content-Security-Policy;
- Strict-Transport-Security;
- X-Content-Type-Options: nosniff;
- Referrer-Policy;
- Permissions-Policy;
- framing protection through CSP frame-ancestors or an existing compatible mechanism;
- cookies using Secure;
- cookies using HttpOnly;
- an appropriate SameSite policy.

Do not add duplicate or conflicting security headers.

Reuse the project's centralized security-header implementation.

CORS must never be opened indiscriminately merely to resolve a frontend integration problem.

Do not combine credentialed cross-origin access with unrestricted origins.

Existing rules prohibiting unsafe-inline, unsafe-eval, inline event handlers, inline JavaScript, and inline styles remain mandatory.

---

# 82. Secure Design and Threat-Oriented Review

For new features or material changes to authentication, authorization, financial flows, uploads, integrations, administrative functions, personal data, or other sensitive workflows, evaluate abuse cases before implementation.

At minimum consider:

- who can invoke the action;
- which resource can be targeted;
- whether ownership must be verified;
- whether an identifier can be changed manually;
- whether the operation can be repeated;
- whether the operation can be reordered;
- whether a lower-privileged user can reach a higher-privileged action;
- whether business limits can be bypassed by direct requests;
- whether a partially completed operation leaves inconsistent state;
- whether concurrency creates duplication or race conditions;
- whether an attacker can force the server to access an unintended resource;
- whether sensitive information can be inferred from error messages or response differences.

Do not rely on obscurity, hidden UI controls, unpredictable URLs, sequential IDs, or undocumented frontend behavior as security controls.

When security depends on a business invariant, enforce that invariant on the server.

Where a destructive, financial, permission-related, or otherwise critical action can be retried, evaluate idempotency and duplicate-submission protections.

---

# 83. Software and Data Integrity

The application must protect the integrity of code, dependencies, configuration, updates, imported data, and security-sensitive state.

Do not:

- execute code obtained from untrusted input;
- dynamically include PHP files from untrusted paths;
- evaluate user-controlled expressions;
- deserialize untrusted PHP objects using unsafe mechanisms;
- trust client-provided totals, permissions, roles, prices, balances, ownership, or other authoritative business values;
- trust hidden form fields as authoritative security state;
- silently accept tampered security-sensitive payloads.

For security-sensitive values, derive authoritative data from trusted server-side sources whenever possible.

When using external packages, scripts, assets, or update mechanisms:

- use pinned or controlled versions where appropriate;
- preserve lock-file integrity;
- review unexpected dependency changes;
- use Subresource Integrity for external browser resources when applicable and compatible;
- do not bypass package integrity checks merely to make installation succeed.

When importing structured data:

- validate schema, type, size, allowed values, ownership, and relationships before persistence;
- reject malformed or unexpected fields when they create security or integrity risk;
- do not permit mass assignment of sensitive fields.

Integrity validation must occur before a critical side effect whenever practical.

---

# 84. Security Logging, Monitoring, and Audit Events

The general logging rules in this document remain authoritative.

In addition, security-sensitive flows must evaluate whether auditable security events are required.

Relevant events may include:

- successful and failed authentication attempts;
- logout and session invalidation;
- password or credential changes;
- password recovery events;
- authorization failures;
- attempts to access resources owned by another user or tenant;
- permission and role changes;
- administrative actions;
- account activation, deactivation, blocking, or unlocking;
- security configuration changes;
- relevant CSRF validation failures;
- suspicious upload rejection;
- repeated input validation failures suggesting attack traffic;
- integrity validation failures;
- SSRF destination rejection;
- high-impact financial or destructive operations.

Security logs should contain enough context for investigation without exposing secrets or unnecessary personal data.

Where practical, include:

- event type;
- date and time;
- authenticated internal user identifier when safe;
- affected internal resource identifier when safe;
- result or status;
- source context appropriate to the project's privacy policy;
- correlation or request identifier when the project already supports it.

Do not log complete passwords, authentication tokens, session IDs, private keys, API secrets, or sensitive payloads.

Do not create noisy logs for every harmless validation error.

Logging must be useful for detection and investigation.

A security control that exists only in logs does not replace prevention.

---

# 85. Extended Security Validation Checklist

Before considering a security-relevant task complete, evaluate the following items when applicable:

- access control is enforced server-side;
- resource ownership or tenant boundaries are validated;
- external input is allowlisted or strictly validated;
- output is encoded according to rendering context;
- SQL values are parameterized;
- dynamic SQL identifiers use explicit allowlists;
- CSRF protection remains effective for state-changing requests;
- authentication and session controls were not weakened;
- sensitive data exposure is minimized;
- secrets are not present in source, output, logs, or URLs;
- cryptographic APIs are established and appropriate;
- external requests are protected against SSRF;
- CORS remains restrictive;
- CSP remains restrictive;
- neither script-src 'unsafe-inline' nor style-src 'unsafe-inline' was introduced;
- unsafe-eval was not introduced;
- no inline JavaScript event handlers were introduced;
- no inline JavaScript blocks were introduced;
- no inline styles were introduced;
- dependencies introduced or modified are justified and compatible;
- software and data integrity risks were considered;
- security-sensitive events are auditable when required;
- error responses do not expose internal details;
- uploaded or imported content is validated;
- destructive or high-impact operations fail safely;
- applicable OWASP Proactive Controls were considered.

Do not claim that every item was tested when only a subset was applicable or executable.

Report only validations that actually occurred.

---

# 86. Security Priority Rule

When multiple technically valid solutions exist, prefer the solution that:

1. preserves or strengthens existing security;
2. follows the repository's established secure abstractions;
3. applies the relevant OWASP Proactive Controls;
4. minimizes attack surface;
5. denies unauthorized behavior by default;
6. exposes the minimum necessary data and functionality;
7. remains compatible with PHP 8.5+ and the production MySQL 5.7 / Percona environment;
8. does not require unsafe-inline, unsafe-eval, weakened CSP, unrestricted CORS, disabled TLS verification, or bypassed validation;
9. remains focused and minimally disruptive.

A functional workaround is not acceptable when it requires weakening an existing security control.

Security must be treated as a system property across architecture, backend, frontend, database, dependencies, configuration, logging, and integrations.

---

# 87. Object Design Review Checklist

Before approving a material PHP design or refactoring, evaluate as applicable:

- responsibility is clear and cohesive;
- public and legacy contracts remain understood;
- dependencies are explicit where practical;
- business invariants are enforced server-side;
- composition is preferred over unnecessary inheritance;
- interfaces exist only where they provide a useful boundary;
- Value Objects, enums, or DTOs are used only where they improve correctness or clarity;
- persistence details do not leak unnecessarily into business logic;
- controllers/endpoints do not accumulate unrelated business rules;
- no God Object or generic `*Service` dumping ground was introduced;
- a design pattern solves a concrete recurring problem rather than adding ceremony;
- the design follows existing module conventions when those conventions are secure and adequate;
- modernization is incremental and does not create an isolated parallel architecture;
- security, authorization, validation, transactions, failure behavior, and auditability were considered;
- the solution remains compatible with PHP 8.5+ and production MySQL 5.7 / Percona constraints;
- tests and static analysis are proportionate to the risk of the change;
- the resulting code is easier to understand and change than the code it replaces.

The preferred solution is the simplest design that preserves correctness, security, compatibility, testability, and long-term maintainability.
