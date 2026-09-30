# Portão pré-deploy — Plano 1/4: Fundação, validação de segurança (unit) e runner

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar `php tests/gate.php --fast` funcionando: lint dos PHP alterados, suíte PHPUnit `unit` com as classes de segurança e scripts legados de `tests/`, com relatório em `tests/out/gate-report.md` e lista de falhas conhecidas.

**Architecture:** PHPUnit 13 (já em `vendor/bin`) com `phpunit.xml` na raiz e suíte `unit`. Código de apoio em `tests/Support/` sob o namespace `Tests\Support`, carregado por um autoloader próprio em `tests/bootstrap.php` (sem mexer no `composer.json`/`vendor`, que sobem para produção). `tests/gate.php` monta uma lista de etapas (`Etapa`) e um `Runner` executa cada uma isolada, coleta `Resultado`s, cruza falhas com `tests/allowlist.php` e gera o relatório. Planos 2–4 só acrescentam etapas.

**Tech Stack:** PHP 8.4 CLI, PHPUnit 13.2, HTMLPurifier (já no vendor), ext-sodium, ext-dom, ext-simplexml, `proc_open`.

**Spec:** `docs/superpowers/specs/2026-09-30-testes-seguranca-integridade-design.md`

**Planos da série:** 1 (este) → 2 contas de teste + ataque HTTP → 3 integridade → 4 Playwright. Cada plano deixa o portão funcionando com as etapas que já existem.

**Branch:** criar `testes/portao-1-fundacao` a partir de `main` antes da Task 1.

## Global Constraints

- PHP 8.4 CLI; todo arquivo novo começa com `<?php` + `declare(strict_types=1);`.
- Nenhuma dependência nova no `composer.json`; não rodar `composer dump-autoload` (o `vendor/` sobe manualmente para o HostGator).
- Nenhum arquivo fora de `tests/`, `phpunit.xml` e `.gitignore` é criado ou alterado. **Código de produção (`classes/`, módulos) não é corrigido neste plano**: teste que reprova por defeito real vira entrada em `tests/allowlist.php` com `motivo` e `desde`, e é relatado ao humano.
- Todo host HTTP usado por testes deve ser `localhost` ou `127.0.0.1` (spec §1, critérios de sucesso).
- Códigos de saída do `gate.php`: `0` passou, `1` reprovação, `2` pré-requisito ausente (spec §9).
- `php tests/gate.php --fast` não exige Apache nem `tests/.env.local` (spec §3).
- Scripts legados: exit `0` passou, exit `2` = pulado com aviso (convenção existente de "ambiente não configurado"), qualquer outro = reprovação (spec §3, etapa 4).
- Scripts legados são descobertos por nome `*_test.php`, `*_test.js`, `*_test.py` dentro de `tests/`, fora de `Unit/`, `Http/`, `Integrity/`, `e2e/`, `Support/`, `out/`.
- Arquivos PHP em `tests/` que não são testes PHPUnit respondem 404 fora do CLI; `tests/.htaccess` nega acesso web.
- Comandos git seguem o `CLAUDE.md` do projeto: prefixo `rtk` (ex.: `rtk git add`). Dentro do submódulo `docs/` use `git` puro — o `rtk git add` falhou ali com `pathspec did not match`.
- Mensagens de commit terminam com `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. `GATE_BASE_URL` disfarçado (`http://localhost.evil.example`, `http://127.0.0.1@evil.example`, `https://evil.example/localhost`) → recusado com mensagem clara. Teste em Task 1 (`EnvTest::testRecusaHostNaoLocal`).
2. `.env.local` salvo no Windows com CRLF, valores entre aspas ou contendo `=` (o DSN) → lido corretamente. Teste em Task 1 (`EnvTest::testLeCrlfAspasEIgualNoValor`).
3. Script legado travado (ex.: esperando lock do MySQL) → morto por timeout, reportado como reprovação e o portão continua. Teste em Task 7 (`ProcessoTest::testTimeoutMataProcesso`).
4. PHPUnit sai com código ≠ 0 sem nenhuma falha no JUnit (warning, deprecation, fatal antes do log) → etapa reprova, nunca passa em silêncio. Teste em Task 8 (`EtapaPhpUnitTest::testCodigoNaoZeroSemFalhaReprova`).
5. Entrada da allowlist malformada ou obsoleta (teste já corrigido continua listado) → erro explícito ao carregar / listada como "sem uso" no relatório. Testes em Task 6 (`AllowlistTest::testEntradaSemMotivoFalha`) e Task 7 (`RelatorioTest::testListaEntradasSemUso`).

---

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `phpunit.xml` | suíte `unit`; planos seguintes acrescentam `http`, `integrity-read`, `integrity-write` |
| `tests/.htaccess` | nega acesso web à pasta |
| `tests/.env.example` | modelo das variáveis do portão |
| `tests/bootstrap.php` | autoload do Composer + autoloader `Tests\` → `tests/` |
| `tests/Unit/bootstrap.php` | sessão CLI em `tests/out/sessoes` e carga de `StartSecureSession.php` antes de qualquer saída |
| `tests/allowlist.php` | dados: falhas conhecidas (e, no Plano 2, endpoints públicos) |
| `tests/Support/Env.php` | leitura de `tests/.env.local`, validação de host local |
| `tests/Support/Payloads.php` | payloads XSS/SQLi compartilhados + detector DOM de HTML perigoso |
| `tests/Support/Allowlist.php` | carrega e consulta `tests/allowlist.php` |
| `tests/Support/JunitReader.php` | converte JUnit do PHPUnit em lista de casos com id estável |
| `tests/Support/Gate/Falha.php`, `Resultado.php`, `Etapa.php` | tipos do runner |
| `tests/Support/Gate/Processo.php` | `proc_open` com timeout, saída capturada em arquivo |
| `tests/Support/Gate/Runner.php` | executa etapas isoladas, calcula código de saída |
| `tests/Support/Gate/Relatorio.php` | resumo de terminal e `gate-report.md` |
| `tests/Support/Gate/EtapaPreflight.php`, `EtapaLint.php`, `EtapaPhpUnit.php`, `EtapaLegado.php` | etapas deste plano |
| `tests/gate.php` | ponto de entrada CLI |
| `tests/Unit/Support/*Test.php` | testes do próprio portão |
| `tests/Unit/Security/*Test.php` | classes de segurança |
| `tests/Unit/Validacao/*Test.php` | CPF, CNPJ, ocultação de CPF |

Nota de nome: o spec cita `tests/Support/allowlist.php`. No Windows `allowlist.php` e `Allowlist.php` na mesma pasta são o mesmo arquivo, então os dados ficam em `tests/allowlist.php` e a classe em `tests/Support/Allowlist.php`.

---

### Task 1: Esqueleto PHPUnit e leitura do ambiente de teste

**Files:**
- Create: `phpunit.xml`
- Create: `tests/.htaccess`
- Create: `tests/.env.example`
- Create: `tests/bootstrap.php`
- Create: `tests/Unit/bootstrap.php`
- Create: `tests/Support/Env.php`
- Modify: `.gitignore` (acrescentar ao final)
- Test: `tests/Unit/Support/EnvTest.php`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `Tests\Support\Env::carregar(string $arquivo): Env` (lança `RuntimeException` se o arquivo não existe)
  - `Tests\Support\Env::deTexto(string $texto): Env`
  - `Tests\Support\Env::vazio(): Env`
  - `Env->get(string $chave): ?string` (string vazia vira `null`)
  - `Env->exigir(string $chave): string` (lança `RuntimeException` com o nome da chave)
  - `Env->todos(): array<string,string>`
  - `Env->baseUrl(): string` (sem `/` final; valida host)
  - `Tests\Support\Env::garantirHostLocal(string $url): void` (lança `RuntimeException`)
  - Constante `SISCONIECP_RAIZ` (raiz do projeto) definida em `tests/bootstrap.php`

- [ ] **Step 1: Criar branch**

```bash
rtk git switch -c testes/portao-1-fundacao
```

- [ ] **Step 2: Criar `phpunit.xml`, bootstraps, `.htaccess`, `.env.example` e `.gitignore`**

`phpunit.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="tests/bootstrap.php"
         cacheDirectory="tests/out/.phpunit.cache"
         colors="true"
         failOnWarning="true"
         failOnRisky="true"
         displayDetailsOnTestsThatTriggerWarnings="true"
         displayDetailsOnTestsThatTriggerDeprecations="true">
    <testsuites>
        <testsuite name="unit" bootstrap="tests/Unit/bootstrap.php">
            <directory>tests/Unit</directory>
        </testsuite>
    </testsuites>
</phpunit>
```

`tests/bootstrap.php`:

```php
<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

if (!defined('SISCONIECP_RAIZ')) {
    define('SISCONIECP_RAIZ', dirname(__DIR__));
}

require_once SISCONIECP_RAIZ . '/vendor/autoload.php';

// Autoloader próprio do portão: Tests\X\Y → tests/X/Y.php.
// Fica fora do composer.json porque o vendor/ sobe para produção.
spl_autoload_register(static function (string $classe): void {
    if (!str_starts_with($classe, 'Tests\\')) {
        return;
    }
    $arquivo = __DIR__ . '/' . str_replace('\\', '/', substr($classe, 6)) . '.php';
    if (is_file($arquivo)) {
        require_once $arquivo;
    }
});
```

`tests/Unit/bootstrap.php`:

```php
<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

// StartSecureSession.php chama session_start() ao ser incluído; precisa
// acontecer antes de qualquer saída do PHPUnit e longe da pasta de sessões real.
$sessoes = dirname(__DIR__) . '/out/sessoes';
if (!is_dir($sessoes)) {
    mkdir($sessoes, 0777, true);
}
ini_set('session.save_path', $sessoes);

require_once dirname(__DIR__, 2) . '/classes/StartSecureSession.php';
```

`tests/.htaccess`:

```apache
# Testes nunca são servidos pelo Apache.
Require all denied
```

`tests/.env.example`:

```dotenv
# Copie para tests/.env.local e preencha. Nunca versionar o .env.local.
# Host obrigatoriamente localhost ou 127.0.0.1.
GATE_BASE_URL=http://localhost/sisconiecp2

# Banco local (cópia de trabalho). Usuário de leitura: somente SELECT.
GATE_LOCAL_DSN=mysql:host=localhost;dbname=conie847_sisconiecp;charset=utf8mb4
GATE_LOCAL_READ_USER=gate_leitura
GATE_LOCAL_READ_PASSWORD=

# Usuário de escrita usado apenas pelas contas de teste (Plano 2).
GATE_LOCAL_WRITE_USER=gate_escrita
GATE_LOCAL_WRITE_PASSWORD=

# Banco descartável dos testes de escrita (mesma convenção de tests/portaria/README.md).
SISCONIECP_TEST_DSN=mysql:host=localhost;dbname=sisconiecp_test;charset=utf8mb4
SISCONIECP_TEST_DB_USER=
SISCONIECP_TEST_DB_PASSWORD=
```

Acrescentar ao final de `.gitignore` (a pasta `tests/out/` já é ignorada pela regra `out/` existente):

```gitignore

# Portão de testes
tests/.env.local
```

- [ ] **Step 3: Escrever o teste que falha**

`tests/Unit/Support/EnvTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Env;

final class EnvTest extends TestCase
{
    public function testLeChavesIgnorandoComentariosELinhasVazias(): void
    {
        $env = Env::deTexto("# comentário\n\nA=1\nB = dois \n  # outro\nSEM_IGUAL\n");

        $this->assertSame('1', $env->get('A'));
        $this->assertSame('dois', $env->get('B'));
        $this->assertNull($env->get('SEM_IGUAL'));
        $this->assertSame(['A' => '1', 'B' => 'dois'], $env->todos());
    }

    public function testLeCrlfAspasEIgualNoValor(): void
    {
        $texto = "GATE_LOCAL_DSN=mysql:host=localhost;dbname=x;charset=utf8mb4\r\n"
            . "SENHA=\"com espaço = e igual\"\r\n"
            . "OUTRA='simples'\r\n";

        $env = Env::deTexto($texto);

        $this->assertSame('mysql:host=localhost;dbname=x;charset=utf8mb4', $env->get('GATE_LOCAL_DSN'));
        $this->assertSame('com espaço = e igual', $env->get('SENHA'));
        $this->assertSame('simples', $env->get('OUTRA'));
    }

    public function testValorVazioViraNulo(): void
    {
        $env = Env::deTexto("VAZIA=\n");

        $this->assertNull($env->get('VAZIA'));
    }

    public function testExigirFalhaComNomeDaChave(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('GATE_LOCAL_READ_USER');

        Env::vazio()->exigir('GATE_LOCAL_READ_USER');
    }

    public function testCarregarArquivoInexistenteFalha(): void
    {
        $this->expectException(RuntimeException::class);

        Env::carregar(sys_get_temp_dir() . '/nao-existe-' . bin2hex(random_bytes(4)) . '.env');
    }

    public function testCarregarArquivoReal(): void
    {
        $arquivo = tempnam(sys_get_temp_dir(), 'env');
        file_put_contents($arquivo, "X=42\n");
        try {
            $this->assertSame('42', Env::carregar($arquivo)->get('X'));
        } finally {
            unlink($arquivo);
        }
    }

    public static function hostsLocais(): array
    {
        return [
            'localhost' => ['http://localhost/sisconiecp2', 'http://localhost/sisconiecp2'],
            'localhost com barra' => ['http://localhost/sisconiecp2/', 'http://localhost/sisconiecp2'],
            'ip local com porta' => ['http://127.0.0.1:8080/app', 'http://127.0.0.1:8080/app'],
            'maiusculas' => ['http://LOCALHOST/app', 'http://LOCALHOST/app'],
        ];
    }

    #[DataProvider('hostsLocais')]
    public function testAceitaHostLocal(string $url, string $esperado): void
    {
        $env = Env::deTexto('GATE_BASE_URL=' . $url);

        $this->assertSame($esperado, $env->baseUrl());
    }

    public static function hostsNaoLocais(): array
    {
        return [
            'producao' => ['https://swga.coniecp.com.br'],
            'subdominio disfarçado' => ['http://localhost.evil.example/'],
            'userinfo disfarçado' => ['http://127.0.0.1@evil.example/'],
            'localhost no caminho' => ['https://evil.example/localhost'],
            'sem esquema' => ['localhost/sisconiecp2'],
            'vazio' => [''],
        ];
    }

    #[DataProvider('hostsNaoLocais')]
    public function testRecusaHostNaoLocal(string $url): void
    {
        $this->expectException(RuntimeException::class);

        Env::deTexto('GATE_BASE_URL=' . $url)->baseUrl();
    }
}
```

- [ ] **Step 4: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter EnvTest`
Expected: erro `Class "Tests\Support\Env" not found`.

- [ ] **Step 5: Implementar `tests/Support/Env.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support;

use RuntimeException;

/**
 * Variáveis do portão lidas de tests/.env.local.
 * Independe de Classes\Env (que lê o .env da aplicação) para que o
 * portão nunca misture credenciais de teste com as do sistema.
 */
final class Env
{
    /** @param array<string, string> $valores */
    private function __construct(private readonly array $valores)
    {
    }

    public static function carregar(string $arquivo): self
    {
        if (!is_file($arquivo)) {
            throw new RuntimeException('Arquivo de ambiente não encontrado: ' . $arquivo);
        }

        return self::deTexto((string) file_get_contents($arquivo));
    }

    public static function vazio(): self
    {
        return new self([]);
    }

    public static function deTexto(string $texto): self
    {
        $valores = [];
        foreach (preg_split('/\R/', $texto) ?: [] as $linha) {
            $linha = trim($linha);
            if ($linha === '' || str_starts_with($linha, '#') || !str_contains($linha, '=')) {
                continue;
            }
            [$chave, $valor] = array_map('trim', explode('=', $linha, 2));
            if (
                strlen($valor) >= 2
                && ($valor[0] === '"' || $valor[0] === "'")
                && $valor[-1] === $valor[0]
            ) {
                $valor = substr($valor, 1, -1);
            }
            $valores[$chave] = $valor;
        }

        return new self($valores);
    }

    public function get(string $chave): ?string
    {
        $valor = $this->valores[$chave] ?? null;

        return ($valor === null || $valor === '') ? null : $valor;
    }

    public function exigir(string $chave): string
    {
        $valor = $this->get($chave);
        if ($valor === null) {
            throw new RuntimeException('Variável obrigatória ausente em tests/.env.local: ' . $chave);
        }

        return $valor;
    }

    /** @return array<string, string> */
    public function todos(): array
    {
        return $this->valores;
    }

    public function baseUrl(): string
    {
        $url = rtrim($this->exigir('GATE_BASE_URL'), '/');
        self::garantirHostLocal($url);

        return $url;
    }

    public static function garantirHostLocal(string $url): void
    {
        $host = strtolower((string) parse_url($url, PHP_URL_HOST));
        if (!in_array($host, ['localhost', '127.0.0.1'], true)) {
            throw new RuntimeException(
                'GATE_BASE_URL deve apontar para localhost ou 127.0.0.1; recebido: '
                . ($host === '' ? '(host vazio)' : $host)
            );
        }
    }
}
```

- [ ] **Step 6: Rodar e confirmar que passa**

Run: `php vendor/bin/phpunit --testsuite unit --filter EnvTest`
Expected: `OK (16 tests, ...)`.

- [ ] **Step 7: Commit**

```bash
rtk git add phpunit.xml .gitignore tests/.htaccess tests/.env.example tests/bootstrap.php tests/Unit/bootstrap.php tests/Support/Env.php tests/Unit/Support/EnvTest.php
rtk git commit -m "test: esqueleto PHPUnit e leitura do ambiente do portão

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Payloads compartilhados e sanitização de HTML

**Files:**
- Create: `tests/Support/Payloads.php`
- Test: `tests/Unit/Support/PayloadsTest.php`
- Test: `tests/Unit/Security/SanitizerTest.php`
- Test: `tests/Unit/Security/PortariaInputValidatorTest.php`

**Interfaces:**
- Consumes: `tests/bootstrap.php` (Task 1).
- Produces:
  - `Tests\Support\Payloads::xss(): array<string,string>` (nome → payload; 31 itens)
  - `Tests\Support\Payloads::sqli(): array<string,string>` (nome → payload; só leitura/tempo)
  - `Tests\Support\Payloads::perigos(string $html): list<string>` (lista vazia = HTML seguro)
  - `Tests\Support\Payloads::comoCasos(array<string,string> $lista): array<string, array{0:string}>` (formato de data provider)

- [ ] **Step 1: Escrever o teste do detector (falha)**

`tests/Unit/Support/PayloadsTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Support\Payloads;

final class PayloadsTest extends TestCase
{
    public static function casosXss(): array
    {
        return Payloads::comoCasos(Payloads::xss());
    }

    #[DataProvider('casosXss')]
    public function testDetectorReconhecePayloadCru(string $payload): void
    {
        $this->assertNotSame([], Payloads::perigos($payload), 'O detector deixou passar: ' . $payload);
    }

    public static function htmlSeguro(): array
    {
        return [
            'paragrafo' => ['<p><strong>Negrito</strong> e <em>itálico</em></p>'],
            'tabela' => ['<table><tbody><tr><td>A</td></tr></tbody></table>'],
            'link https' => ['<a href="https://coniecp.com.br" rel="nofollow">site</a>'],
            'imagem comum' => ['<img src="x" alt="x">'],
            'estilo de cor' => ['<span style="color:#ff0000;">x</span>'],
            'texto que cita onerror' => ['<p>o atributo onerror= é perigoso</p>'],
            'vazio' => [''],
        ];
    }

    #[DataProvider('htmlSeguro')]
    public function testDetectorAceitaHtmlSeguro(string $html): void
    {
        $this->assertSame([], Payloads::perigos($html));
    }

    public function testListasTemTamanhoEsperado(): void
    {
        $this->assertCount(31, Payloads::xss());
        $this->assertGreaterThanOrEqual(10, count(Payloads::sqli()));
    }

    public function testSqliNaoTemComandoDestrutivo(): void
    {
        foreach (Payloads::sqli() as $nome => $payload) {
            $this->assertDoesNotMatchRegularExpression(
                '/\b(DROP|DELETE|UPDATE|INSERT|TRUNCATE|ALTER|CREATE|GRANT)\b/i',
                $payload,
                "Payload SQLi destrutivo proibido pelo spec: {$nome}"
            );
        }
    }
}
```

- [ ] **Step 2: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter PayloadsTest`
Expected: erro `Class "Tests\Support\Payloads" not found`.

- [ ] **Step 3: Implementar `tests/Support/Payloads.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support;

use DOMDocument;
use DOMXPath;

/**
 * Payloads de ataque compartilhados pelas suítes unit, http e e2e.
 * SQLi só com leitura/tempo: o spec proíbe DROP/DELETE/UPDATE.
 */
final class Payloads
{
    private const ELEMENTOS_PROIBIDOS = [
        'script', 'iframe', 'frame', 'object', 'embed', 'svg', 'math', 'form', 'style',
        'meta', 'base', 'link', 'template', 'input', 'button', 'textarea', 'select',
        'video', 'audio', 'source', 'details', 'noscript',
    ];

    private const ATRIBUTOS_URL = ['href', 'src', 'action', 'formaction', 'xlink:href', 'data', 'srcdoc'];

    /** @return array<string, string> */
    public static function xss(): array
    {
        return [
            'script' => '<script>alert(1)</script>',
            'script-caixa-mista' => '<ScRiPt>alert(1)</sCrIpT>',
            'img-onerror' => '<img src=x onerror=alert(1)>',
            'svg-onload' => '<svg onload=alert(1)>',
            'body-onload' => '<body onload=alert(1)>',
            'div-onmouseover' => '<div onmouseover="alert(1)">x</div>',
            'a-javascript' => '<a href="javascript:alert(1)">x</a>',
            'a-javascript-caixa' => '<a href="JaVaScRiPt:alert(1)">x</a>',
            'a-javascript-entidade' => '<a href="&#106;avascript:alert(1)">x</a>',
            'a-javascript-tab' => "<a href=\"java\tscript:alert(1)\">x</a>",
            'iframe' => '<iframe src="//evil.example"></iframe>',
            'object' => '<object data="x.swf"></object>',
            'embed' => '<embed src="x.swf">',
            'form' => '<form action="//evil.example"><input></form>',
            'style-expression' => '<p style="width:expression(alert(1))">x</p>',
            'style-url' => '<span style="background:url(javascript:alert(1))">x</span>',
            'style-tag' => '<style>@import "//evil.example/x.css";</style>',
            'img-data-html' => '<img src="data:text/html;base64,PHNjcmlwdD4=">',
            'math-mxss' => '<math><mtext></mtext><mglyph><style><img src=x onerror=alert(1)>',
            'meta-refresh' => '<meta http-equiv="refresh" content="0;url=javascript:alert(1)">',
            'base-href' => '<base href="//evil.example/">',
            'link-import' => '<link rel="stylesheet" href="//evil.example/x.css">',
            'atributo-quebrado' => '"><script>alert(1)</script>',
            'aspas-simples' => "'><img src=x onerror=alert(1)>",
            'template' => '<template><script>alert(1)</script></template>',
            'details-ontoggle' => '<details open ontoggle=alert(1)>',
            'video-onerror' => '<video><source onerror=alert(1)></video>',
            'input-autofocus' => '<input autofocus onfocus=alert(1)>',
            'noscript-mxss' => '<noscript><p title="</noscript><img src=x onerror=alert(1)>">',
            'comentario' => '<!--<img src="--><img src=x onerror=alert(1)//">',
            'svg-href' => '<svg><a xlink:href="javascript:alert(1)"><text>x</text></a></svg>',
        ];
    }

    /** @return array<string, string> */
    public static function sqli(): array
    {
        return [
            'aspas' => "'",
            'aspas-duplas' => '"',
            'barra-invertida' => "\\'",
            'or-verdadeiro' => "' OR '1'='1",
            'or-comentario' => "' OR 1=1-- -",
            'numerico-or' => '1 OR 1=1',
            'union' => "' UNION SELECT NULL,NULL-- -",
            'order-by' => '1 ORDER BY 99',
            'sleep-texto' => "' AND SLEEP(3)-- -",
            'sleep-numerico' => '1 AND SLEEP(3)',
            'url-codificado' => '%27%20OR%201%3D1--%20-',
        ];
    }

    /**
     * @param array<string, string> $lista
     * @return array<string, array{0: string}>
     */
    public static function comoCasos(array $lista): array
    {
        return array_map(static fn (string $p): array => [$p], $lista);
    }

    /**
     * Analisa o HTML como o navegador faria (DOM) e lista o que executaria código.
     * Texto escapado que apenas cita "onerror=" não é perigo.
     *
     * @return list<string>
     */
    public static function perigos(string $html): array
    {
        if (trim($html) === '') {
            return [];
        }

        $perigos = [];
        if (preg_match('~<\s*(html|head|body)\b~i', $html)) {
            $perigos[] = 'elemento de documento (html/head/body)';
        }

        $dom = new DOMDocument();
        $anterior = libxml_use_internal_errors(true);
        $dom->loadHTML(
            '<?xml encoding="UTF-8"><div id="raiz-gate">' . $html . '</div>',
            LIBXML_NOERROR | LIBXML_NOWARNING
        );
        libxml_clear_errors();
        libxml_use_internal_errors($anterior);

        foreach ((new DOMXPath($dom))->query('//div[@id="raiz-gate"]//*') ?: [] as $elemento) {
            $nome = strtolower($elemento->nodeName);
            if (in_array($nome, self::ELEMENTOS_PROIBIDOS, true)) {
                $perigos[] = "elemento <{$nome}>";
            }
            foreach ($elemento->attributes ?? [] as $atributo) {
                $attr = strtolower($atributo->nodeName);
                $valor = strtolower((string) preg_replace(
                    '/[\s\x00-\x1f]+/',
                    '',
                    html_entity_decode((string) $atributo->nodeValue, ENT_QUOTES | ENT_HTML5, 'UTF-8')
                ));
                if (str_starts_with($attr, 'on')) {
                    $perigos[] = "atributo {$attr} em <{$nome}>";
                }
                if (
                    in_array($attr, self::ATRIBUTOS_URL, true)
                    && preg_match('~^(javascript|vbscript|data:text/html)~', $valor)
                ) {
                    $perigos[] = "URL executável em {$attr} de <{$nome}>";
                }
                if ($attr === 'style' && preg_match('~expression\(|javascript:|url\(~', $valor)) {
                    $perigos[] = "style perigoso em <{$nome}>";
                }
            }
        }

        return $perigos;
    }
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `php vendor/bin/phpunit --testsuite unit --filter PayloadsTest`
Expected: `OK (40 tests, ...)`.

- [ ] **Step 5: Escrever os testes de sanitização**

`tests/Unit/Security/SanitizerTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Classes\Security\Sanitizer;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Support\Payloads;

final class SanitizerTest extends TestCase
{
    public static function casosXss(): array
    {
        return Payloads::comoCasos(Payloads::xss());
    }

    #[DataProvider('casosXss')]
    public function testModoPadraoRemoveCodigoExecutavel(string $payload): void
    {
        $saida = (new Sanitizer())->clean($payload);

        $this->assertSame([], Payloads::perigos($saida), 'Saída: ' . $saida);
    }

    #[DataProvider('casosXss')]
    public function testModoFormatacaoRemoveCodigoExecutavel(string $payload): void
    {
        $saida = (new Sanitizer(null, false, true))->clean($payload);

        $this->assertSame([], Payloads::perigos($saida), 'Saída: ' . $saida);
    }

    #[DataProvider('casosXss')]
    public function testModoBase64RemoveCodigoExecutavel(string $payload): void
    {
        $saida = (new Sanitizer(null, true, false))->clean($payload);

        $this->assertSame([], Payloads::perigos($saida), 'Saída: ' . $saida);
    }

    public static function htmlLegitimo(): array
    {
        return [
            'negrito e italico' => [
                '<p><strong>Negrito</strong> e <em>itálico</em></p>',
                '<p><strong>Negrito</strong> e <em>itálico</em></p>',
            ],
            'lista' => ['<ul><li>um</li><li>dois</li></ul>', '<ul><li>um</li><li>dois</li></ul>'],
            'tabela' => [
                '<table><tbody><tr><td>A</td><td>B</td></tr></tbody></table>',
                '<table><tbody><tr><td>A</td><td>B</td></tr></tbody></table>',
            ],
            'acentos e entidades' => [
                '<p>Ação &amp; coração — “aspas”</p>',
                '<p>Ação &amp; coração — “aspas”</p>',
            ],
            'link externo ganha rel e target' => [
                '<a href="https://coniecp.com.br">site</a>',
                '<a href="https://coniecp.com.br" rel="nofollow noreferrer noopener" target="_blank">site</a>',
            ],
        ];
    }

    #[DataProvider('htmlLegitimo')]
    public function testPreservaHtmlDoTinyMce(string $entrada, string $esperado): void
    {
        $this->assertSame($esperado, (new Sanitizer())->clean($entrada));
    }

    public function testModoFormatacaoPreservaEstiloSeguro(): void
    {
        $saida = (new Sanitizer(null, false, true))
            ->clean('<p style="text-align:center;color:#ff0000">x</p>');

        $this->assertSame('<p style="text-align:center;color:#ff0000;">x</p>', $saida);
    }

    public function testImagemBase64PermitidaQuandoHabilitada(): void
    {
        $img = '<img src="data:image/png;base64,iVBORw0KGgo=" alt="a">';

        $saida = (new Sanitizer(null, true))->clean($img);

        $this->assertStringContainsString('src="data:image/png;base64,iVBORw0KGgo="', $saida);
    }

    public function testEntradaVaziaOuNula(): void
    {
        $sanitizer = new Sanitizer();

        $this->assertSame('', $sanitizer->clean(null));
        $this->assertSame('', $sanitizer->clean("   \n"));
    }

    public function testCleanArrayRecursivo(): void
    {
        $saida = (new Sanitizer())->cleanArray([
            'a' => '<script>x</script><p>ok</p>',
            'b' => ['c' => '<img src=x onerror=alert(1)>'],
            'n' => 5,
        ]);

        $this->assertSame('<p>ok</p>', $saida['a']);
        $this->assertSame([], Payloads::perigos($saida['b']['c']));
        $this->assertSame(5, $saida['n']);
    }
}
```

`tests/Unit/Security/PortariaInputValidatorTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use DomainException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use PortariaInputValidator;
use Tests\Support\Payloads;

final class PortariaInputValidatorTest extends TestCase
{
    public static function setUpBeforeClass(): void
    {
        require_once SISCONIECP_RAIZ . '/classes/PortariaInputValidator.php';
    }

    public static function casosXss(): array
    {
        return Payloads::comoCasos(Payloads::xss());
    }

    #[DataProvider('casosXss')]
    public function testExibicaoRemoveCodigoExecutavel(string $payload): void
    {
        $saida = (new PortariaInputValidator())->sanitizarHtmlParaExibicao($payload);

        $this->assertSame([], Payloads::perigos($saida), 'Saída: ' . $saida);
    }

    public function testSemPurifierEscapaTudo(): void
    {
        $saida = (new PortariaInputValidator(false))->sanitizarHtmlParaExibicao('<b>x</b>');

        $this->assertSame('&lt;b&gt;x&lt;/b&gt;', $saida);
    }

    public function testPreservaCorEmSpan(): void
    {
        $saida = (new PortariaInputValidator())
            ->sanitizarHtmlParaExibicao('<p><span style="color:#ff0000">x</span></p>');

        $this->assertSame('<p><span style="color:#ff0000;">x</span></p>', $saida);
    }

    private static function entradaValida(array $sobrescrever = []): array
    {
        return array_merge([
            'dataPortaria' => '2026-09-30',
            'conteudo' => '<p>Conteúdo</p>',
            'embasamento' => '<p>Base</p>',
            'assinadoPor' => '12',
        ], $sobrescrever);
    }

    public function testValidarAceitaEntradaValida(): void
    {
        $dados = (new PortariaInputValidator())->validar(self::entradaValida());

        $this->assertSame('2026-09-30', $dados['dataPortaria']);
        $this->assertSame(12, $dados['assinadoPor']);
        $this->assertSame('<p>Conteúdo</p>', $dados['conteudo']);
    }

    public function testValidarLimpaXssNoConteudo(): void
    {
        $dados = (new PortariaInputValidator())->validar(self::entradaValida([
            'conteudo' => '<p>ok</p><script>alert(1)</script>',
            'embasamento' => '<img src=x onerror=alert(1)>',
        ]));

        $this->assertSame([], Payloads::perigos($dados['conteudo']));
        $this->assertSame([], Payloads::perigos($dados['embasamento']));
    }

    public static function entradasInvalidas(): array
    {
        return [
            'data impossivel' => [['dataPortaria' => '2026-02-30'], 'DATA_INVALIDA'],
            'data com hora' => [['dataPortaria' => '2026-09-30 10:00'], 'DATA_INVALIDA'],
            'data vazia' => [['dataPortaria' => ''], 'DATA_INVALIDA'],
            'conteudo so script' => [['conteudo' => '<script>alert(1)</script>'], 'CONTEUDO_VAZIO'],
            'assinador zero' => [['assinadoPor' => '0'], 'ASSINADOR_INVALIDO'],
            'assinador texto' => [['assinadoPor' => "1 OR 1=1"], 'ASSINADOR_INVALIDO'],
            'operacao desconhecida' => [['operacao' => 'excluir'], 'OPERACAO_INVALIDA'],
        ];
    }

    #[DataProvider('entradasInvalidas')]
    public function testValidarRecusaEntradaInvalida(array $sobrescrever, string $codigo): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage($codigo);

        (new PortariaInputValidator())->validar(self::entradaValida($sobrescrever));
    }
}
```

- [ ] **Step 6: Rodar os testes de sanitização**

Run: `php vendor/bin/phpunit --testsuite unit --filter "SanitizerTest|PortariaInputValidatorTest"`
Expected: todos passam **exceto** `SanitizerTest::testImagemBase64PermitidaQuandoHabilitada` (defeito real verificado em 2026-09-30: `Sanitizer(null, true)` devolve `<img alt="a">`, porque `URI.AllowedSchemes` não inclui `data`). Essa falha é esperada e vira entrada da allowlist na Task 6. Qualquer **outra** falha: não altere `classes/`; anote id e mensagem para a Task 6 e relate ao humano.

- [ ] **Step 7: Commit**

```bash
rtk git add tests/Support/Payloads.php tests/Unit/Support/PayloadsTest.php tests/Unit/Security/SanitizerTest.php tests/Unit/Security/PortariaInputValidatorTest.php
rtk git commit -m "test: payloads XSS/SQLi compartilhados e testes de sanitização

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: CSRF, autorização de assinatura e cookie de sessão

**Files:**
- Test: `tests/Unit/Security/CsrfTest.php`
- Test: `tests/Unit/Security/AssinaturaAutorizacaoTest.php`
- Test: `tests/Unit/Security/SessaoCookieTest.php`

**Interfaces:**
- Consumes: `Classes\Csrf` (`getToken(): string`, `validateToken(string): bool`, `htmlField(): string`); `Classes\AssinaturaAutorizacao::resolverAssinador(int, int, bool): int` e `::validarCsrf(string): bool`; funções globais `secureSessionCookieParameters(array): array` e `secureSessionName(bool): string` carregadas por `tests/Unit/bootstrap.php`.
- Produces: nada consumido por outras tasks.

Estas classes já existem; os testes devem passar de primeira. O ciclo aqui é: escrever, rodar, e se algo falhar, **não** mexer em `classes/` — registrar para a Task 6.

- [ ] **Step 1: Escrever `tests/Unit/Security/CsrfTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Classes\Csrf;
use PHPUnit\Framework\TestCase;

final class CsrfTest extends TestCase
{
    protected function setUp(): void
    {
        $_SESSION = [];
    }

    public function testTokenTem64Hex(): void
    {
        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', Csrf::getToken());
    }

    public function testTokenEstavelNaMesmaSessao(): void
    {
        $this->assertSame(Csrf::getToken(), Csrf::getToken());
    }

    public function testNovaSessaoGeraOutroToken(): void
    {
        $primeiro = Csrf::getToken();
        $_SESSION = [];

        $this->assertNotSame($primeiro, Csrf::getToken());
    }

    public function testAceitaTokenCorreto(): void
    {
        $this->assertTrue(Csrf::validateToken(Csrf::getToken()));
    }

    public function testRecusaVariacoes(): void
    {
        $token = Csrf::getToken();
        $trocado = $token;
        $trocado[10] = $token[10] === 'a' ? 'b' : 'a';

        $this->assertFalse(Csrf::validateToken(''), 'vazio');
        $this->assertFalse(Csrf::validateToken(str_repeat('0', 64)), 'outro token');
        $this->assertFalse(Csrf::validateToken($trocado), 'um caractere trocado');
        $this->assertFalse(Csrf::validateToken(strtoupper($token)), 'maiúsculas');
        $this->assertFalse(Csrf::validateToken($token . ' '), 'espaço no fim');
        $this->assertFalse(Csrf::validateToken(substr($token, 0, 63)), 'truncado');
    }

    public function testSemTokenNaSessaoRecusaQualquerValor(): void
    {
        $this->assertFalse(Csrf::validateToken('qualquer'));
        $this->assertArrayNotHasKey('csrf_token', $_SESSION, 'validar não pode criar token');
    }

    public function testComparacaoEmTempoConstante(): void
    {
        $fonte = (string) file_get_contents(SISCONIECP_RAIZ . '/classes/Csrf.php');

        $this->assertStringContainsString('hash_equals(', $fonte);
    }

    public function testCampoHtmlEscapaToken(): void
    {
        $_SESSION['csrf_token'] = 'a"><script>alert(1)</script>';

        $campo = Csrf::htmlField();

        $this->assertStringNotContainsString('<script>', $campo);
        $this->assertStringContainsString('name="csrf_token"', $campo);
        $this->assertStringContainsString('&quot;&gt;&lt;script&gt;', $campo);
    }
}
```

- [ ] **Step 2: Escrever `tests/Unit/Security/AssinaturaAutorizacaoTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Classes\AssinaturaAutorizacao;
use DomainException;
use PHPUnit\Framework\TestCase;

final class AssinaturaAutorizacaoTest extends TestCase
{
    protected function setUp(): void
    {
        $_SESSION = [];
    }

    public function testAtorAssinaPorSiMesmo(): void
    {
        $this->assertSame(5, AssinaturaAutorizacao::resolverAssinador(5, 5, true));
    }

    public function testAtorNaoAssinaPorOutro(): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('ASSINADOR_DIVERGENTE');

        AssinaturaAutorizacao::resolverAssinador(5, 7, true);
    }

    public function testSemAssinarPodeIndicarOutroAssinante(): void
    {
        $this->assertSame(7, AssinaturaAutorizacao::resolverAssinador(5, 7, false));
    }

    public function testAssinanteInvalido(): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('ASSINADOR_INVALIDO');

        AssinaturaAutorizacao::resolverAssinador(5, 0, false);
    }

    public function testCsrfSemSessaoRecusa(): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('CSRF_INVALIDO');

        AssinaturaAutorizacao::validarCsrf('abc');
    }

    public function testCsrfErradoRecusa(): void
    {
        $_SESSION['csrf_token'] = str_repeat('a', 64);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('CSRF_INVALIDO');

        AssinaturaAutorizacao::validarCsrf(str_repeat('b', 64));
    }

    public function testCsrfCorretoAceita(): void
    {
        $_SESSION['csrf_token'] = str_repeat('a', 64);

        $this->assertTrue(AssinaturaAutorizacao::validarCsrf(str_repeat('a', 64)));
    }
}
```

- [ ] **Step 3: Escrever `tests/Unit/Security/SessaoCookieTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class SessaoCookieTest extends TestCase
{
    public static function servidores(): array
    {
        return [
            'localhost http' => [['HTTP_HOST' => 'localhost:80', 'SERVER_PORT' => 80], false],
            'https on' => [['HTTP_HOST' => 'localhost', 'HTTPS' => 'on', 'SERVER_PORT' => 443], true],
            'porta 443 sem flag' => [['HTTP_HOST' => 'localhost', 'SERVER_PORT' => 443], true],
            'producao sem flag' => [['HTTP_HOST' => 'swga.coniecp.com.br', 'SERVER_PORT' => 80], true],
            'proxy https' => [['HTTP_HOST' => 'localhost', 'HTTP_X_FORWARDED_PROTO' => 'https'], true],
            'proxy http nao rebaixa' => [
                ['HTTP_HOST' => 'localhost', 'HTTPS' => 'on', 'HTTP_X_FORWARDED_PROTO' => 'http'],
                true,
            ],
            'host nao confiavel https' => [['HTTP_HOST' => 'evil.example:443', 'HTTPS' => 'on', 'SERVER_PORT' => 443], true],
        ];
    }

    #[DataProvider('servidores')]
    public function testParametrosDoCookie(array $servidor, bool $seguroEsperado): void
    {
        $p = secureSessionCookieParameters($servidor);

        $this->assertSame($seguroEsperado, $p['secure']);
        $this->assertTrue($p['httponly']);
        $this->assertSame('Strict', $p['samesite']);
        $this->assertSame('/', $p['path']);
        $this->assertSame(0, $p['lifetime']);
        $this->assertArrayNotHasKey('domain', $p, 'Host recebido nunca define Domain');
    }

    public function testNomeDoCookie(): void
    {
        $this->assertSame('__Host-SISCONIECP', secureSessionName(true));
        $this->assertSame('SISCONIECP', secureSessionName(false));
    }

    public function testSessaoEmModoEstrito(): void
    {
        $this->assertSame('1', ini_get('session.use_strict_mode'));
        $this->assertSame('1', ini_get('session.use_only_cookies'));
    }
}
```

- [ ] **Step 4: Rodar**

Run: `php vendor/bin/phpunit --testsuite unit --filter "CsrfTest|AssinaturaAutorizacaoTest|SessaoCookieTest"`
Expected: `OK`. Se `testSessaoEmModoEstrito` falhar com `''` em vez de `'1'`, confirme que `tests/Unit/bootstrap.php` incluiu `StartSecureSession.php` **antes** de qualquer saída (a função só aplica os `ini_set` quando abre a sessão). Qualquer outra falha: não altere `classes/`; anote para a Task 6.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/Unit/Security/CsrfTest.php tests/Unit/Security/AssinaturaAutorizacaoTest.php tests/Unit/Security/SessaoCookieTest.php
rtk git commit -m "test: CSRF, autorização de assinatura e cookie de sessão

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Criptografia, token de redefinição de senha e conteúdo base64

**Files:**
- Test: `tests/Unit/Security/CryptoTest.php`
- Test: `tests/Unit/Security/PasswordResetTokenTest.php`
- Test: `tests/Unit/Security/ConteudoBase64Test.php`

**Interfaces:**
- Consumes: `Classes\Crypto` (`encrypt`, `decrypt`, `blindIndex`; chaves via `getenv('APP_ENC_KEY')`/`getenv('APP_BIDX_KEY')`, que têm precedência sobre o `.env` em `Classes\Env::get`); `Classes\PasswordResetToken`; `Classes\ConteudoBase64::decodificarPost(string ...$campos): void`.
- Produces: nada.

- [ ] **Step 1: Escrever `tests/Unit/Security/CryptoTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Classes\Crypto;
use PHPUnit\Framework\TestCase;
use RuntimeException;

final class CryptoTest extends TestCase
{
    /** @var array<string, string|false> */
    private static array $originais = [];

    public static function setUpBeforeClass(): void
    {
        foreach (['APP_ENC_KEY', 'APP_BIDX_KEY'] as $nome) {
            self::$originais[$nome] = getenv($nome);
            putenv($nome . '=' . base64_encode(random_bytes(32)));
        }
    }

    public static function tearDownAfterClass(): void
    {
        foreach (self::$originais as $nome => $valor) {
            putenv($valor === false ? $nome : $nome . '=' . $valor);
        }
    }

    public function testIdaEVolta(): void
    {
        foreach (['529.982.247-25', 'Ação 😀 “aspas”', str_repeat('x', 5000)] as $texto) {
            $this->assertSame($texto, Crypto::decrypt(Crypto::encrypt($texto)));
        }
    }

    public function testVazioContinuaVazio(): void
    {
        $this->assertSame('', Crypto::encrypt(''));
        $this->assertSame('', Crypto::decrypt(''));
    }

    public function testCifraDiferenteACadaChamadaESemTextoPuro(): void
    {
        $a = Crypto::encrypt('52998224725');
        $b = Crypto::encrypt('52998224725');

        $this->assertNotSame($a, $b);
        $this->assertStringStartsWith('v1:', $a);
        $this->assertStringNotContainsString('52998224725', $a);
    }

    public function testAdulteracaoDetectada(): void
    {
        $cifrado = Crypto::encrypt('segredo');
        $bruto = base64_decode(substr($cifrado, 3), true);
        $bruto[strlen($bruto) - 1] = chr(ord($bruto[strlen($bruto) - 1]) ^ 1);

        $this->expectException(RuntimeException::class);

        Crypto::decrypt('v1:' . base64_encode($bruto));
    }

    public function testFormatosInvalidos(): void
    {
        foreach (['sem-versao', 'v2:' . base64_encode(random_bytes(40)), 'v1:' . base64_encode('curto'), 'v1:%%%'] as $entrada) {
            try {
                Crypto::decrypt($entrada);
                $this->fail('Deveria recusar: ' . $entrada);
            } catch (RuntimeException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function testChaveErradaNaoDecifra(): void
    {
        $cifrado = Crypto::encrypt('segredo');
        $chaveAtual = getenv('APP_ENC_KEY');
        putenv('APP_ENC_KEY=' . base64_encode(random_bytes(32)));
        try {
            $this->expectException(RuntimeException::class);
            Crypto::decrypt($cifrado);
        } finally {
            putenv('APP_ENC_KEY=' . $chaveAtual);
        }
    }

    public function testChaveMalFormadaRecusada(): void
    {
        $chaveAtual = getenv('APP_ENC_KEY');
        putenv('APP_ENC_KEY=' . base64_encode('curta'));
        try {
            $this->expectException(RuntimeException::class);
            Crypto::encrypt('x');
        } finally {
            putenv('APP_ENC_KEY=' . $chaveAtual);
        }
    }

    public function testIndiceCegoDeterministicoENormalizado(): void
    {
        $a = Crypto::blindIndex('529.982.247-25');

        $this->assertSame($a, Crypto::blindIndex('52998224725'));
        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', $a);
        $this->assertNotSame($a, Crypto::blindIndex('11144477735'));
        $this->assertSame('', Crypto::blindIndex('.-'));
    }
}
```

- [ ] **Step 2: Escrever `tests/Unit/Security/PasswordResetTokenTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Classes\PasswordResetToken;
use DateTimeImmutable;
use DateTimeZone;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class PasswordResetTokenTest extends TestCase
{
    public function testGeraTokensDe64HexDistintos(): void
    {
        $a = PasswordResetToken::generate();

        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', $a);
        $this->assertNotSame($a, PasswordResetToken::generate());
        $this->assertTrue(PasswordResetToken::isValidFormat($a));
    }

    public static function formatosInvalidos(): array
    {
        return [
            'curto' => [str_repeat('a', 63)],
            'longo' => [str_repeat('a', 65)],
            'nao hex' => [str_repeat('g', 64)],
            'com espaco' => [str_repeat('a', 63) . ' '],
            'vazio' => [''],
            'nulo' => [null],
            'inteiro' => [123],
            'array' => [[str_repeat('a', 64)]],
        ];
    }

    #[DataProvider('formatosInvalidos')]
    public function testRecusaFormatoInvalido(mixed $token): void
    {
        $this->assertFalse(PasswordResetToken::isValidFormat($token));
    }

    public function testHashNaoEhOToken(): void
    {
        $token = PasswordResetToken::generate();
        $hash = PasswordResetToken::hash($token);

        $this->assertSame(hash('sha256', $token), $hash);
        $this->assertNotSame($token, $hash);
        $this->assertSame($hash, PasswordResetToken::hash($token));
    }

    public function testExpiraEm45MinutosEmUtc(): void
    {
        $agora = new DateTimeImmutable('2026-09-30 10:00:00', new DateTimeZone('America/Sao_Paulo'));

        $expira = PasswordResetToken::expiresAt($agora);

        $this->assertSame('UTC', $expira->getTimezone()->getName());
        $this->assertSame('2026-09-30 13:45:00', $expira->format('Y-m-d H:i:s'));
    }

    public function testPrazoNaoPositivoRecusado(): void
    {
        foreach ([0, -1] as $ttl) {
            try {
                PasswordResetToken::expiresAt(null, $ttl);
                $this->fail('Deveria recusar ttl ' . $ttl);
            } catch (InvalidArgumentException) {
                $this->addToAssertionCount(1);
            }
        }
    }
}
```

- [ ] **Step 3: Escrever `tests/Unit/Security/ConteudoBase64Test.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Security;

use Classes\ConteudoBase64;
use DomainException;
use PHPUnit\Framework\TestCase;

final class ConteudoBase64Test extends TestCase
{
    protected function setUp(): void
    {
        $_POST = [];
    }

    public function testDecodificaERemoveCampoB64(): void
    {
        $_POST['assunto_b64'] = base64_encode('<p>Ação &ndash; “Word”</p>');

        ConteudoBase64::decodificarPost('assunto');

        $this->assertSame('<p>Ação &ndash; “Word”</p>', $_POST['assunto']);
        $this->assertArrayNotHasKey('assunto_b64', $_POST);
    }

    public function testCampoLegadoSemB64FicaIntacto(): void
    {
        $_POST['texto'] = '<p>legado</p>';

        ConteudoBase64::decodificarPost('texto');

        $this->assertSame(['texto' => '<p>legado</p>'], $_POST);
    }

    public function testB64TemPrioridadeSobreCampoPuro(): void
    {
        $_POST['texto'] = 'antigo';
        $_POST['texto_b64'] = base64_encode('novo');

        ConteudoBase64::decodificarPost('texto');

        $this->assertSame('novo', $_POST['texto']);
    }

    public function testVariosCampos(): void
    {
        $_POST['assunto_b64'] = base64_encode('A');
        $_POST['texto_b64'] = base64_encode('B');

        ConteudoBase64::decodificarPost('assunto', 'texto');

        $this->assertSame(['assunto' => 'A', 'texto' => 'B'], $_POST);
    }

    public function testBase64InvalidoRecusadoSemGravarCampo(): void
    {
        $_POST['assunto_b64'] = '###não-é-base64###';

        try {
            ConteudoBase64::decodificarPost('assunto');
            $this->fail('Deveria recusar base64 inválido');
        } catch (DomainException $e) {
            $this->assertSame('CONTEUDO_INVALIDO', $e->getMessage());
        }
        $this->assertArrayNotHasKey('assunto', $_POST);
    }

    public function testUtf8InvalidoRecusado(): void
    {
        $_POST['assunto_b64'] = base64_encode("\xff\xfe\xfd");

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('CONTEUDO_INVALIDO');

        ConteudoBase64::decodificarPost('assunto');
    }

    public function testArrayNoLugarDeTextoRecusado(): void
    {
        $_POST['assunto_b64'] = ['x'];

        $this->expectException(DomainException::class);

        ConteudoBase64::decodificarPost('assunto');
    }
}
```

- [ ] **Step 4: Rodar**

Run: `php vendor/bin/phpunit --testsuite unit --filter "CryptoTest|PasswordResetTokenTest|ConteudoBase64Test"`
Expected: `OK`. Falha: não altere `classes/`; anote id e mensagem para a Task 6.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/Unit/Security/CryptoTest.php tests/Unit/Security/PasswordResetTokenTest.php tests/Unit/Security/ConteudoBase64Test.php
rtk git commit -m "test: criptografia de campo, token de senha e conteúdo base64

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Validação de CPF, CNPJ e ocultação de CPF

**Files:**
- Test: `tests/Unit/Validacao/ValidarCpfTest.php`
- Test: `tests/Unit/Validacao/ValidarCnpjTest.php`
- Test: `tests/Unit/Validacao/OcultarCpfTest.php`

**Interfaces:**
- Consumes: `ValidarCpf->validar($cpf)` — **retorna `0` para válido e `1` para inválido** (contrato legado, verificado em 2026-09-30); `ValidarCnpj->validarCnpj(?string): bool` e construtor `new ValidarCnpj(?string)`; função global `ocultarCPF($cpf): string`.
- Produces: nada.

- [ ] **Step 1: Escrever `tests/Unit/Validacao/ValidarCpfTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Validacao;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use ValidarCpf;

/**
 * Contrato legado: validar() devolve 0 quando o CPF é válido e 1 quando é inválido.
 */
final class ValidarCpfTest extends TestCase
{
    public static function setUpBeforeClass(): void
    {
        require_once SISCONIECP_RAIZ . '/classes/ValidarCpf.class.php';
    }

    public static function validos(): array
    {
        return [
            'com mascara' => ['529.982.247-25'],
            'sem mascara' => ['52998224725'],
            'outro' => ['111.444.777-35'],
        ];
    }

    #[DataProvider('validos')]
    public function testCpfValidoRetornaZero(string $cpf): void
    {
        $this->assertSame(0, (new ValidarCpf())->validar($cpf));
    }

    public static function invalidos(): array
    {
        return [
            'digito errado' => ['529.982.247-24'],
            'zeros' => ['000.000.000-00'],
            'uns' => ['111.111.111-11'],
            'noves' => ['999.999.999-99'],
            'curto' => ['123'],
            'vazio' => [''],
            'letra no fim' => ['52998224725x'],
            'doze digitos' => ['529982247250'],
            'injecao' => ["529.982.247-25' OR '1'='1"],
        ];
    }

    #[DataProvider('invalidos')]
    public function testCpfInvalidoRetornaUm(string $cpf): void
    {
        $this->assertSame(1, (new ValidarCpf())->validar($cpf));
    }
}
```

- [ ] **Step 2: Escrever `tests/Unit/Validacao/ValidarCnpjTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Validacao;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use ValidarCnpj;

final class ValidarCnpjTest extends TestCase
{
    public static function setUpBeforeClass(): void
    {
        require_once SISCONIECP_RAIZ . '/classes/ValidarCnpj.class.php';
    }

    public static function validos(): array
    {
        return [
            'numerico com mascara' => ['11.222.333/0001-81'],
            'numerico sem mascara' => ['11222333000181'],
            'alfanumerico' => ['12ABC34501DE35'],
            'alfanumerico-com-mascara' => ['12.ABC.345/01DE-35'],
        ];
    }

    #[DataProvider('validos')]
    public function testCnpjValido(string $cnpj): void
    {
        $this->assertTrue((new ValidarCnpj())->validarCnpj($cnpj));
    }

    public static function invalidos(): array
    {
        return [
            'digito errado' => ['11.222.333/0001-82'],
            'zeros' => ['00000000000000'],
            'uns' => ['11111111111111'],
            'treze digitos' => ['1122233300018'],
            'alfanumerico digito errado' => ['12ABC34501DE36'],
            'lixo' => ['abc'],
            'vazio' => [''],
            'injecao' => ["11222333000181' OR '1'='1"],
        ];
    }

    #[DataProvider('invalidos')]
    public function testCnpjInvalido(string $cnpj): void
    {
        $this->assertFalse((new ValidarCnpj())->validarCnpj($cnpj));
    }

    public function testValorDoConstrutor(): void
    {
        $this->assertTrue((new ValidarCnpj('11222333000181'))->validarCnpj());
        $this->assertFalse((new ValidarCnpj())->validarCnpj());
    }
}
```

- [ ] **Step 3: Escrever `tests/Unit/Validacao/OcultarCpfTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Validacao;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class OcultarCpfTest extends TestCase
{
    public static function setUpBeforeClass(): void
    {
        require_once SISCONIECP_RAIZ . '/classes/OcultarCpf.php';
    }

    public static function cpfs(): array
    {
        return [
            'com mascara' => ['123.456.789-09', '123.***.***-09'],
            'sem mascara' => ['12345678909', '123.***.***-09'],
            'outro' => ['529.982.247-25', '529.***.***-25'],
        ];
    }

    #[DataProvider('cpfs')]
    public function testMostraSoInicioEFim(string $cpf, string $esperado): void
    {
        $saida = ocultarCPF($cpf);

        $this->assertSame($esperado, $saida);
        $this->assertStringNotContainsString(substr(preg_replace('/\D/', '', $cpf), 3, 6), $saida);
    }

    public function testTamanhoErradoNaoDevolveEntrada(): void
    {
        $this->assertSame('CPF inválido', ocultarCPF('123'));
        $this->assertSame('CPF inválido', ocultarCPF('1234567890123'));
    }
}
```

- [ ] **Step 4: Rodar**

Run: `php vendor/bin/phpunit --testsuite unit --filter "ValidarCpfTest|ValidarCnpjTest|OcultarCpfTest"`
Expected: todos passam **exceto** `ValidarCnpjTest::testCnpjValido with data set "alfanumerico-com-mascara"` (defeito real verificado em 2026-09-30: `validarCnpjAlfanumerico` exige 14 caracteres e não remove `.`, `/`, `-`). Falha esperada, vira allowlist na Task 6. Outras falhas: não altere `classes/`; anote para a Task 6.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/Unit/Validacao/
rtk git commit -m "test: validação de CPF, CNPJ e ocultação de CPF

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Allowlist de falhas conhecidas e leitor de JUnit

**Files:**
- Create: `tests/allowlist.php`
- Create: `tests/Support/Allowlist.php`
- Create: `tests/Support/JunitReader.php`
- Test: `tests/Unit/Support/AllowlistTest.php`
- Test: `tests/Unit/Support/JunitReaderTest.php`

**Interfaces:**
- Consumes: nada além do bootstrap.
- Produces:
  - `Tests\Support\Allowlist::carregar(string $arquivo): Allowlist` (arquivo ausente = lista vazia; malformado = `RuntimeException`)
  - `Tests\Support\Allowlist::deArray(array $dados): Allowlist`
  - `Allowlist->explicar(string $idTeste): ?array{id:string,motivo:string,desde:string}` (padrão `id` aceita `*` como curinga; nenhum outro metacaractere)
  - `Allowlist->falhasConhecidas(): list<array{id:string,motivo:string,desde:string}>`
  - `Allowlist->publicos(): list<string>` (chave `publicos` do arquivo; vazia neste plano, usada no Plano 2)
  - `Tests\Support\JunitReader::ler(string $arquivo): list<array{id:string,status:string,mensagem:string}>` — `status` ∈ `passou|falhou|erro|pulado`; `id` = `Classe\Completa::metodo` ou `Classe\Completa::metodo#nome-do-data-set` (ou `#0` para data set numérico)

- [ ] **Step 1: Escrever os testes**

`tests/Unit/Support/AllowlistTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Allowlist;

final class AllowlistTest extends TestCase
{
    private static function entrada(string $id): array
    {
        return ['id' => $id, 'motivo' => 'defeito conhecido', 'desde' => '2026-09-30'];
    }

    public function testCasamentoExato(): void
    {
        $lista = Allowlist::deArray(['falhas_conhecidas' => [self::entrada('Tests\A::testB')]]);

        $this->assertSame('defeito conhecido', $lista->explicar('Tests\A::testB')['motivo']);
        $this->assertNull($lista->explicar('Tests\A::testC'));
    }

    public function testCuringaAsterisco(): void
    {
        $lista = Allowlist::deArray(['falhas_conhecidas' => [self::entrada('legado::tests/portaria/*')]]);

        $this->assertNotNull($lista->explicar('legado::tests/portaria/portaria_layout_test.php'));
        $this->assertNull($lista->explicar('legado::tests/sessao/start_secure_session_test.php'));
    }

    public function testColchetesEPontosSaoLiterais(): void
    {
        $lista = Allowlist::deArray(['falhas_conhecidas' => [self::entrada('Tests\A::testB#caso [1].x')]]);

        $this->assertNotNull($lista->explicar('Tests\A::testB#caso [1].x'));
        $this->assertNull($lista->explicar('Tests\A::testB#caso 1Ax'));
    }

    public function testEntradaSemMotivoFalha(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage("falhas_conhecidas[0] sem 'motivo'");

        Allowlist::deArray(['falhas_conhecidas' => [['id' => 'x', 'desde' => '2026-09-30']]]);
    }

    public function testDataMalFormadaFalha(): void
    {
        $this->expectException(RuntimeException::class);

        Allowlist::deArray(['falhas_conhecidas' => [['id' => 'x', 'motivo' => 'm', 'desde' => '30/09/2026']]]);
    }

    public function testArquivoAusenteEhListaVazia(): void
    {
        $lista = Allowlist::carregar(sys_get_temp_dir() . '/nao-existe-' . bin2hex(random_bytes(4)) . '.php');

        $this->assertSame([], $lista->falhasConhecidas());
        $this->assertSame([], $lista->publicos());
    }

    public function testArquivoDoProjetoCarrega(): void
    {
        $lista = Allowlist::carregar(SISCONIECP_RAIZ . '/tests/allowlist.php');

        $this->assertIsArray($lista->falhasConhecidas());
    }
}
```

`tests/Unit/Support/JunitReaderTest.php` (o XML abaixo foi capturado de uma execução real do PHPUnit 13.2.1):

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\JunitReader;

final class JunitReaderTest extends TestCase
{
    private const XML = <<<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="Tests\Amostra\AmostraTest" tests="6">
    <testsuite name="Tests\Amostra\AmostraTest::testCaso" tests="3">
      <testcase name="testCaso with data set &quot;coniecp/x/yAcao.php&quot;" class="Tests\Amostra\AmostraTest"/>
      <testcase name="testCaso with data set &quot;b &quot;aspas&quot;&quot;" class="Tests\Amostra\AmostraTest">
        <failure type="PHPUnit\Framework\ExpectationFailedException">Tests\Amostra\AmostraTest::testCaso&#13;
msg falha
Failed asserting that 2 is identical to 1.</failure>
      </testcase>
      <testcase name="testCaso with data set #0" class="Tests\Amostra\AmostraTest"/>
    </testsuite>
    <testcase name="testSimples" class="Tests\Amostra\AmostraTest"/>
    <testcase name="testErro" class="Tests\Amostra\AmostraTest">
      <error type="RuntimeException">RuntimeException: boom</error>
    </testcase>
    <testcase name="testPulado" class="Tests\Amostra\AmostraTest">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
XML;

    public function testConverteCasos(): void
    {
        $arquivo = tempnam(sys_get_temp_dir(), 'junit');
        file_put_contents($arquivo, self::XML);
        try {
            $casos = JunitReader::ler($arquivo);
        } finally {
            unlink($arquivo);
        }

        $porId = array_column($casos, null, 'id');
        $this->assertCount(6, $casos);
        $this->assertSame('passou', $porId['Tests\Amostra\AmostraTest::testCaso#coniecp/x/yAcao.php']['status']);
        $this->assertSame('falhou', $porId['Tests\Amostra\AmostraTest::testCaso#b "aspas"']['status']);
        $this->assertStringContainsString('msg falha', $porId['Tests\Amostra\AmostraTest::testCaso#b "aspas"']['mensagem']);
        $this->assertStringNotContainsString("\r", $porId['Tests\Amostra\AmostraTest::testCaso#b "aspas"']['mensagem']);
        $this->assertSame('passou', $porId['Tests\Amostra\AmostraTest::testCaso#0']['status']);
        $this->assertSame('passou', $porId['Tests\Amostra\AmostraTest::testSimples']['status']);
        $this->assertSame('erro', $porId['Tests\Amostra\AmostraTest::testErro']['status']);
        $this->assertSame('pulado', $porId['Tests\Amostra\AmostraTest::testPulado']['status']);
    }

    public function testArquivoAusenteFalha(): void
    {
        $this->expectException(RuntimeException::class);

        JunitReader::ler(sys_get_temp_dir() . '/sem-junit-' . bin2hex(random_bytes(4)) . '.xml');
    }

    public function testXmlInvalidoFalha(): void
    {
        $arquivo = tempnam(sys_get_temp_dir(), 'junit');
        file_put_contents($arquivo, '<testsuites><quebrado');
        try {
            $this->expectException(RuntimeException::class);
            JunitReader::ler($arquivo);
        } finally {
            unlink($arquivo);
        }
    }
}
```

- [ ] **Step 2: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter "AllowlistTest|JunitReaderTest"`
Expected: erro `Class "Tests\Support\Allowlist" not found` e `Class "Tests\Support\JunitReader" not found`.

- [ ] **Step 3: Implementar `tests/Support/Allowlist.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support;

use RuntimeException;

/**
 * Falhas conhecidas e aceitas temporariamente (spec §10) e, a partir do
 * Plano 2, endpoints públicos. Toda entrada exige motivo e data para que
 * a lista apareça no relatório e não vire esquecimento.
 */
final class Allowlist
{
    /**
     * @param list<array{id: string, motivo: string, desde: string}> $falhas
     * @param list<string> $publicos
     */
    private function __construct(
        private readonly array $falhas,
        private readonly array $publicos,
    ) {
    }

    public static function carregar(string $arquivo): self
    {
        if (!is_file($arquivo)) {
            return new self([], []);
        }
        $dados = require $arquivo;
        if (!is_array($dados)) {
            throw new RuntimeException('tests/allowlist.php deve retornar um array.');
        }

        return self::deArray($dados);
    }

    public static function deArray(array $dados): self
    {
        $falhas = array_values($dados['falhas_conhecidas'] ?? []);
        foreach ($falhas as $i => $falha) {
            foreach (['id', 'motivo', 'desde'] as $campo) {
                if (!is_string($falha[$campo] ?? null) || trim($falha[$campo]) === '') {
                    throw new RuntimeException("allowlist: falhas_conhecidas[{$i}] sem '{$campo}'.");
                }
            }
            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $falha['desde'])) {
                throw new RuntimeException("allowlist: falhas_conhecidas[{$i}] com 'desde' fora do formato AAAA-MM-DD.");
            }
        }

        $publicos = array_values(array_filter($dados['publicos'] ?? [], 'is_string'));

        return new self($falhas, $publicos);
    }

    /** @return array{id: string, motivo: string, desde: string}|null */
    public function explicar(string $idTeste): ?array
    {
        foreach ($this->falhas as $falha) {
            if (self::casa($falha['id'], $idTeste)) {
                return $falha;
            }
        }

        return null;
    }

    /** @return list<array{id: string, motivo: string, desde: string}> */
    public function falhasConhecidas(): array
    {
        return $this->falhas;
    }

    /** @return list<string> */
    public function publicos(): array
    {
        return $this->publicos;
    }

    private static function casa(string $padrao, string $valor): bool
    {
        $regex = '~^' . str_replace('\*', '.*', preg_quote($padrao, '~')) . '$~s';

        return preg_match($regex, $valor) === 1;
    }
}
```

- [ ] **Step 4: Implementar `tests/Support/JunitReader.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support;

use RuntimeException;

final class JunitReader
{
    /** @return list<array{id: string, status: string, mensagem: string}> */
    public static function ler(string $arquivo): array
    {
        if (!is_file($arquivo)) {
            throw new RuntimeException('Relatório JUnit não gerado: ' . $arquivo);
        }
        $anterior = libxml_use_internal_errors(true);
        $xml = simplexml_load_file($arquivo);
        libxml_clear_errors();
        libxml_use_internal_errors($anterior);
        if ($xml === false) {
            throw new RuntimeException('Relatório JUnit ilegível: ' . $arquivo);
        }

        $casos = [];
        foreach ($xml->xpath('//testcase') ?: [] as $caso) {
            $nome = (string) $caso['name'];
            if (preg_match('/^(\S+) with data set (?:"(.*)"|#(\d+))$/s', $nome, $m)) {
                $nome = $m[1] . '#' . (($m[2] ?? '') !== '' ? $m[2] : ($m[3] ?? ''));
            }

            $status = 'passou';
            $mensagem = '';
            if (isset($caso->failure)) {
                $status = 'falhou';
                $mensagem = (string) $caso->failure;
            } elseif (isset($caso->error)) {
                $status = 'erro';
                $mensagem = (string) $caso->error;
            } elseif (isset($caso->skipped)) {
                $status = 'pulado';
            }

            $casos[] = [
                'id' => (string) $caso['class'] . '::' . $nome,
                'status' => $status,
                'mensagem' => trim(str_replace("\r", '', $mensagem)),
            ];
        }

        return $casos;
    }
}
```

Atenção ao regex: para `with data set #0` o grupo 2 fica vazio e o grupo 3 tem `0`. Um data set nomeado com string vazia (`""`) resultaria em `#` — aceitável, o projeto não usa nomes vazios.

- [ ] **Step 5: Criar `tests/allowlist.php` com as falhas verificadas nas Tasks 2 e 5**

```php
<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

/*
 * Falhas conhecidas aceitas temporariamente pelo portão (spec §10).
 * Cada entrada: id do teste (curinga * permitido), motivo e data (AAAA-MM-DD).
 * Ao corrigir o defeito, apague a entrada — o relatório lista entradas sem uso.
 */
return [
    'falhas_conhecidas' => [
        [
            'id' => 'Tests\Unit\Security\SanitizerTest::testImagemBase64PermitidaQuandoHabilitada',
            'motivo' => 'Sanitizer(allowBase64Images: true) remove src="data:..." porque URI.AllowedSchemes não inclui data.',
            'desde' => '2026-09-30',
        ],
        [
            'id' => 'Tests\Unit\Validacao\ValidarCnpjTest::testCnpjValido#alfanumerico-com-mascara',
            'motivo' => 'ValidarCnpj recusa CNPJ alfanumérico com máscara (12.ABC.345/01DE-35): não remove . / - antes de exigir 14 caracteres.',
            'desde' => '2026-09-30',
        ],
    ],
    // Plano 2: rotas acessíveis sem login (caminho relativo à raiz).
    'publicos' => [],
];
```

Se as Tasks 2–5 anotaram outras falhas, acrescente uma entrada para cada uma, com o id exato do JUnit (formato `Classe::metodo` ou `Classe::metodo#data-set`), motivo em uma frase e `desde` = data de hoje.

- [ ] **Step 6: Rodar**

Run: `php vendor/bin/phpunit --testsuite unit --filter "AllowlistTest|JunitReaderTest"`
Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
rtk git add tests/allowlist.php tests/Support/Allowlist.php tests/Support/JunitReader.php tests/Unit/Support/AllowlistTest.php tests/Unit/Support/JunitReaderTest.php
rtk git commit -m "test: allowlist de falhas conhecidas e leitor de JUnit

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Núcleo do runner — processo, resultado, execução e relatório

**Files:**
- Create: `tests/Support/Gate/Falha.php`
- Create: `tests/Support/Gate/Resultado.php`
- Create: `tests/Support/Gate/Etapa.php`
- Create: `tests/Support/Gate/Processo.php`
- Create: `tests/Support/Gate/Runner.php`
- Create: `tests/Support/Gate/Relatorio.php`
- Test: `tests/Unit/Support/ProcessoTest.php`
- Test: `tests/Unit/Support/RunnerTest.php`
- Test: `tests/Unit/Support/RelatorioTest.php`

**Interfaces:**
- Consumes: `Tests\Support\Allowlist` (Task 6).
- Produces:
  - `Tests\Support\Gate\Falha(string $id, string $mensagem, ?array $conhecida = null)` — propriedades públicas `readonly`; `$conhecida` é a entrada da allowlist quando aplicável.
  - `Tests\Support\Gate\Resultado(string $etapa, string $status, list<Falha> $falhas = [], string $observacao = '')` — constantes `PASSOU`, `REPROVOU`, `PULOU`, `ABORTOU`; `Resultado::deFalhas(string $etapa, list<Falha> $falhas, string $observacao = ''): Resultado` (REPROVOU se houver falha sem `conhecida`, senão PASSOU).
  - `interface Tests\Support\Gate\Etapa { public function nome(): string; public function executar(): Resultado; }`
  - `Tests\Support\Gate\Processo::executar(list<string> $comando, array<string,string> $env = [], ?string $cwd = null, int $timeoutSegundos = 600): array{codigo:int, saida:string, estourou:bool}` — `codigo` 124 quando estoura o tempo; `saida` = stdout seguido de stderr.
  - `Tests\Support\Gate\Runner(list<Etapa> $etapas)`; `->executar(?callable $aoConcluir = null): list<Resultado>` (callback recebe `Resultado $r, float $segundos`); exceção numa etapa vira `REPROVOU`; `ABORTOU` interrompe as etapas seguintes. `Runner::codigoSaida(list<Resultado>): int` → 2 se algum ABORTOU, 1 se algum REPROVOU, senão 0.
  - `Tests\Support\Gate\Relatorio::terminal(list<Resultado> $resultados): string`
  - `Tests\Support\Gate\Relatorio::markdown(list<Resultado> $resultados, Allowlist $allowlist, \DateTimeImmutable $quando): string`

- [ ] **Step 1: Escrever os testes**

`tests/Unit/Support/ProcessoTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use Tests\Support\Gate\Processo;

final class ProcessoTest extends TestCase
{
    public function testCapturaSaidaECodigo(): void
    {
        $r = Processo::executar([PHP_BINARY, '-r', 'echo "ola"; fwrite(STDERR, "erro"); exit(3);']);

        $this->assertSame(3, $r['codigo']);
        $this->assertFalse($r['estourou']);
        $this->assertStringContainsString('ola', $r['saida']);
        $this->assertStringContainsString('erro', $r['saida']);
    }

    public function testRepassaVariaveisDeAmbiente(): void
    {
        $r = Processo::executar([PHP_BINARY, '-r', 'echo getenv("GATE_X");'], ['GATE_X' => 'valor=com igual']);

        $this->assertSame('valor=com igual', trim($r['saida']));
    }

    public function testArgumentoComEspacoEAspasNaoQuebra(): void
    {
        $r = Processo::executar([PHP_BINARY, '-r', 'echo $argv[1];', 'a b "c"']);

        $this->assertSame('a b "c"', trim($r['saida']));
    }

    public function testTimeoutMataProcesso(): void
    {
        $inicio = microtime(true);

        $r = Processo::executar([PHP_BINARY, '-r', 'sleep(30);'], [], null, 1);

        $this->assertTrue($r['estourou']);
        $this->assertSame(124, $r['codigo']);
        $this->assertLessThan(10, microtime(true) - $inicio);
    }
}
```

`tests/Unit/Support/RunnerTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Gate\Etapa;
use Tests\Support\Gate\Falha;
use Tests\Support\Gate\Resultado;
use Tests\Support\Gate\Runner;

final class RunnerTest extends TestCase
{
    private static function etapa(string $nome, callable $fn): Etapa
    {
        return new class ($nome, $fn) implements Etapa {
            /** @var callable */
            private $fn;

            public function __construct(private readonly string $n, callable $fn)
            {
                $this->fn = $fn;
            }

            public function nome(): string
            {
                return $this->n;
            }

            public function executar(): Resultado
            {
                return ($this->fn)();
            }
        };
    }

    public function testExcecaoViraReprovacaoESegue(): void
    {
        $executou = false;
        $runner = new Runner([
            self::etapa('a', fn () => throw new RuntimeException('quebrou')),
            self::etapa('b', function () use (&$executou) {
                $executou = true;

                return new Resultado('b', Resultado::PASSOU);
            }),
        ]);

        $resultados = $runner->executar();

        $this->assertSame(Resultado::REPROVOU, $resultados[0]->status);
        $this->assertStringContainsString('quebrou', $resultados[0]->falhas[0]->mensagem);
        $this->assertTrue($executou);
        $this->assertSame(1, Runner::codigoSaida($resultados));
    }

    public function testAbortoInterrompeEDevolve2(): void
    {
        $runner = new Runner([
            self::etapa('pre', fn () => new Resultado('pre', Resultado::ABORTOU, [new Falha('pre', 'Apache fora')])),
            self::etapa('depois', fn () => throw new RuntimeException('não deveria rodar')),
        ]);

        $resultados = $runner->executar();

        $this->assertCount(1, $resultados);
        $this->assertSame(2, Runner::codigoSaida($resultados));
    }

    public function testTudoPassouDevolve0EChamaCallback(): void
    {
        $vistos = [];
        $runner = new Runner([self::etapa('a', fn () => new Resultado('a', Resultado::PASSOU))]);

        $resultados = $runner->executar(function (Resultado $r, float $s) use (&$vistos) {
            $vistos[] = $r->etapa;
        });

        $this->assertSame(['a'], $vistos);
        $this->assertSame(0, Runner::codigoSaida($resultados));
    }

    public function testDeFalhasConsideraConhecidas(): void
    {
        $conhecida = ['id' => 'x', 'motivo' => 'm', 'desde' => '2026-09-30'];

        $soConhecidas = Resultado::deFalhas('u', [new Falha('x', 'm', $conhecida)]);
        $comNova = Resultado::deFalhas('u', [new Falha('x', 'm', $conhecida), new Falha('y', 'nova')]);

        $this->assertSame(Resultado::PASSOU, $soConhecidas->status);
        $this->assertSame(Resultado::REPROVOU, $comNova->status);
        $this->assertSame(Resultado::PASSOU, Resultado::deFalhas('u', [])->status);
    }
}
```

`tests/Unit/Support/RelatorioTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use DateTimeImmutable;
use PHPUnit\Framework\TestCase;
use Tests\Support\Allowlist;
use Tests\Support\Gate\Falha;
use Tests\Support\Gate\Relatorio;
use Tests\Support\Gate\Resultado;

final class RelatorioTest extends TestCase
{
    private static function cenario(): array
    {
        $conhecida = ['id' => 'T::conhecido', 'motivo' => 'defeito X', 'desde' => '2026-09-30'];
        $allowlist = Allowlist::deArray(['falhas_conhecidas' => [
            $conhecida,
            ['id' => 'T::jaCorrigido', 'motivo' => 'antigo', 'desde' => '2026-09-01'],
        ]]);
        $resultados = [
            new Resultado('lint', Resultado::PASSOU, [], 'nenhum PHP alterado'),
            new Resultado('unit', Resultado::REPROVOU, [
                new Falha('T::novo', "Falhou | com pipe\nsegunda linha"),
                new Falha('T::conhecido', 'falha antiga', $conhecida),
            ]),
            new Resultado('legado', Resultado::PULOU, [], '2 pulados (exit 2)'),
        ];

        return [$resultados, $allowlist];
    }

    public function testTerminalMostraStatusPorEtapa(): void
    {
        [$resultados] = self::cenario();

        $texto = Relatorio::terminal($resultados);

        $this->assertMatchesRegularExpression('/PASSOU\s+lint/', $texto);
        $this->assertMatchesRegularExpression('/REPROVOU\s+unit/', $texto);
        $this->assertStringContainsString('1 nova(s), 1 conhecida(s)', $texto);
        $this->assertMatchesRegularExpression('/PULOU\s+legado/', $texto);
    }

    public function testMarkdownListaNovasEConhecidasSeparadas(): void
    {
        [$resultados, $allowlist] = self::cenario();

        $md = Relatorio::markdown($resultados, $allowlist, new DateTimeImmutable('2026-09-30 10:00:00'));

        $this->assertStringContainsString('# Portão pré-deploy — 2026-09-30 10:00', $md);
        $this->assertStringContainsString('**Resultado: REPROVADO**', $md);
        $this->assertStringContainsString('`T::novo`', $md);
        $this->assertStringContainsString('defeito X (desde 2026-09-30)', $md);
        $this->assertStringContainsString("Falhou | com pipe\nsegunda linha", $md);
    }

    public function testListaEntradasSemUso(): void
    {
        [$resultados, $allowlist] = self::cenario();

        $md = Relatorio::markdown($resultados, $allowlist, new DateTimeImmutable('2026-09-30 10:00:00'));

        $this->assertStringContainsString('## Entradas da allowlist sem uso', $md);
        $this->assertStringContainsString('`T::jaCorrigido`', $md);
    }

    public function testAprovadoQuandoSoConhecidas(): void
    {
        $conhecida = ['id' => 'T::c', 'motivo' => 'm', 'desde' => '2026-09-30'];
        $allowlist = Allowlist::deArray(['falhas_conhecidas' => [$conhecida]]);
        $resultados = [Resultado::deFalhas('unit', [new Falha('T::c', 'x', $conhecida)])];

        $md = Relatorio::markdown($resultados, $allowlist, new DateTimeImmutable('2026-09-30 10:00:00'));

        $this->assertStringContainsString('**Resultado: APROVADO**', $md);
        $this->assertStringNotContainsString('## Entradas da allowlist sem uso', $md);
    }
}
```

- [ ] **Step 2: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter "ProcessoTest|RunnerTest|RelatorioTest"`
Expected: erros `Class "Tests\Support\Gate\..." not found`.

- [ ] **Step 3: Implementar os tipos**

`tests/Support/Gate/Falha.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

final class Falha
{
    /** @param array{id: string, motivo: string, desde: string}|null $conhecida */
    public function __construct(
        public readonly string $id,
        public readonly string $mensagem,
        public readonly ?array $conhecida = null,
    ) {
    }
}
```

`tests/Support/Gate/Resultado.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

final class Resultado
{
    public const PASSOU = 'passou';
    public const REPROVOU = 'reprovou';
    public const PULOU = 'pulou';
    public const ABORTOU = 'abortou';

    /** @param list<Falha> $falhas */
    public function __construct(
        public readonly string $etapa,
        public readonly string $status,
        public readonly array $falhas = [],
        public readonly string $observacao = '',
    ) {
    }

    /** @param list<Falha> $falhas */
    public static function deFalhas(string $etapa, array $falhas, string $observacao = ''): self
    {
        foreach ($falhas as $falha) {
            if ($falha->conhecida === null) {
                return new self($etapa, self::REPROVOU, $falhas, $observacao);
            }
        }

        return new self($etapa, self::PASSOU, $falhas, $observacao);
    }
}
```

`tests/Support/Gate/Etapa.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

interface Etapa
{
    public function nome(): string;

    public function executar(): Resultado;
}
```

- [ ] **Step 4: Implementar `tests/Support/Gate/Processo.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use RuntimeException;

/**
 * Executa um comando sem shell (array → CreateProcess direto no Windows),
 * com timeout. A saída vai para arquivos temporários porque pipes não
 * bloqueantes não funcionam com proc_open no Windows.
 */
final class Processo
{
    /**
     * @param list<string> $comando
     * @param array<string, string> $env
     * @return array{codigo: int, saida: string, estourou: bool}
     */
    public static function executar(array $comando, array $env = [], ?string $cwd = null, int $timeoutSegundos = 600): array
    {
        $saidaPadrao = (string) tempnam(sys_get_temp_dir(), 'gate-out');
        $saidaErro = (string) tempnam(sys_get_temp_dir(), 'gate-err');
        $descritores = [
            0 => ['pipe', 'r'],
            1 => ['file', $saidaPadrao, 'w'],
            2 => ['file', $saidaErro, 'w'],
        ];
        $ambiente = $env === [] ? null : array_merge(getenv(), $env);

        $processo = proc_open($comando, $descritores, $pipes, $cwd, $ambiente);
        if (!is_resource($processo)) {
            @unlink($saidaPadrao);
            @unlink($saidaErro);
            throw new RuntimeException('Não foi possível iniciar: ' . implode(' ', $comando));
        }
        fclose($pipes[0]);

        $limite = microtime(true) + $timeoutSegundos;
        $estourou = false;
        while (true) {
            $status = proc_get_status($processo);
            if (!$status['running']) {
                $codigo = (int) $status['exitcode'];
                break;
            }
            if (microtime(true) >= $limite) {
                proc_terminate($processo);
                $estourou = true;
                $codigo = 124;
                break;
            }
            usleep(100_000);
        }
        proc_close($processo);

        $saida = (string) file_get_contents($saidaPadrao) . (string) file_get_contents($saidaErro);
        @unlink($saidaPadrao);
        @unlink($saidaErro);

        return ['codigo' => $codigo, 'saida' => $saida, 'estourou' => $estourou];
    }
}
```

- [ ] **Step 5: Implementar `tests/Support/Gate/Runner.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use Throwable;

final class Runner
{
    /** @param list<Etapa> $etapas */
    public function __construct(private readonly array $etapas)
    {
    }

    /** @return list<Resultado> */
    public function executar(?callable $aoConcluir = null): array
    {
        $resultados = [];
        foreach ($this->etapas as $etapa) {
            $inicio = microtime(true);
            try {
                $resultado = $etapa->executar();
            } catch (Throwable $e) {
                $resultado = new Resultado($etapa->nome(), Resultado::REPROVOU, [
                    new Falha($etapa->nome(), $e::class . ': ' . $e->getMessage()),
                ]);
            }
            $resultados[] = $resultado;
            if ($aoConcluir !== null) {
                $aoConcluir($resultado, microtime(true) - $inicio);
            }
            if ($resultado->status === Resultado::ABORTOU) {
                break;
            }
        }

        return $resultados;
    }

    /** @param list<Resultado> $resultados */
    public static function codigoSaida(array $resultados): int
    {
        foreach ($resultados as $r) {
            if ($r->status === Resultado::ABORTOU) {
                return 2;
            }
        }
        foreach ($resultados as $r) {
            if ($r->status === Resultado::REPROVOU) {
                return 1;
            }
        }

        return 0;
    }
}
```

- [ ] **Step 6: Implementar `tests/Support/Gate/Relatorio.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use DateTimeImmutable;
use Tests\Support\Allowlist;

final class Relatorio
{
    private const LIMITE_MENSAGEM = 2000;

    /** @param list<Resultado> $resultados */
    public static function terminal(array $resultados): string
    {
        $linhas = [];
        foreach ($resultados as $r) {
            $linhas[] = sprintf('%-9s %s%s', strtoupper($r->status), $r->etapa, self::resumo($r));
        }

        return implode(PHP_EOL, $linhas) . PHP_EOL;
    }

    /** @param list<Resultado> $resultados */
    public static function markdown(array $resultados, Allowlist $allowlist, DateTimeImmutable $quando): string
    {
        $aprovado = Runner::codigoSaida($resultados) === 0;
        $md = '# Portão pré-deploy — ' . $quando->format('Y-m-d H:i') . "\n\n";
        $md .= '**Resultado: ' . ($aprovado ? 'APROVADO' : 'REPROVADO') . "**\n\n";
        $md .= "| Etapa | Status | Detalhe |\n|---|---|---|\n";
        foreach ($resultados as $r) {
            $md .= sprintf("| %s | %s | %s |\n", $r->etapa, strtoupper($r->status), ltrim(self::resumo($r), ' —'));
        }

        $usadas = [];
        foreach ($resultados as $r) {
            $novas = array_filter($r->falhas, static fn (Falha $f) => $f->conhecida === null);
            if ($novas !== []) {
                $md .= "\n## {$r->etapa} — reprovações\n";
                foreach ($novas as $falha) {
                    $md .= "\n### `{$falha->id}`\n\n```\n" . mb_substr($falha->mensagem, 0, self::LIMITE_MENSAGEM) . "\n```\n";
                }
            }
            foreach ($r->falhas as $falha) {
                if ($falha->conhecida !== null) {
                    $usadas[$falha->conhecida['id']] = true;
                }
            }
        }

        $conhecidas = [];
        foreach ($resultados as $r) {
            foreach ($r->falhas as $falha) {
                if ($falha->conhecida !== null) {
                    $conhecidas[] = sprintf(
                        '- `%s` — %s (desde %s)',
                        $falha->id,
                        $falha->conhecida['motivo'],
                        $falha->conhecida['desde']
                    );
                }
            }
        }
        if ($conhecidas !== []) {
            $md .= "\n## Falhas conhecidas (allowlist)\n\n" . implode("\n", $conhecidas) . "\n";
        }

        $semUso = array_filter(
            $allowlist->falhasConhecidas(),
            static fn (array $entrada) => !isset($usadas[$entrada['id']])
        );
        if ($semUso !== []) {
            $md .= "\n## Entradas da allowlist sem uso\n\nO defeito pode ter sido corrigido; apague a entrada de `tests/allowlist.php`.\n\n";
            foreach ($semUso as $entrada) {
                $md .= "- `{$entrada['id']}` (desde {$entrada['desde']})\n";
            }
        }

        return $md;
    }

    private static function resumo(Resultado $r): string
    {
        $novas = count(array_filter($r->falhas, static fn (Falha $f) => $f->conhecida === null));
        $conhecidas = count($r->falhas) - $novas;
        $partes = [];
        if ($r->falhas !== []) {
            $partes[] = "{$novas} nova(s), {$conhecidas} conhecida(s)";
        }
        if ($r->observacao !== '') {
            $partes[] = $r->observacao;
        }

        return $partes === [] ? '' : ' — ' . implode('; ', $partes);
    }
}
```

Nota: "Entradas sem uso" só faz sentido quando todas as etapas rodaram. Com `--suite=` ou `--fast`, entradas de outras suítes aparecem como sem uso; o `gate.php` (Task 8) passa uma allowlist filtrada nesses modos.

- [ ] **Step 7: Rodar**

Run: `php vendor/bin/phpunit --testsuite unit --filter "ProcessoTest|RunnerTest|RelatorioTest"`
Expected: `OK`. Se `testTimeoutMataProcesso` demorar > 10 s no Windows, confirme que o comando é passado como **array** para `proc_open` (com string o PHP abre um `cmd.exe` e o `proc_terminate` mata só o shell).

- [ ] **Step 8: Commit**

```bash
rtk git add tests/Support/Gate/ tests/Unit/Support/ProcessoTest.php tests/Unit/Support/RunnerTest.php tests/Unit/Support/RelatorioTest.php
rtk git commit -m "test: núcleo do runner do portão (processo, execução, relatório)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Etapas (pré-requisitos, lint, PHPUnit, legados) e `gate.php`

**Files:**
- Create: `tests/Support/Gate/EtapaPreflight.php`
- Create: `tests/Support/Gate/EtapaLint.php`
- Create: `tests/Support/Gate/EtapaPhpUnit.php`
- Create: `tests/Support/Gate/EtapaLegado.php`
- Create: `tests/gate.php`
- Test: `tests/Unit/Support/EtapaPreflightTest.php`
- Test: `tests/Unit/Support/EtapaLintTest.php`
- Test: `tests/Unit/Support/EtapaPhpUnitTest.php`
- Test: `tests/Unit/Support/EtapaLegadoTest.php`

**Interfaces:**
- Consumes: `Env` (Task 1), `Allowlist`, `JunitReader` (Task 6), `Etapa`, `Resultado`, `Falha`, `Processo`, `Runner`, `Relatorio` (Task 7).
- Produces (usado pelos Planos 2–4):
  - `EtapaPreflight(Env $env, bool $arquivoEnvExiste, bool $exigeServidor, ?callable $sondaHttp = null, ?callable $sondaBanco = null)` — `sondaHttp(string $url): int` devolve o status HTTP (0 = sem resposta); `sondaBanco(string $dsn, string $usuario, string $senha): void` lança em falha. Nome `preflight`.
  - `EtapaLint(string $raiz, ?callable $listarArquivos = null)` — `listarArquivos(): list<string>` devolve caminhos relativos. Nome `lint`.
  - `EtapaPhpUnit(string $raiz, string $suite, Allowlist $allowlist, array<string,string> $env = [])` — nome = `$suite`; `EtapaPhpUnit::classificar(list<array{id,status,mensagem}> $casos, int $codigo, string $saida, string $suite, Allowlist $allowlist): list<Falha>` (estático, puro).
  - `EtapaLegado(string $raiz, Env $env, Allowlist $allowlist)` — nome `legado`; `EtapaLegado::descobrir(string $raiz): list<string>` (estático; caminhos relativos com `/`); ids de falha no formato `legado::tests/pasta/arquivo_test.ext`.
  - `tests/gate.php` — array `$etapas` indexado por nome, na ordem de execução; Planos 2–4 acrescentam entradas.

- [ ] **Step 1: Escrever os testes**

`tests/Unit/Support/EtapaPreflightTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Env;
use Tests\Support\Gate\EtapaPreflight;
use Tests\Support\Gate\Resultado;

final class EtapaPreflightTest extends TestCase
{
    private static function env(string $url = 'http://localhost/sisconiecp2'): Env
    {
        return Env::deTexto("GATE_BASE_URL={$url}\nGATE_LOCAL_DSN=mysql:host=localhost;dbname=x\nGATE_LOCAL_READ_USER=u\nGATE_LOCAL_READ_PASSWORD=p\n");
    }

    public function testModoRapidoSemArquivoPassa(): void
    {
        $r = (new EtapaPreflight(Env::vazio(), false, false))->executar();

        $this->assertSame(Resultado::PASSOU, $r->status);
    }

    public function testSemArquivoEmModoCompletoAborta(): void
    {
        $r = (new EtapaPreflight(Env::vazio(), false, true))->executar();

        $this->assertSame(Resultado::ABORTOU, $r->status);
        $this->assertStringContainsString('tests/.env.local', $r->falhas[0]->mensagem);
    }

    public function testHostExternoAbortaSemTocarRede(): void
    {
        $chamouHttp = false;
        $etapa = new EtapaPreflight(self::env('https://swga.coniecp.com.br'), true, true, function () use (&$chamouHttp) {
            $chamouHttp = true;

            return 200;
        }, fn () => null);

        $r = $etapa->executar();

        $this->assertSame(Resultado::ABORTOU, $r->status);
        $this->assertFalse($chamouHttp, 'Nunca pode sondar host externo');
    }

    public function testApacheForaAborta(): void
    {
        $r = (new EtapaPreflight(self::env(), true, true, fn () => 0, fn () => null))->executar();

        $this->assertSame(Resultado::ABORTOU, $r->status);
        $this->assertStringContainsString('Apache', $r->falhas[0]->mensagem);
    }

    public function testErro500Aborta(): void
    {
        $r = (new EtapaPreflight(self::env(), true, true, fn () => 500, fn () => null))->executar();

        $this->assertSame(Resultado::ABORTOU, $r->status);
    }

    public function testMysqlForaAborta(): void
    {
        $r = (new EtapaPreflight(self::env(), true, true, fn () => 200, function () {
            throw new RuntimeException('SQLSTATE[HY000] [2002] recusado');
        }))->executar();

        $this->assertSame(Resultado::ABORTOU, $r->status);
        $this->assertStringContainsString('MySQL', $r->falhas[0]->mensagem);
    }

    public function testTudoOkPassa(): void
    {
        $urlSondada = '';
        $r = (new EtapaPreflight(self::env(), true, true, function (string $url) use (&$urlSondada) {
            $urlSondada = $url;

            return 302;
        }, fn () => null))->executar();

        $this->assertSame(Resultado::PASSOU, $r->status);
        $this->assertSame('http://localhost/sisconiecp2/index.php', $urlSondada);
    }
}
```

`tests/Unit/Support/EtapaLintTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use Tests\Support\Gate\EtapaLint;
use Tests\Support\Gate\Resultado;

final class EtapaLintTest extends TestCase
{
    private string $dir;

    protected function setUp(): void
    {
        $this->dir = sys_get_temp_dir() . '/gate-lint-' . bin2hex(random_bytes(4));
        mkdir($this->dir . '/vendor', 0777, true);
        file_put_contents($this->dir . '/bom.php', "<?php\necho 1;\n");
        file_put_contents($this->dir . '/quebrado.php', "<?php\necho 1\n");
        file_put_contents($this->dir . '/vendor/lib.php', "<?php\nquebrado(\n");
        file_put_contents($this->dir . '/notas.txt', 'x');
    }

    protected function tearDown(): void
    {
        foreach (['bom.php', 'quebrado.php', 'vendor/lib.php', 'notas.txt'] as $f) {
            @unlink($this->dir . '/' . $f);
        }
        @rmdir($this->dir . '/vendor');
        @rmdir($this->dir);
    }

    public function testReprovaSoOArquivoQuebrado(): void
    {
        $etapa = new EtapaLint($this->dir, fn () => ['bom.php', 'quebrado.php', 'vendor/lib.php', 'notas.txt', 'apagado.php']);

        $r = $etapa->executar();

        $this->assertSame(Resultado::REPROVOU, $r->status);
        $this->assertCount(1, $r->falhas);
        $this->assertSame('lint::quebrado.php', $r->falhas[0]->id);
        $this->assertStringContainsString('2 arquivo(s) PHP verificado(s)', $r->observacao);
    }

    public function testNadaAlteradoPassa(): void
    {
        $r = (new EtapaLint($this->dir, fn () => []))->executar();

        $this->assertSame(Resultado::PASSOU, $r->status);
        $this->assertSame('nenhum PHP alterado', $r->observacao);
    }
}
```

`tests/Unit/Support/EtapaPhpUnitTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use Tests\Support\Allowlist;
use Tests\Support\Gate\EtapaPhpUnit;

final class EtapaPhpUnitTest extends TestCase
{
    public function testSoFalhasEErrosViramFalha(): void
    {
        $allowlist = Allowlist::deArray(['falhas_conhecidas' => [
            ['id' => 'T::conhecido', 'motivo' => 'm', 'desde' => '2026-09-30'],
        ]]);
        $casos = [
            ['id' => 'T::ok', 'status' => 'passou', 'mensagem' => ''],
            ['id' => 'T::pulado', 'status' => 'pulado', 'mensagem' => ''],
            ['id' => 'T::falhou', 'status' => 'falhou', 'mensagem' => 'x'],
            ['id' => 'T::erro', 'status' => 'erro', 'mensagem' => 'y'],
            ['id' => 'T::conhecido', 'status' => 'falhou', 'mensagem' => 'z'],
        ];

        $falhas = EtapaPhpUnit::classificar($casos, 1, '', 'unit', $allowlist);

        $this->assertSame(['T::falhou', 'T::erro', 'T::conhecido'], array_map(fn ($f) => $f->id, $falhas));
        $this->assertNull($falhas[0]->conhecida);
        $this->assertNotNull($falhas[2]->conhecida);
    }

    public function testCodigoNaoZeroSemFalhaReprova(): void
    {
        $falhas = EtapaPhpUnit::classificar(
            [['id' => 'T::ok', 'status' => 'passou', 'mensagem' => '']],
            1,
            "linha 1\nThere was 1 PHPUnit warning:\n1) teste disparou warning",
            'unit',
            Allowlist::deArray([])
        );

        $this->assertCount(1, $falhas);
        $this->assertSame('phpunit:unit', $falhas[0]->id);
        $this->assertStringContainsString('código 1', $falhas[0]->mensagem);
        $this->assertStringContainsString('warning', $falhas[0]->mensagem);
    }

    public function testCodigoZeroSemFalhaPassa(): void
    {
        $this->assertSame([], EtapaPhpUnit::classificar([], 0, '', 'unit', Allowlist::deArray([])));
    }
}
```

`tests/Unit/Support/EtapaLegadoTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use Tests\Support\Allowlist;
use Tests\Support\Env;
use Tests\Support\Gate\EtapaLegado;
use Tests\Support\Gate\Resultado;

final class EtapaLegadoTest extends TestCase
{
    private string $raiz;

    protected function setUp(): void
    {
        $this->raiz = sys_get_temp_dir() . '/gate-legado-' . bin2hex(random_bytes(4));
        $arquivos = [
            'tests/modulo/passa_test.php' => '<?php exit(0);',
            'tests/modulo/falha_test.php' => '<?php fwrite(STDERR, "FAIL: regra X"); exit(1);',
            'tests/modulo/sem_env_test.php' => '<?php fwrite(STDERR, "SISCONIECP_TEST_DSN não configurado"); exit(2);',
            'tests/modulo/le_env_test.php' => '<?php exit(getenv("SISCONIECP_TEST_DSN") === "mysql:dbname=sisconiecp_test" ? 0 : 1);',
            'tests/modulo/auxiliar.php' => '<?php exit(1);',
            'tests/Unit/NaoLegado_test.php' => '<?php exit(1);',
            'tests/Support/x_test.php' => '<?php exit(1);',
            'tests/out/y_test.php' => '<?php exit(1);',
        ];
        foreach ($arquivos as $caminho => $conteudo) {
            @mkdir(dirname($this->raiz . '/' . $caminho), 0777, true);
            file_put_contents($this->raiz . '/' . $caminho, $conteudo);
        }
    }

    protected function tearDown(): void
    {
        $it = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($this->raiz, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST
        );
        foreach ($it as $item) {
            $item->isDir() ? rmdir($item->getPathname()) : unlink($item->getPathname());
        }
        rmdir($this->raiz);
    }

    public function testDescobreSoLegadosForaDasPastasNovas(): void
    {
        $this->assertSame([
            'tests/modulo/falha_test.php',
            'tests/modulo/le_env_test.php',
            'tests/modulo/passa_test.php',
            'tests/modulo/sem_env_test.php',
        ], EtapaLegado::descobrir($this->raiz));
    }

    public function testClassificaPorCodigoDeSaida(): void
    {
        $env = Env::deTexto('SISCONIECP_TEST_DSN=mysql:dbname=sisconiecp_test');

        $r = (new EtapaLegado($this->raiz, $env, Allowlist::deArray([])))->executar();

        $this->assertSame(Resultado::REPROVOU, $r->status);
        $this->assertCount(1, $r->falhas);
        $this->assertSame('legado::tests/modulo/falha_test.php', $r->falhas[0]->id);
        $this->assertStringContainsString('regra X', $r->falhas[0]->mensagem);
        $this->assertStringContainsString('2 passaram', $r->observacao);
        $this->assertStringContainsString('1 pulado(s)', $r->observacao);
        $this->assertStringContainsString('sem_env_test.php', $r->observacao);
    }

    public function testFalhaNaAllowlistNaoReprova(): void
    {
        $allowlist = Allowlist::deArray(['falhas_conhecidas' => [
            ['id' => 'legado::tests/modulo/falha_test.php', 'motivo' => 'm', 'desde' => '2026-09-30'],
        ]]);

        $r = (new EtapaLegado($this->raiz, Env::vazio(), $allowlist))->executar();

        // le_env_test.php reprova sem a variável; filtra para checar só a conhecida.
        $conhecida = array_values(array_filter($r->falhas, fn ($f) => $f->id === 'legado::tests/modulo/falha_test.php'));
        $this->assertNotNull($conhecida[0]->conhecida);
    }
}
```

- [ ] **Step 2: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter "EtapaPreflightTest|EtapaLintTest|EtapaPhpUnitTest|EtapaLegadoTest"`
Expected: erros `Class "Tests\Support\Gate\Etapa..." not found`.

- [ ] **Step 3: Implementar `tests/Support/Gate/EtapaPreflight.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use PDO;
use RuntimeException;
use Tests\Support\Env;
use Throwable;

final class EtapaPreflight implements Etapa
{
    /** @var callable(string): int */
    private $sondaHttp;

    /** @var callable(string, string, string): void */
    private $sondaBanco;

    public function __construct(
        private readonly Env $env,
        private readonly bool $arquivoEnvExiste,
        private readonly bool $exigeServidor,
        ?callable $sondaHttp = null,
        ?callable $sondaBanco = null,
    ) {
        $this->sondaHttp = $sondaHttp ?? [self::class, 'statusHttp'];
        $this->sondaBanco = $sondaBanco ?? [self::class, 'conectarBanco'];
    }

    public function nome(): string
    {
        return 'preflight';
    }

    public function executar(): Resultado
    {
        if (!$this->exigeServidor) {
            return new Resultado($this->nome(), Resultado::PASSOU, [], $this->arquivoEnvExiste
                ? 'modo sem servidor'
                : 'modo sem servidor; tests/.env.local ausente (legados de banco serão pulados)');
        }
        if (!$this->arquivoEnvExiste) {
            return $this->abortar('tests/.env.local não encontrado. Copie tests/.env.example e preencha.');
        }

        try {
            $base = $this->env->baseUrl();
        } catch (RuntimeException $e) {
            return $this->abortar($e->getMessage());
        }

        $status = ($this->sondaHttp)($base . '/index.php');
        if ($status === 0 || $status >= 500) {
            return $this->abortar("Apache não respondeu em {$base}/index.php (status {$status}). Inicie o WAMP.");
        }

        try {
            ($this->sondaBanco)(
                $this->env->exigir('GATE_LOCAL_DSN'),
                $this->env->exigir('GATE_LOCAL_READ_USER'),
                (string) $this->env->get('GATE_LOCAL_READ_PASSWORD')
            );
        } catch (Throwable $e) {
            return $this->abortar('MySQL indisponível com GATE_LOCAL_READ_USER: ' . $e->getMessage());
        }

        return new Resultado($this->nome(), Resultado::PASSOU, [], "Apache e MySQL respondendo ({$base})");
    }

    public static function statusHttp(string $url): int
    {
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 10,
        ]);
        curl_exec($curl);

        return (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    }

    public static function conectarBanco(string $dsn, string $usuario, string $senha): void
    {
        new PDO($dsn, $usuario, $senha, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 5]);
    }

    private function abortar(string $mensagem): Resultado
    {
        return new Resultado($this->nome(), Resultado::ABORTOU, [new Falha('preflight', $mensagem)]);
    }
}
```

- [ ] **Step 4: Implementar `tests/Support/Gate/EtapaLint.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use RuntimeException;

final class EtapaLint implements Etapa
{
    private const IGNORAR = '~^(vendor|node_modules|backup|tinymce)/~';

    /** @var callable(): list<string> */
    private $listarArquivos;

    public function __construct(private readonly string $raiz, ?callable $listarArquivos = null)
    {
        $this->listarArquivos = $listarArquivos ?? fn (): array => $this->alteradosNoGit();
    }

    public function nome(): string
    {
        return 'lint';
    }

    public function executar(): Resultado
    {
        $arquivos = array_values(array_filter(
            ($this->listarArquivos)(),
            fn (string $f): bool => str_ends_with(strtolower($f), '.php')
                && !preg_match(self::IGNORAR, str_replace('\\', '/', $f))
                && is_file($this->raiz . '/' . $f)
        ));
        if ($arquivos === []) {
            return new Resultado($this->nome(), Resultado::PASSOU, [], 'nenhum PHP alterado');
        }

        $falhas = [];
        foreach ($arquivos as $arquivo) {
            $r = Processo::executar([PHP_BINARY, '-l', $this->raiz . '/' . $arquivo], [], $this->raiz, 60);
            if ($r['codigo'] !== 0) {
                $falhas[] = new Falha('lint::' . $arquivo, trim($r['saida']));
            }
        }

        return Resultado::deFalhas($this->nome(), $falhas, count($arquivos) . ' arquivo(s) PHP verificado(s)');
    }

    /** @return list<string> */
    private function alteradosNoGit(): array
    {
        $alterados = Processo::executar(
            ['git', '-c', 'diff.ignoreSubmodules=all', 'diff', '--name-only', 'HEAD'],
            [],
            $this->raiz,
            60
        );
        $novos = Processo::executar(['git', 'ls-files', '--others', '--exclude-standard'], [], $this->raiz, 60);
        if ($alterados['codigo'] !== 0 || $novos['codigo'] !== 0) {
            throw new RuntimeException('git indisponível para listar arquivos alterados: ' . trim($alterados['saida'] . $novos['saida']));
        }

        return array_values(array_unique(array_filter(array_map(
            'trim',
            preg_split('/\R/', $alterados['saida'] . "\n" . $novos['saida']) ?: []
        ))));
    }
}
```

- [ ] **Step 5: Implementar `tests/Support/Gate/EtapaPhpUnit.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use Tests\Support\Allowlist;
use Tests\Support\JunitReader;

final class EtapaPhpUnit implements Etapa
{
    /** @param array<string, string> $env */
    public function __construct(
        private readonly string $raiz,
        private readonly string $suite,
        private readonly Allowlist $allowlist,
        private readonly array $env = [],
    ) {
    }

    public function nome(): string
    {
        return $this->suite;
    }

    public function executar(): Resultado
    {
        $junit = $this->raiz . '/tests/out/junit-' . $this->suite . '.xml';
        if (!is_dir(dirname($junit))) {
            mkdir(dirname($junit), 0777, true);
        }
        @unlink($junit);

        $r = Processo::executar([
            PHP_BINARY,
            $this->raiz . '/vendor/bin/phpunit',
            '--configuration', $this->raiz . '/phpunit.xml',
            '--testsuite', $this->suite,
            '--log-junit', $junit,
        ], $this->env, $this->raiz, 1800);

        $casos = is_file($junit) ? JunitReader::ler($junit) : [];
        $falhas = self::classificar($casos, $r['codigo'], $r['saida'], $this->suite, $this->allowlist);
        $contagem = array_count_values(array_column($casos, 'status'));

        return Resultado::deFalhas($this->nome(), $falhas, sprintf(
            '%d teste(s): %d passaram, %d pulados',
            count($casos),
            $contagem['passou'] ?? 0,
            $contagem['pulado'] ?? 0
        ));
    }

    /**
     * @param list<array{id: string, status: string, mensagem: string}> $casos
     * @return list<Falha>
     */
    public static function classificar(array $casos, int $codigo, string $saida, string $suite, Allowlist $allowlist): array
    {
        $falhas = [];
        foreach ($casos as $caso) {
            if ($caso['status'] === 'falhou' || $caso['status'] === 'erro') {
                $falhas[] = new Falha($caso['id'], $caso['mensagem'], $allowlist->explicar($caso['id']));
            }
        }

        // Warning, deprecation ou fatal antes do log: o JUnit não mostra, mas o código de saída sim.
        if ($codigo !== 0 && $falhas === []) {
            $cauda = implode("\n", array_slice(preg_split('/\R/', trim($saida)) ?: [], -30));
            $falhas[] = new Falha("phpunit:{$suite}", "PHPUnit saiu com código {$codigo} sem falha no JUnit:\n{$cauda}");
        }

        return $falhas;
    }
}
```

- [ ] **Step 6: Implementar `tests/Support/Gate/EtapaLegado.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Gate;

use FilesystemIterator;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use Tests\Support\Allowlist;
use Tests\Support\Env;
use Throwable;

/**
 * Roda os scripts de teste avulsos que existiam antes do portão.
 * Convenção herdada: exit 0 passou, exit 2 ambiente não configurado (pulado).
 */
final class EtapaLegado implements Etapa
{
    private const PASTAS_NOVAS = ['Unit', 'Http', 'Integrity', 'e2e', 'Support', 'out'];

    public function __construct(
        private readonly string $raiz,
        private readonly Env $env,
        private readonly Allowlist $allowlist,
    ) {
    }

    public function nome(): string
    {
        return 'legado';
    }

    /** @return list<string> */
    public static function descobrir(string $raiz): array
    {
        $base = $raiz . '/tests';
        $encontrados = [];
        $iterador = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($base, FilesystemIterator::SKIP_DOTS));
        foreach ($iterador as $arquivo) {
            $relativo = str_replace('\\', '/', substr($arquivo->getPathname(), strlen($base) + 1));
            $primeiraPasta = explode('/', $relativo)[0];
            if (in_array($primeiraPasta, self::PASTAS_NOVAS, true) || !str_contains($relativo, '/')) {
                continue;
            }
            if (preg_match('/_test\.(php|js|py)$/', $arquivo->getFilename())) {
                $encontrados[] = 'tests/' . $relativo;
            }
        }
        sort($encontrados);

        return $encontrados;
    }

    public function executar(): Resultado
    {
        $falhas = [];
        $passaram = 0;
        $pulados = [];
        foreach (self::descobrir($this->raiz) as $script) {
            $id = 'legado::' . $script;
            try {
                $r = Processo::executar(
                    [$this->interpretador($script), $this->raiz . '/' . $script],
                    $this->env->todos(),
                    $this->raiz,
                    300
                );
            } catch (Throwable $e) {
                $falhas[] = new Falha($id, $e->getMessage(), $this->allowlist->explicar($id));
                continue;
            }

            if ($r['codigo'] === 0) {
                $passaram++;
            } elseif ($r['codigo'] === 2) {
                $pulados[] = basename($script);
            } else {
                $cauda = implode("\n", array_slice(preg_split('/\R/', trim($r['saida'])) ?: [], -20));
                $motivo = $r['estourou'] ? "Tempo esgotado (300 s).\n{$cauda}" : "Saiu com código {$r['codigo']}.\n{$cauda}";
                $falhas[] = new Falha($id, $motivo, $this->allowlist->explicar($id));
            }
        }

        $observacao = "{$passaram} passaram";
        if ($pulados !== []) {
            $observacao .= '; ' . count($pulados) . ' pulado(s) por ambiente: ' . implode(', ', $pulados);
        }

        return Resultado::deFalhas($this->nome(), $falhas, $observacao);
    }

    private function interpretador(string $script): string
    {
        return match (pathinfo($script, PATHINFO_EXTENSION)) {
            'php' => PHP_BINARY,
            'js' => 'node',
            'py' => 'python',
        };
    }
}
```

Nota: sem `tests/.env.local`, `Env::vazio()->todos()` é `[]` e `Processo` repassa o ambiente herdado; os legados de banco saem com 2 e ficam como pulados.

- [ ] **Step 7: Rodar os testes das etapas**

Run: `php vendor/bin/phpunit --testsuite unit --filter "EtapaPreflightTest|EtapaLintTest|EtapaPhpUnitTest|EtapaLegadoTest"`
Expected: `OK`.

- [ ] **Step 8: Implementar `tests/gate.php`**

```php
<?php

declare(strict_types=1);

/*
 * Portão pré-deploy. Uso:
 *   php tests/gate.php            todas as etapas (exige WAMP e tests/.env.local)
 *   php tests/gate.php --fast     lint + unit + legados, sem servidor
 *   php tests/gate.php --suite=unit   uma etapa (preflight roda sempre antes)
 * Saída: 0 aprovado, 1 reprovado, 2 pré-requisito ausente.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/bootstrap.php';

use Tests\Support\Allowlist;
use Tests\Support\Env;
use Tests\Support\Gate\EtapaLegado;
use Tests\Support\Gate\EtapaLint;
use Tests\Support\Gate\EtapaPhpUnit;
use Tests\Support\Gate\EtapaPreflight;
use Tests\Support\Gate\Relatorio;
use Tests\Support\Gate\Resultado;
use Tests\Support\Gate\Runner;

$opcoes = getopt('', ['fast', 'suite:']);
$rapido = isset($opcoes['fast']);
$suite = isset($opcoes['suite']) ? (string) $opcoes['suite'] : null;

$raiz = dirname(__DIR__);
$arquivoEnv = __DIR__ . '/.env.local';
$env = is_file($arquivoEnv) ? Env::carregar($arquivoEnv) : Env::vazio();
$allowlist = Allowlist::carregar(__DIR__ . '/allowlist.php');

// Ordem de execução. Planos 2–4 acrescentam: contas, http, integrity-read, integrity-write, e2e.
$semServidor = ['lint', 'unit', 'legado'];
$etapas = [
    'lint' => new EtapaLint($raiz),
    'unit' => new EtapaPhpUnit($raiz, 'unit', $allowlist),
    'legado' => new EtapaLegado($raiz, $env, $allowlist),
];

if ($suite !== null && !isset($etapas[$suite])) {
    fwrite(STDERR, "Etapa desconhecida: {$suite}. Disponíveis: " . implode(', ', array_keys($etapas)) . PHP_EOL);
    exit(2);
}
if ($suite !== null) {
    $etapas = [$suite => $etapas[$suite]];
} elseif ($rapido) {
    $etapas = array_intersect_key($etapas, array_flip($semServidor));
}

$exigeServidor = array_diff(array_keys($etapas), $semServidor) !== [];
$preflight = new EtapaPreflight($env, is_file($arquivoEnv), $exigeServidor);

$runner = new Runner(array_values([$preflight, ...array_values($etapas)]));
$resultados = $runner->executar(static function (Resultado $r, float $segundos): void {
    fwrite(STDOUT, rtrim(Relatorio::terminal([$r])) . sprintf(' (%.1f s)', $segundos) . PHP_EOL);
});

// Em execução parcial, só as entradas da allowlist dessas etapas contam para "sem uso".
$prefixos = ['lint' => 'lint::', 'unit' => 'Tests\\Unit\\', 'legado' => 'legado::'];
$allowlistRelatorio = $allowlist;
if ($suite !== null || $rapido) {
    $relevantes = array_values(array_filter(
        $allowlist->falhasConhecidas(),
        static function (array $entrada) use ($etapas, $prefixos): bool {
            foreach (array_keys($etapas) as $nome) {
                if (isset($prefixos[$nome]) && str_starts_with($entrada['id'], $prefixos[$nome])) {
                    return true;
                }
            }

            return false;
        }
    ));
    $allowlistRelatorio = Allowlist::deArray(['falhas_conhecidas' => $relevantes, 'publicos' => $allowlist->publicos()]);
}

$relatorio = __DIR__ . '/out/gate-report.md';
if (!is_dir(dirname($relatorio))) {
    mkdir(dirname($relatorio), 0777, true);
}
file_put_contents($relatorio, Relatorio::markdown($resultados, $allowlistRelatorio, new DateTimeImmutable('now')));

$codigo = Runner::codigoSaida($resultados);
fwrite(STDOUT, PHP_EOL . ['APROVADO', 'REPROVADO', 'PRÉ-REQUISITO AUSENTE'][$codigo] . ' — relatório: tests/out/gate-report.md' . PHP_EOL);
exit($codigo);
```

Nota: cada plano seguinte acrescenta seu prefixo em `$prefixos` (ex.: `'http' => 'Tests\\Http\\'`).

- [ ] **Step 9: Rodar a suíte `unit` inteira**

Run: `php vendor/bin/phpunit --testsuite unit`
Expected: `FAILURES!` apenas com os 2 testes da allowlist (`testImagemBase64PermitidaQuandoHabilitada` e `testCnpjValido with data set "alfanumerico-com-mascara"`) mais quaisquer falhas anotadas nas Tasks 2–5 (que também já devem estar na allowlist). Nenhum warning/deprecation.

Se aparecer warning ou deprecation vindo de `classes/`: **não** crie entrada `phpunit:unit` na allowlist (ela esconderia qualquer warning novo). Anote arquivo e linha e relate ao humano antes de seguir.

- [ ] **Step 10: Rodar o portão em modo rápido**

Run: `php tests/gate.php --fast; echo "exit=$?"`
Expected (formato; números variam):
```
PASSOU    preflight — modo sem servidor; tests/.env.local ausente (...) (0.0 s)
PASSOU    lint — nenhum PHP alterado (0.4 s)
PASSOU    unit — 0 nova(s), 2 conhecida(s); 3xx teste(s): ... (8.0 s)
PASSOU    legado — N passaram; M pulado(s) por ambiente: ... (20.0 s)

APROVADO — relatório: tests/out/gate-report.md
exit=0
```
`unit` deve mostrar `0 nova(s)` e pelo menos 2 conhecidas. `legado` pode reprovar (ver abaixo); nesse caso a última linha é `REPROVADO` e `exit=1`. Abra `tests/out/gate-report.md` e confira que as falhas conhecidas aparecem com motivo.

Se `legado` reprovar: **não** corrija os scripts antigos nem o código de produção. Leia a mensagem no relatório; se o motivo é defeito real já existente, acrescente entrada `legado::tests/...` na allowlist com o motivo e relate ao humano; se é problema do runner (interpretador não encontrado, caminho), corrija `EtapaLegado`.

- [ ] **Step 11: Verificar o bloqueio web**

Run: `curl -s -o /dev/null -w "%{http_code}\n" http://localhost/sisconiecp2/tests/gate.php`
Expected: `403` (se o WAMP estiver ligado; com WAMP desligado, pule e anote).

- [ ] **Step 12: Commit**

```bash
rtk git add tests/gate.php tests/Support/Gate/EtapaPreflight.php tests/Support/Gate/EtapaLint.php tests/Support/Gate/EtapaPhpUnit.php tests/Support/Gate/EtapaLegado.php tests/Unit/Support/EtapaPreflightTest.php tests/Unit/Support/EtapaLintTest.php tests/Unit/Support/EtapaPhpUnitTest.php tests/Unit/Support/EtapaLegadoTest.php tests/allowlist.php
rtk git commit -m "test: gate.php com preflight, lint, unit e scripts legados

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Usuário MySQL de leitura e verificação do modo completo (humano + agente)

**Files:**
- Create: `tests/README.md`

**Interfaces:**
- Consumes: `tests/gate.php` (Task 8).
- Produces: documentação de uso; usuário `gate_leitura` que os Planos 2 e 3 usam.

- [ ] **Step 1: Escrever `tests/README.md`**

````markdown
# Portão pré-deploy

Rode antes de subir arquivos para o HostGator. Reprovou = não sobe.

```powershell
php tests/gate.php --fast   # lint + unit + legados, sem WAMP (~1 min)
php tests/gate.php          # tudo; exige WAMP ligado e tests/.env.local
php tests/gate.php --suite=unit
```

Saída: `0` aprovado, `1` reprovado, `2` pré-requisito ausente. Relatório em `tests/out/gate-report.md`.

## Configuração (uma vez)

1. Copie `tests/.env.example` para `tests/.env.local` e preencha.
2. No MySQL local, como root, crie o usuário de leitura:

```sql
CREATE USER 'gate_leitura'@'localhost' IDENTIFIED BY 'troque-esta-senha';
GRANT SELECT ON conie847_sisconiecp.* TO 'gate_leitura'@'localhost';
```

3. Para os legados de banco (`tests/portaria`, `tests/pagamento15`), siga `tests/portaria/README.md` (banco `sisconiecp_test`).

## Falhas conhecidas

`tests/allowlist.php` lista reprovações aceitas temporariamente, cada uma com motivo e data.
Ao corrigir o defeito, apague a entrada. O relatório lista entradas sem uso.
Nunca adicione entrada sem motivo: o portão recusa carregar.

## Adicionar teste

- Classe de segurança: `tests/Unit/Security/<Nome>Test.php` (namespace `Tests\Unit\Security`).
- Payloads de ataque: reutilize `Tests\Support\Payloads`.
- Script avulso antigo (`*_test.php|js|py`): roda sozinho; use exit 2 para "ambiente não configurado".
````

- [ ] **Step 2: (Humano) criar o usuário de leitura e o `tests/.env.local`**

Peça ao humano para executar o SQL do README como root e preencher `tests/.env.local` (`GATE_BASE_URL`, `GATE_LOCAL_*` e, se já existir o banco `sisconiecp_test`, `SISCONIECP_TEST_*`). O agente não cria usuários MySQL. O Plano 1 ainda não usa `GATE_LOCAL_*` (nenhuma etapa exige servidor); o usuário fica pronto para os Planos 2 e 3.

- [ ] **Step 3: Verificar que o `.env.local` chega aos legados**

Run: `php tests/gate.php --suite=legado; echo "exit=$?"`
Expected: `PASSOU preflight — modo sem servidor` e, se `SISCONIECP_TEST_*` foi preenchido, a lista de "pulado(s) por ambiente" de `legado` fica menor do que no Step 10 da Task 8 (os testes de `portaria/` e `pagamento15/` passam a rodar). Se continuarem pulados, confira as credenciais do `sisconiecp_test` com o humano.

A recusa de host externo no modo completo só é observável quando o Plano 2 registrar a etapa `http` (a primeira que exige servidor). Neste plano ela está coberta por `EtapaPreflightTest::testHostExternoAbortaSemTocarRede`.

- [ ] **Step 4: Commit**

```bash
rtk git add tests/README.md
rtk git commit -m "docs: como rodar e configurar o portão pré-deploy

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Cobertura do spec neste plano

| Spec | Onde |
|---|---|
| §1 critérios: exit 0/1/2, `--fast`, relatório, host local | Tasks 1, 7, 8 |
| §3 estrutura, `.env.local`, ordem 1–4 e 9, flags | Tasks 1, 7, 8 |
| §4 validação de segurança (todas as classes da tabela) | Tasks 2–5 |
| §9 falhas e relatório, `.gitignore` | Tasks 1, 7, 8 |
| §10 allowlist com motivo e data | Tasks 6, 7 |
| §3 etapas 5–8, §5, §6, §7, §8, §11 (Playwright, usuário de escrita) | Planos 2, 3 e 4 |
