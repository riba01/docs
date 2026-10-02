# Portão pré-deploy — Plano 2a/4: Catálogo de endpoints e cliente HTTP

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status (2026-10-01): plano PARCIAL, escopo redefinido.** Só as Tasks 1–2 estão escritas e são executáveis. A redação das tasks seguintes (contas `TESTE_GATE`, etapa `http`, autenticação, autorização/IDOR, CSRF dinâmico) foi interrompida e ficou com o humano — ver "Pendente (a escrever pelo humano)" ao final. As seções abaixo que citam Tasks 3–7 descrevem o desenho combinado, não tasks prontas.

**Goal:** Acrescentar ao portão um catálogo estático dos endpoints que reprova handler novo que grava sem CSRF ou recebe POST sem guarda de sessão (Task 1), e o cliente HTTP que as tasks seguintes vão usar (Task 2).

**Architecture:** `Tests\Support\Http\Catalogo` varre os `.php` servidos pela web (descontando o que o `.htaccess` bloqueia) e classifica por regex; os testes estáticos rodam na suíte `unit` (entram no `--fast`). Falhas atuais ficam em `tests/Http/conhecidos.json` (lista de base): reprova item **novo** e item listado que **já não falha**. Desenho combinado para as tasks pendentes: a etapa `http` (`EtapaHttp`) abre o banco local com a conexão do próprio sistema (`config/database.local.php`), cria as contas (`ContasTeste`), passa as credenciais à suíte PHPUnit `http` por arquivo temporário (`GATE_CONTAS`) e remove tudo em `finally`, acusando sobras.

**Tech Stack:** PHP 8.5 CLI, PHPUnit 13.2, curl, MySQL 5.7.44 (WAMP), PDO.

**Spec:** `docs/superpowers/specs/2026-09-30-testes-seguranca-integridade-design.md` (seções 5 e 8)

**Planos da série:** 1 (feito) → **2a (este)** → 2b HTTP restante (regras do balancete, exposição, headers, força bruta, SQLi/XSS, upload) → 3 (feito) → 4 Playwright.

**Branch:** criar `testes/portao-2a-http` a partir de `main` antes da Task 1.

## Global Constraints

- Convenções dos Planos 1 e 3 continuam: `declare(strict_types=1)` em todo PHP novo; nada em `composer.json`/`vendor`; **código de produção não é alterado** — defeito real encontrado vira item da lista de base e é relatado.
- Nenhum teste fala com host que não seja `localhost`/`127.0.0.1` (`Env::garantirHostLocal`, já existente).
- Escrita no banco local **só** por `ContasTeste`, **só** em linhas das entidades `TESTE_GATE` (IECP com nome `TESTE_GATE ...`, e-mail `teste_gate_<chave>@invalid.local`). Conexão: a do sistema (`config/database.local.php`) — decisão do humano em 2026-09-30 (recusou criar `gate_escrita`). Backup com `mysqldump` antes da primeira execução (Task 4).
- CSRF dinâmico **só** em handlers apontados para entidades de teste. Nunca enviar POST sem token a handler que não esteja na lista curada da Task 7: handler desprotegido grava de verdade (decisão do humano em 2026-10-01: estático + dinâmico curado).
- Falha conhecida = item em `tests/Http/conhecidos.json` (decisão do humano em 2026-10-01: lista de base, não allowlist por entrada). Item listado que passa a funcionar reprova com "apague a linha".
- A suíte `http` **falha** (não pula) sem `GATE_CONTAS`: rodada fora do portão não pode aprovar em silêncio.
- Etapa `http` roda **depois** de `integrity-read`/`integrity-write`: as contas de teste nunca existem durante as checagens de integridade.
- Git: commits com `git commit -F <arquivo-de-mensagem>`; PHP com barra invertida escrito com a ferramenta Write, nunca heredoc do Bash (o heredoc come `\`).
- Commits terminam com `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Fatos verificados em 2026-10-01 (usados pelas tasks)

- **Login** (`index.php` → `login.php`): campos `csrf_token`, `email`, `senha`, `perfil`. Token único por sessão (`$_SESSION['csrf_token']`, 64 hex), nunca rotacionado; `login.php` não limpa a sessão, então o token raspado do `index.php` antes do login continua válido depois. Token inválido → `302 index.php`; credencial errada → `302 erro.php`; sucesso → `session_regenerate_id(true)` e `302 painel.php`. **Sem limite de tentativas.**
- **Cookie de sessão** em `http://localhost`: `SISCONIECP` (o `__Host-SISCONIECP` só sob HTTPS), `use_strict_mode=1`.
- **Conta que chega ao painel** precisa de: `login.senha` = `password_hash()` com `login.password_updated = 1`; `cadastroministro.acesso = 'liberado'` (padrão da coluna é `'bloqueado'`); `idStatusMinistro` em {1,4,5,6}; linha em `aceite_termo (rm, versao)` com `versao = Classes\TermoConsentimento::versaoVigente($pdo)`; `historicofuncao` aberto (`dataFim NULL`) cuja função dá o nível certo.
- **Perfis** (`perfil` do POST → `defineNivel.php`), funções escolhidas e nível obtido pela tabela `perfil`: CONIECP `perfil=1`, função 1 → nível 1; IECP `perfil=2`, função 9 → nível 2 (exige `idCongregacao = 0`, senão `validar_usuario_iecp.php` manda para `pertenceCong.php`); Congregação `perfil=8`, função 20 → nível 8 (exige congregação ativa); Usuário `perfil=9`, função 12 → nível 7; EBD `perfil=9`, função 17 → nível 11 (com `idCongregacao = 0`).
- **`painel.php?pagina=<caminho sem .php>`** não confere login: só faz `require` do arquivo; a guarda é a do próprio arquivo (`valida_sessao_all.php` + `validar_usuario_<area>.php`). `GET painel.php` (home) roda o `validar_usuario_<área>` do perfil, que grava `$_SESSION['idIecp']`/`['idCongregacao']` — os handlers do balancete dependem disso.
- **Guardas por área:** `validar_usuario_coniecp.php` exige nível 1 (falha: `Location: restrita.php` **sem `exit`**); `_iecp` exige 2/3/4 e `idCongregacao = 0`; `_congregacao` exige 6/8/9/10/11/12 e congregação ativa com `idCongregacao > 0`; `_ebd` aceita 2/3/6/8/9/11/12; `_usuario` aceita 1..13.
- **Tabelas tocadas por uma conta** (sem FK, `STRICT_ALL_TABLES`): `iecp`, `congregacao`, `cadastroministro`, `login`, `historicofuncao`, `aceite_termo`; a cada login o sistema grava `registrovisita`, `user_login`, `user_sessions` (todas com coluna `rm`).
- **Balancete IECP** (`balancete`/`itembalancete`) e **congregação** (`balancete_congregacao`/`itembalancete_congregacao`): status editáveis `Em Elaboracao`/`Devolvido`. Handlers protegidos (CSRF + nível + dono pela sessão): `iecp/tesouraria/balanceteMensal/{incluirReceita,deleteItemBalancete,modificaStatusBalancete}.php` e `congregacao/tesouraria/balanceteMensal/{incluirReceita,deleteItemBalancete}.php`. **Desprotegido:** `congregacao/tesouraria/balanceteMensal/modificaStatusBalancete.php` (sem CSRF, sem nível, sem conferir dono — usa `listar()`, não `listarSeguro()`). Campo `dia` vai como `dd/mm/aaaa`; `valor` como `10,00`.
- O envio de status de congregação só valida meses anteriores a partir do mês de fundação: congregação com `dataFundacao` no 1º dia do mês corrente e balancete do mês corrente passa direto para a gravação.
- **Ficha de ministro:** `iecp/ministro/ficha-Ministro/fichaMinistro.php` (POST `rm`) mostra **qualquer** ministro, de qualquer IECP (`dadosMinistro/dados.php` filtra só por `rm`). `congregacao/membro/ficha-Ministro/fichaMinistro.php` confere IECP e congregação da sessão. Os dois fazem `JOIN` com `cargo`, `statusministro` e `escolaridade`: o ministro de teste precisa de `idCargo`/`idEscola` existentes. O nome é exibido com `ucwords()`.
- **Catálogo medido no working tree em 2026-10-01** com o código da Task 1 e os públicos da Task 1: 1160 `.php` servidos, 496 recebem POST, **108** gravam sem CSRF, **369** recebem POST sem guarda de sessão. Diferença de poucas unidades na `main` é esperada (o working tree tinha um branch de outra frente).

## Review Focus

Item 4 é coberto pela Task 1. Itens 1, 2, 3 e 5 são requisitos para as tasks pendentes.

1. Limpeza que apaga dado real (prefixo casando nome legítimo, id reaproveitado) → `ContasTeste` só apaga ids que **voltam a casar** o prefixo numa consulta própria, nunca um id recebido de fora. Teste em Task 3 (`ContasTesteSqlTest::testFiltraIdsPeloPrefixo`).
2. `config/database.local.php` apontando para servidor remoto ou outro banco → `ConexaoEscrita` recusa antes de conectar. Teste em Task 3 (`ConexaoEscritaTest`).
3. Suíte `http` reprova no meio (exceção, timeout) e deixa contas no banco → `EtapaHttp` remove em `finally` e acusa sobras; a próxima execução ainda limpa resíduos pelo prefixo. Teste em Task 4 (`EtapaHttpTest::testRemoveMesmoQuandoASuiteLanca`).
4. Lista de base que absorve falha nova ou guarda item já corrigido → teste estático compara nos dois sentidos. Teste em Task 1 (`ConhecidosTest::testComparaNosDoisSentidos`).
5. Teste dinâmico que "passa" porque o pedido foi recusado por outro motivo (sessão sem `idIecp`, balancete já enviado) → cada caso CSRF/IDOR tem controle positivo (o mesmo pedido, com token e alvo próprio, grava de verdade) e restaura as fixtures antes. Teste em Task 7 (`CsrfTest::testControlePositivo*`) e Task 6 (`IdorTest`).

---

## Estrutura de arquivos

Tasks 1–2 criam as linhas de `Catalogo` a `HttpClient`, `CatalogoSegurancaTest` e os testes de `tests/Unit/Support/`, e alteram `tests/allowlist.php`. As demais linhas são do desenho combinado (tasks pendentes).

| Arquivo                                          | Responsabilidade                                                                 |
| ------------------------------------------------ | -------------------------------------------------------------------------------- |
| `tests/Support/Http/Catalogo.php`                | varre e classifica endpoints (POST, grava, CSRF, guarda, público)                |
| `tests/Support/Http/Conhecidos.php`              | lê `tests/Http/conhecidos.json`; compara encontrados × listados                  |
| `tests/Http/conhecidos.json`                     | lista de base: `csrf_ausente`, `sem_guarda_de_sessao`, `casos_http`              |
| `tests/Support/Http/Resposta.php`                | status, cabeçalhos, corpo, `Location`, JSON, texto visível                       |
| `tests/Support/Http/HttpClient.php`              | curl com cookie em memória, só host local, login com token                       |
| `tests/Support/Http/ConexaoEscrita.php`          | PDO do sistema com travas de host e banco                                        |
| `tests/Support/Http/Contas.php`                  | dados das contas/entidades criadas (ida e volta em JSON)                         |
| `tests/Support/Http/ContasTeste.php`             | cria, restaura fixtures, remove e acusa sobras                                   |
| `tests/Support/Gate/EtapaHttp.php`               | contas → suíte `http` → remoção em `finally`                                     |
| `tests/Http/Attack/CasoHttp.php`                 | base dos testes HTTP: contas, clientes, banco, verificação contra conhecidos      |
| `tests/Http/Attack/*Test.php`                    | autenticação, autorização, IDOR, CSRF                                            |
| `tests/Unit/Estatico/CatalogoSegurancaTest.php`  | catálogo × lista de base (roda no `--fast`)                                      |
| `tests/Unit/Support/*Test.php`                   | testes sem rede/banco das peças acima                                            |
| `tests/allowlist.php`, `phpunit.xml`, `tests/gate.php`, `tests/README.md`, `tests/.env.example` | registrar públicos, suíte e etapa |

---

### Task 1: Catálogo estático e lista de base

**Files:**

- Create: `tests/Support/Http/Catalogo.php`
- Create: `tests/Support/Http/Conhecidos.php`
- Create: `tests/Http/conhecidos.json`
- Modify: `tests/allowlist.php` (chave `publicos`)
- Test: `tests/Unit/Support/CatalogoTest.php`
- Test: `tests/Unit/Support/ConhecidosTest.php`
- Test: `tests/Unit/Estatico/CatalogoSegurancaTest.php`

**Interfaces:**

- Consumes: `Tests\Support\BloqueiosWeb::doArquivo(string)`, `::doTexto(string)`, `->caminhoBloqueado(string): bool` (Plano 1); `Tests\Support\Allowlist::carregar(string)->publicos(): list<string>` (Plano 1).
- Produces:
    - `new Catalogo(string $raiz, BloqueiosWeb $bloqueios, list<string> $publicos)`; `->arquivos(): list<string>`; `->handlersPost(): list<string>`; `->gravamSemCsrf(): list<string>`; `->semGuardaDeSessao(): list<string>`; `->ehPublico(string): bool`; estáticos `recebePost(string $fonte): bool`, `grava(string): bool`, `validaCsrf(string): bool`, `temGuardaDeSessao(string): bool`.
    - `Conhecidos::carregar(string $arquivo): Conhecidos`; `::deArray(array): Conhecidos`; `Conhecidos::CATEGORIAS = ['csrf_ausente', 'sem_guarda_de_sessao', 'casos_http']`; `->lista(string $categoria): list<string>`; `->conhecido(string $categoria, string $item): bool`; `->comparar(string $categoria, list<string> $encontrados): array{novos: list<string>, resolvidos: list<string>}`.

- [ ] **Step 1: Criar o branch**

```bash
git switch main
git switch -c testes/portao-2a-http
```

- [ ] **Step 2: Escrever `tests/Unit/Support/CatalogoTest.php` (RED)**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Support\BloqueiosWeb;
use Tests\Support\Http\Catalogo;

final class CatalogoTest extends TestCase
{
    private string $raiz;

    protected function setUp(): void
    {
        $this->raiz = SISCONIECP_RAIZ . '/tests/out/catalogo-' . bin2hex(random_bytes(4));
        $arquivos = [
            'protegido.php' => "<?php require 'valida_sessao_all.php'; if (!Csrf::validateToken(\$_POST['t'])) { exit; } \$q = 'INSERT INTO t';",
            'publico.php' => "<?php \$x = \$_POST['a']; \$pdo->exec('DELETE FROM t');",
            'leitura.php' => "<?php require 'validar_usuario_iecp.php'; \$id = \$_POST['id']; \$q = 'SELECT * FROM t';",
            'sub/aberto.php' => "<?php \$x = \$_POST['a']; \$pdo->exec('DELETE FROM t');",
            'sub/velho_old.php' => "<?php \$x = \$_POST['a']; \$pdo->exec('DELETE FROM t');",
            'sub/so_get.php' => "<?php \$x = \$_GET['a'];",
            'vendor/lib.php' => "<?php \$x = \$_POST['a'];",
            'tests/t.php' => "<?php \$x = \$_POST['a'];",
            'classes/C.php' => "<?php \$x = \$_FILES['a'];",
            'sub/leia.txt' => '$_POST',
        ];
        foreach ($arquivos as $nome => $conteudo) {
            $caminho = $this->raiz . '/' . $nome;
            if (!is_dir(dirname($caminho))) {
                mkdir(dirname($caminho), 0777, true);
            }
            file_put_contents($caminho, $conteudo);
        }
    }

    protected function tearDown(): void
    {
        $iterador = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($this->raiz, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST
        );
        foreach ($iterador as $item) {
            $item->isDir() ? rmdir($item->getPathname()) : unlink($item->getPathname());
        }
        rmdir($this->raiz);
    }

    private function catalogo(): Catalogo
    {
        $bloqueios = BloqueiosWeb::doTexto("<FilesMatch \"_old\\.php$\">\n    Require all denied\n</FilesMatch>\n");

        return new Catalogo($this->raiz, $bloqueios, ['publico.php']);
    }

    public function testArquivosIgnoraExcluidosEBloqueados(): void
    {
        $this->assertSame(
            ['leitura.php', 'protegido.php', 'publico.php', 'sub/aberto.php', 'sub/so_get.php'],
            $this->catalogo()->arquivos()
        );
    }

    public function testHandlersPostIgnoraPublicosESoGet(): void
    {
        $this->assertSame(['leitura.php', 'protegido.php', 'sub/aberto.php'], $this->catalogo()->handlersPost());
    }

    public function testGravamSemCsrf(): void
    {
        $this->assertSame(['sub/aberto.php'], $this->catalogo()->gravamSemCsrf());
    }

    public function testSemGuardaDeSessao(): void
    {
        $this->assertSame(['sub/aberto.php'], $this->catalogo()->semGuardaDeSessao());
    }

    public static function publicos(): array
    {
        return [
            'exato' => ['login.php', true],
            'curinga' => ['autenticador/aut.php', true],
            'prefixo nao basta' => ['xlogin.php', false],
            'outra pasta' => ['iecp/login.php', false],
        ];
    }

    #[DataProvider('publicos')]
    public function testEhPublico(string $relativo, bool $esperado): void
    {
        $catalogo = new Catalogo($this->raiz, BloqueiosWeb::doTexto(''), ['login.php', 'autenticador/*']);
        $this->assertSame($esperado, $catalogo->ehPublico($relativo));
    }

    public static function fontes(): array
    {
        return [
            'post' => ['recebePost', "\$a = \$_POST['x'];", true],
            'input post' => ['recebePost', "filter_input(INPUT_POST, 'x')", true],
            'arquivo' => ['recebePost', "\$_FILES['foto']", true],
            'json' => ['recebePost', "file_get_contents('php://input')", true],
            'get nao' => ['recebePost', "\$_GET['x']", false],
            'insert' => ['grava', 'INSERT INTO login', true],
            'update' => ['grava', 'UPDATE `login` SET senha = 1', true],
            'delete' => ['grava', 'DELETE FROM login', true],
            'metodo' => ['grava', '$item->inserir();', true],
            'estatico' => ['grava', 'Recibo_iecp::excluirPorItem($id);', true],
            'upload' => ['grava', 'move_uploaded_file($a, $b);', true],
            'select nao' => ['grava', 'SELECT * FROM login', false],
            'listar nao' => ['grava', '$b->listar($id);', false],
            'csrf classe' => ['validaCsrf', "Csrf::validateToken(\$_POST['csrf_token'])", true],
            'csrf assinatura' => ['validaCsrf', 'AssinaturaAutorizacao::validarCsrf($t);', true],
            'csrf ata' => ['validaCsrf', 'ataRequireCsrf();', true],
            'csrf inline' => ['validaCsrf', "hash_equals((string)(\$_SESSION['csrf_token'] ?? ''), \$x)", true],
            'csrf so leitura da sessao' => ['validaCsrf', "\$t = \$_SESSION['csrf_token'];", false],
            'guarda sessao' => ['temGuardaDeSessao', "require 'valida_sessao_all.php';", true],
            'guarda area' => ['temGuardaDeSessao', "include_once('validar_usuario_iecp.php');", true],
            'guarda 401' => ['temGuardaDeSessao', 'http_response_code(401);', true],
            'guarda redirect' => ['temGuardaDeSessao', "header('Location: login.php');", true],
            'session_start nao' => ['temGuardaDeSessao', 'session_start();', false],
        ];
    }

    #[DataProvider('fontes')]
    public function testClassificacaoDaFonte(string $metodo, string $fonte, bool $esperado): void
    {
        $this->assertSame($esperado, Catalogo::{$metodo}($fonte));
    }
}
```

- [ ] **Step 3: Escrever `tests/Unit/Support/ConhecidosTest.php` (RED)**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Http\Conhecidos;

final class ConhecidosTest extends TestCase
{
    public function testCategoriaAusenteViraListaVazia(): void
    {
        $c = Conhecidos::deArray(['csrf_ausente' => ['a.php']]);
        $this->assertSame(['a.php'], $c->lista('csrf_ausente'));
        $this->assertSame([], $c->lista('casos_http'));
        $this->assertTrue($c->conhecido('csrf_ausente', 'a.php'));
        $this->assertFalse($c->conhecido('csrf_ausente', 'b.php'));
    }

    public function testComparaNosDoisSentidos(): void
    {
        $c = Conhecidos::deArray(['csrf_ausente' => ['a.php', 'b.php']]);
        $this->assertSame(
            ['novos' => ['c.php'], 'resolvidos' => ['a.php']],
            $c->comparar('csrf_ausente', ['b.php', 'c.php'])
        );
    }

    public static function invalidos(): array
    {
        return [
            'categoria desconhecida' => [['outra' => []]],
            'nao lista' => [['csrf_ausente' => ['x' => 'a.php']]],
            'item vazio' => [['csrf_ausente' => ['']]],
            'item nao texto' => [['csrf_ausente' => [1]]],
            'curinga' => [['csrf_ausente' => ['iecp/*']]],
            'repetido' => [['csrf_ausente' => ['a.php', 'a.php']]],
        ];
    }

    #[DataProvider('invalidos')]
    public function testRecusaListaInvalida(array $dados): void
    {
        $this->expectException(RuntimeException::class);
        Conhecidos::deArray($dados);
    }

    public function testRecusaCategoriaDesconhecidaNaConsulta(): void
    {
        $this->expectException(RuntimeException::class);
        Conhecidos::deArray([])->lista('outra');
    }

    public function testArquivoAusenteFalha(): void
    {
        $this->expectException(RuntimeException::class);
        Conhecidos::carregar(SISCONIECP_RAIZ . '/tests/out/nao-existe.json');
    }
}
```

- [ ] **Step 4: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter "CatalogoTest|ConhecidosTest"`
Expected: FAIL/ERROR com `Class "Tests\Support\Http\Catalogo" not found` e `Class "Tests\Support\Http\Conhecidos" not found`.

- [ ] **Step 5: Implementar `tests/Support/Http/Catalogo.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Http;

use FilesystemIterator;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use Tests\Support\BloqueiosWeb;

/**
 * Catálogo estático dos endpoints (spec §5): varre os .php servidos pela web
 * e classifica quem recebe POST, quem grava, quem valida CSRF e quem exige
 * sessão. Arquivo novo entra sozinho, sem editar teste.
 */
final class Catalogo
{
    /** Fora do catálogo: dependências, testes e bibliotecas incluídas (classes/ não é endpoint). */
    private const PASTAS_EXCLUIDAS = '~^(vendor|node_modules|backup|tinymce|tests|docs|classes|\.git)/~';

    private const RECEBE_POST = '~\$_POST|\$_FILES|\bINPUT_POST\b|php://input~';

    private const GRAVA = '~\b(INSERT\s+INTO|UPDATE\s+`?\w+`?\s+SET|DELETE\s+FROM|REPLACE\s+INTO)\b'
        . '|\bmove_uploaded_file\s*\(|\bfile_put_contents\s*\(|\bunlink\s*\('
        . '|(->|::)\s*(inserir|incluir|cadastrar|alterar|atualizar|excluir|deletar|remover|salvar|gravar|registrar|mudaStatus|finalizar)\w*\s*\(~i';

    private const VALIDA_CSRF = '~Csrf::validateToken\s*\(|\bvalidarCsrf\s*\(|\bataRequireCsrf\s*\('
        . '|\brecoveryRequestCsrfIsValid\s*\(|\bresetPasswordCsrfIsValid\s*\(|\bvalidarTokenCsrfAutenticador\s*\('
        . '|hash_equals\s*\(\s*\(string\)\s*\(\s*\$_SESSION\[\s*[\'"]csrf_token[\'"]\s*\]~';

    private const GUARDA_SESSAO = '~\bvalida_sessao\w*\.php|\bvalidar_usuario\w*\.php'
        . '|http_response_code\s*\(\s*40[13]\s*\)'
        . '|Location:\s*[^\'"]*\b(login|index|restrita|acessoBloqueado)\.php~i';

    /** @var list<string>|null */
    private ?array $cache = null;

    /** @param list<string> $publicos caminhos relativos (curinga * permitido) acessíveis sem login */
    public function __construct(
        private readonly string $raiz,
        private readonly BloqueiosWeb $bloqueios,
        private readonly array $publicos,
    ) {
    }

    /** @return list<string> .php servidos pela web, relativos à raiz, em ordem */
    public function arquivos(): array
    {
        if ($this->cache !== null) {
            return $this->cache;
        }
        $lista = [];
        $iterador = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($this->raiz, FilesystemIterator::SKIP_DOTS)
        );
        foreach ($iterador as $arquivo) {
            if (strtolower($arquivo->getExtension()) !== 'php') {
                continue;
            }
            $relativo = str_replace('\\', '/', substr($arquivo->getPathname(), strlen($this->raiz) + 1));
            if (preg_match(self::PASTAS_EXCLUIDAS, $relativo) || $this->bloqueios->caminhoBloqueado($relativo)) {
                continue;
            }
            $lista[] = $relativo;
        }
        sort($lista, SORT_STRING);

        return $this->cache = $lista;
    }

    /** @return list<string> recebem POST/arquivo e não são públicos */
    public function handlersPost(): array
    {
        return array_values(array_filter(
            $this->arquivos(),
            fn (string $rel): bool => !$this->ehPublico($rel) && self::recebePost($this->fonte($rel))
        ));
    }

    /** @return list<string> */
    public function gravamSemCsrf(): array
    {
        return array_values(array_filter($this->handlersPost(), function (string $rel): bool {
            $fonte = $this->fonte($rel);

            return self::grava($fonte) && !self::validaCsrf($fonte);
        }));
    }

    /** @return list<string> */
    public function semGuardaDeSessao(): array
    {
        return array_values(array_filter(
            $this->handlersPost(),
            fn (string $rel): bool => !self::temGuardaDeSessao($this->fonte($rel))
        ));
    }

    public function ehPublico(string $relativo): bool
    {
        foreach ($this->publicos as $padrao) {
            $regex = '~^' . str_replace('\*', '.*', preg_quote($padrao, '~')) . '$~';
            if (preg_match($regex, $relativo) === 1) {
                return true;
            }
        }

        return false;
    }

    public static function recebePost(string $fonte): bool
    {
        return preg_match(self::RECEBE_POST, $fonte) === 1;
    }

    public static function grava(string $fonte): bool
    {
        return preg_match(self::GRAVA, $fonte) === 1;
    }

    public static function validaCsrf(string $fonte): bool
    {
        return preg_match(self::VALIDA_CSRF, $fonte) === 1;
    }

    public static function temGuardaDeSessao(string $fonte): bool
    {
        return preg_match(self::GUARDA_SESSAO, $fonte) === 1;
    }

    private function fonte(string $relativo): string
    {
        return (string) file_get_contents($this->raiz . '/' . $relativo);
    }
}
```

- [ ] **Step 6: Implementar `tests/Support/Http/Conhecidos.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Http;

use RuntimeException;

/**
 * Falhas de segurança conhecidas do portão HTTP (lista de base, decisão de
 * 2026-10-01). O teste reprova item NOVO e também item listado que já não
 * falha: apagar a linha mantém a lista honesta.
 */
final class Conhecidos
{
    public const CATEGORIAS = ['csrf_ausente', 'sem_guarda_de_sessao', 'casos_http'];

    /** @param array<string, list<string>> $listas */
    private function __construct(private readonly array $listas)
    {
    }

    public static function carregar(string $arquivo): self
    {
        if (!is_file($arquivo)) {
            throw new RuntimeException('Lista de conhecidos não encontrada: ' . $arquivo);
        }
        $dados = json_decode((string) file_get_contents($arquivo), true);
        if (!is_array($dados)) {
            throw new RuntimeException('Lista de conhecidos com JSON inválido: ' . $arquivo);
        }

        return self::deArray($dados);
    }

    public static function deArray(array $dados): self
    {
        $extras = array_diff(array_keys($dados), self::CATEGORIAS);
        if ($extras !== []) {
            throw new RuntimeException('Categoria desconhecida em conhecidos: ' . implode(', ', $extras));
        }
        $listas = [];
        foreach (self::CATEGORIAS as $categoria) {
            $lista = $dados[$categoria] ?? [];
            if (!is_array($lista) || !array_is_list($lista)) {
                throw new RuntimeException("conhecidos.{$categoria} deve ser uma lista.");
            }
            foreach ($lista as $item) {
                if (!is_string($item) || trim($item) === '' || str_contains($item, '*')) {
                    throw new RuntimeException("conhecidos.{$categoria}: item vazio, não textual ou com curinga.");
                }
            }
            if (count($lista) !== count(array_unique($lista))) {
                throw new RuntimeException("conhecidos.{$categoria}: item repetido.");
            }
            $listas[$categoria] = $lista;
        }

        return new self($listas);
    }

    /** @return list<string> */
    public function lista(string $categoria): array
    {
        if (!in_array($categoria, self::CATEGORIAS, true)) {
            throw new RuntimeException('Categoria desconhecida: ' . $categoria);
        }

        return $this->listas[$categoria];
    }

    public function conhecido(string $categoria, string $item): bool
    {
        return in_array($item, $this->lista($categoria), true);
    }

    /**
     * @param list<string> $encontrados
     * @return array{novos: list<string>, resolvidos: list<string>}
     */
    public function comparar(string $categoria, array $encontrados): array
    {
        $lista = $this->lista($categoria);

        return [
            'novos' => array_values(array_diff($encontrados, $lista)),
            'resolvidos' => array_values(array_diff($lista, $encontrados)),
        ];
    }
}
```

- [ ] **Step 7: Rodar os testes unitários (GREEN)**

Run: `php vendor/bin/phpunit --testsuite unit --filter "CatalogoTest|ConhecidosTest"`
Expected: PASS (todos).

- [ ] **Step 8: Registrar os públicos em `tests/allowlist.php`**

Substituir o trecho final

```php
    // Plano 2: rotas acessíveis sem login (caminho relativo à raiz).
    'publicos' => [],
```

por

```php
    // Rotas acessíveis sem login (caminho relativo à raiz; curinga * permitido).
    // Ficam fora das checagens de guarda de sessão e CSRF do catálogo.
    'publicos' => [
        'index.php',
        'login.php',
        'logout.php',
        'erro.php',
        'esqueci-senha.php',
        'redefinir-senha.php',
        'politica-privacidade.php',
        'csp-report.php',
        'autenticador/*',
    ],
```

- [ ] **Step 9: Gerar a lista de base inicial**

Criar com a ferramenta Write o arquivo descartável `tests/out/gerar-conhecidos.php` (`tests/out/` é ignorado pelo git):

```php
<?php

declare(strict_types=1);

require __DIR__ . '/../bootstrap.php';

use Tests\Support\Allowlist;
use Tests\Support\BloqueiosWeb;
use Tests\Support\Http\Catalogo;

$catalogo = new Catalogo(
    SISCONIECP_RAIZ,
    BloqueiosWeb::doArquivo(SISCONIECP_RAIZ . '/.htaccess'),
    Allowlist::carregar(SISCONIECP_RAIZ . '/tests/allowlist.php')->publicos()
);
$dados = [
    'csrf_ausente' => $catalogo->gravamSemCsrf(),
    'sem_guarda_de_sessao' => $catalogo->semGuardaDeSessao(),
    'casos_http' => [],
];
if (!is_dir(SISCONIECP_RAIZ . '/tests/Http')) {
    mkdir(SISCONIECP_RAIZ . '/tests/Http', 0777, true);
}
file_put_contents(
    SISCONIECP_RAIZ . '/tests/Http/conhecidos.json',
    json_encode($dados, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . PHP_EOL
);
printf("csrf_ausente=%d sem_guarda_de_sessao=%d\n", count($dados['csrf_ausente']), count($dados['sem_guarda_de_sessao']));
```

Run: `php tests/out/gerar-conhecidos.php` e depois apagar `tests/out/gerar-conhecidos.php`.
Expected: `csrf_ausente=108 sem_guarda_de_sessao=369` (poucas unidades de diferença na `main` são aceitáveis — ver "Fatos verificados"). Conferir que `tests/Http/conhecidos.json` contém `congregacao/tesouraria/balanceteMensal/modificaStatusBalancete.php` e `coniecp/tesouraria/balanceteMensalConiecp/incluirReceita.php` em `csrf_ausente`, e **não** contém nada sob `backup/`, nem `login.php`. Este script não é versionado: a lista só cresce à mão daqui em diante.

- [ ] **Step 10: Escrever `tests/Unit/Estatico/CatalogoSegurancaTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Estatico;

use PHPUnit\Framework\TestCase;
use Tests\Support\Allowlist;
use Tests\Support\BloqueiosWeb;
use Tests\Support\Http\Catalogo;
use Tests\Support\Http\Conhecidos;

/**
 * Spec §5: handler novo que recebe POST entra sozinho nas checagens de CSRF
 * e de sessão. A lista de base (tests/Http/conhecidos.json) guarda o legado.
 */
final class CatalogoSegurancaTest extends TestCase
{
    private static Catalogo $catalogo;

    private static Conhecidos $conhecidos;

    public static function setUpBeforeClass(): void
    {
        self::$catalogo = new Catalogo(
            SISCONIECP_RAIZ,
            BloqueiosWeb::doArquivo(SISCONIECP_RAIZ . '/.htaccess'),
            Allowlist::carregar(SISCONIECP_RAIZ . '/tests/allowlist.php')->publicos()
        );
        self::$conhecidos = Conhecidos::carregar(SISCONIECP_RAIZ . '/tests/Http/conhecidos.json');
    }

    public function testCatalogoEnxergaOsAlvosEsperados(): void
    {
        $post = self::$catalogo->handlersPost();
        $this->assertContains('iecp/tesouraria/balanceteMensal/incluirReceita.php', $post);
        $this->assertNotContains('login.php', $post, 'login.php é público');
        foreach ($post as $relativo) {
            $this->assertDoesNotMatchRegularExpression('~(^|/)backup/~', $relativo, 'pasta bloqueada pelo .htaccess entrou no catálogo');
        }
    }

    public function testHandlerQueGravaValidaCsrf(): void
    {
        $r = self::$conhecidos->comparar('csrf_ausente', self::$catalogo->gravamSemCsrf());
        $this->assertSame([], $r['novos'], "Handler novo grava sem validar CSRF (use Classes\\Csrf::validateToken):\n" . implode("\n", $r['novos']));
    }

    public function testListaCsrfSemItensResolvidos(): void
    {
        $r = self::$conhecidos->comparar('csrf_ausente', self::$catalogo->gravamSemCsrf());
        $this->assertSame([], $r['resolvidos'], "Já validam CSRF ou saíram do catálogo; apague de tests/Http/conhecidos.json (csrf_ausente):\n" . implode("\n", $r['resolvidos']));
    }

    public function testHandlerPostExigeSessao(): void
    {
        $r = self::$conhecidos->comparar('sem_guarda_de_sessao', self::$catalogo->semGuardaDeSessao());
        $this->assertSame([], $r['novos'], "Handler novo recebe POST sem guarda de sessão (valida_sessao_all.php + validar_usuario_<área>.php):\n" . implode("\n", $r['novos']));
    }

    public function testListaGuardaSemItensResolvidos(): void
    {
        $r = self::$conhecidos->comparar('sem_guarda_de_sessao', self::$catalogo->semGuardaDeSessao());
        $this->assertSame([], $r['resolvidos'], "Já têm guarda ou saíram do catálogo; apague de tests/Http/conhecidos.json (sem_guarda_de_sessao):\n" . implode("\n", $r['resolvidos']));
    }
}
```

- [ ] **Step 11: Rodar a suíte unit inteira**

Run: `php tests/gate.php --suite=unit`
Expected: `PASSOU    unit` (650 + os novos). Se `testCatalogoEnxergaOsAlvosEsperados` falhar por `backup/`, a regra do `.htaccess` mudou — parar e relatar.

- [ ] **Step 12: Commit**

```bash
git add tests/Support/Http/Catalogo.php tests/Support/Http/Conhecidos.php tests/Http/conhecidos.json tests/allowlist.php tests/Unit/Support/CatalogoTest.php tests/Unit/Support/ConhecidosTest.php tests/Unit/Estatico/CatalogoSegurancaTest.php
git commit -F <mensagem: "test: catálogo de endpoints com lista de base de CSRF e guarda de sessão">
```

---

### Task 2: Cliente HTTP

**Files:**

- Create: `tests/Support/Http/Resposta.php`
- Create: `tests/Support/Http/HttpClient.php`
- Test: `tests/Unit/Support/HttpClientTest.php`

**Interfaces:**

- Consumes: `Tests\Support\Env::garantirHostLocal(string $url): void` (Plano 1; lança `RuntimeException`).
- Produces:
    - `Resposta`: propriedades `readonly int $status`, `readonly array $cabecalhos` (`array<string, list<string>>`, nome em minúsculas), `readonly string $corpo`; `Resposta::deBruto(int $status, string $cabecalhosBrutos, string $corpo): Resposta`; `->cabecalho(string $nome): ?string` (último valor); `->location(): ?string`; `->json(): ?array`; `->textoVisivel(): string` (sem `<script>`/`<style>`, sem tags, espaços colapsados); `->redireciona(): bool` (3xx com `Location`).
    - `HttpClient`: `COOKIE_SESSAO = 'SISCONIECP'`; `new HttpClient(string $baseUrl)` (lança se host não local); `->get(string $caminho, array $query = []): Resposta`; `->post(string $caminho, array $campos): Resposta`; `->cookieSessao(): ?string`; `->definirCookieSessao(string $valor): void`; `->entrar(string $email, string $senha, int $perfil, bool $comToken = true): Resposta` (GET `index.php`, guarda o token, POST `login.php`); `->token(): string` (token CSRF da sessão; lança se ainda não houve `entrar`); `HttpClient::extrairCsrf(string $html): ?string`.

- [ ] **Step 1: Escrever `tests/Unit/Support/HttpClientTest.php` (RED)**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Http\HttpClient;
use Tests\Support\Http\Resposta;

final class HttpClientTest extends TestCase
{
    public function testRecusaHostExterno(): void
    {
        $this->expectException(RuntimeException::class);
        new HttpClient('https://swga.coniecp.com.br');
    }

    public function testExtraiTokenDoCampoOculto(): void
    {
        $token = str_repeat('ab12', 16);
        $html = '<form><input type="hidden" name="csrf_token" id="csrf_token" value="' . $token . '"></form>';
        $this->assertSame($token, HttpClient::extrairCsrf($html));
    }

    public function testTokenAusenteOuForaDoFormato(): void
    {
        $this->assertNull(HttpClient::extrairCsrf('<input name="csrf_token" value="curto">'));
        $this->assertNull(HttpClient::extrairCsrf('<p>sem formulário</p>'));
    }

    public function testTokenSemLoginLanca(): void
    {
        $this->expectException(RuntimeException::class);
        (new HttpClient('http://localhost/sisconiecp2'))->token();
    }

    public function testRespostaLeCabecalhosERedirecionamento(): void
    {
        $brutos = "HTTP/1.1 302 Found\r\nLocation: painel.php\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nX-Powered-By: PHP\r\n\r\n";
        $r = Resposta::deBruto(302, $brutos, '');
        $this->assertSame('painel.php', $r->location());
        $this->assertTrue($r->redireciona());
        $this->assertSame(['a=1', 'b=2'], $r->cabecalhos['set-cookie']);
        $this->assertSame('PHP', $r->cabecalho('X-Powered-By'));
        $this->assertNull($r->cabecalho('content-type'));
    }

    public function testRespostaUsaOsCabecalhosDaUltimaResposta(): void
    {
        $brutos = "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n";
        $r = Resposta::deBruto(200, $brutos, '{"success":false}');
        $this->assertSame('application/json', $r->cabecalho('content-type'));
        $this->assertSame(['success' => false], $r->json());
        $this->assertFalse($r->redireciona());
    }

    public function testTextoVisivelIgnoraScriptEstiloETags(): void
    {
        $html = "<html><head><style>p{}</style><script>var x = 'segredo';</script></head><body><p>Olá\n  mundo</p></body></html>";
        $this->assertSame('Olá mundo', Resposta::deBruto(200, '', $html)->textoVisivel());
    }

    public function testJsonInvalidoViraNull(): void
    {
        $this->assertNull(Resposta::deBruto(200, '', '<html>')->json());
    }
}
```

- [ ] **Step 2: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter HttpClientTest`
Expected: ERROR `Class "Tests\Support\Http\HttpClient" not found`.

- [ ] **Step 3: Implementar `tests/Support/Http/Resposta.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Http;

final class Resposta
{
    /** @param array<string, list<string>> $cabecalhos nomes em minúsculas */
    private function __construct(
        public readonly int $status,
        public readonly array $cabecalhos,
        public readonly string $corpo,
    ) {
    }

    /** Cabeçalhos brutos do curl; com 100-continue/redirecionamento vale o último bloco. */
    public static function deBruto(int $status, string $cabecalhosBrutos, string $corpo): self
    {
        $blocos = preg_split('/\r?\n\r?\n/', trim($cabecalhosBrutos)) ?: [];
        $ultimo = (string) end($blocos);
        $cabecalhos = [];
        foreach (preg_split('/\r?\n/', $ultimo) ?: [] as $linha) {
            if (!str_contains($linha, ':') || str_starts_with($linha, 'HTTP/')) {
                continue;
            }
            [$nome, $valor] = array_map('trim', explode(':', $linha, 2));
            $cabecalhos[strtolower($nome)][] = $valor;
        }

        return new self($status, $cabecalhos, $corpo);
    }

    public function cabecalho(string $nome): ?string
    {
        $valores = $this->cabecalhos[strtolower($nome)] ?? [];

        return $valores === [] ? null : $valores[array_key_last($valores)];
    }

    public function location(): ?string
    {
        return $this->cabecalho('location');
    }

    public function redireciona(): bool
    {
        return $this->status >= 300 && $this->status < 400 && $this->location() !== null;
    }

    public function json(): ?array
    {
        $dados = json_decode($this->corpo, true);

        return is_array($dados) ? $dados : null;
    }

    public function textoVisivel(): string
    {
        $sem = (string) preg_replace('~<(script|style)\b[^>]*>.*?</\1>~is', ' ', $this->corpo);
        $texto = html_entity_decode(strip_tags($sem), ENT_QUOTES | ENT_HTML5, 'UTF-8');

        return trim((string) preg_replace('/\s+/u', ' ', $texto));
    }
}
```

- [ ] **Step 4: Implementar `tests/Support/Http/HttpClient.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Http;

use CurlHandle;
use RuntimeException;
use Tests\Support\Env;

/**
 * Navegador mínimo do portão: um handle curl por instância (cookies em
 * memória, isolados entre instâncias), sem seguir redirecionamento, e só
 * para localhost/127.0.0.1.
 */
final class HttpClient
{
    public const COOKIE_SESSAO = 'SISCONIECP';

    private readonly string $base;

    private readonly CurlHandle $curl;

    private ?string $token = null;

    public function __construct(string $baseUrl)
    {
        Env::garantirHostLocal($baseUrl);
        $this->base = rtrim($baseUrl, '/');
        $this->curl = curl_init();
        curl_setopt_array($this->curl, [
            CURLOPT_COOKIEFILE => '',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HEADER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_USERAGENT => 'portao-sisconiecp/2a',
        ]);
    }

    /** @param array<string, scalar> $query */
    public function get(string $caminho, array $query = []): Resposta
    {
        $url = $this->url($caminho) . ($query === [] ? '' : (str_contains($caminho, '?') ? '&' : '?') . http_build_query($query));
        curl_setopt_array($this->curl, [CURLOPT_URL => $url, CURLOPT_HTTPGET => true]);

        return $this->executar();
    }

    /** @param array<string, scalar|list<scalar>> $campos */
    public function post(string $caminho, array $campos): Resposta
    {
        curl_setopt_array($this->curl, [
            CURLOPT_URL => $this->url($caminho),
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query($campos),
        ]);

        return $this->executar();
    }

    public function entrar(string $email, string $senha, int $perfil, bool $comToken = true): Resposta
    {
        $pagina = $this->get('index.php');
        $token = self::extrairCsrf($pagina->corpo);
        if ($token === null) {
            throw new RuntimeException('index.php não trouxe csrf_token (status ' . $pagina->status . ').');
        }
        $this->token = $token;
        $campos = ['email' => $email, 'senha' => $senha, 'perfil' => $perfil];
        if ($comToken) {
            $campos['csrf_token'] = $token;
        }

        return $this->post('login.php', $campos);
    }

    /** Token CSRF da sessão (o mesmo do formulário de login: o sistema não o rotaciona). */
    public function token(): string
    {
        if ($this->token === null) {
            throw new RuntimeException('Sem token: chame entrar() antes.');
        }

        return $this->token;
    }

    public function cookieSessao(): ?string
    {
        foreach (curl_getinfo($this->curl, CURLINFO_COOKIELIST) ?: [] as $linha) {
            $partes = explode("\t", $linha);
            if (count($partes) >= 7 && $partes[5] === self::COOKIE_SESSAO) {
                return $partes[6];
            }
        }

        return null;
    }

    public function definirCookieSessao(string $valor): void
    {
        $host = (string) parse_url($this->base, PHP_URL_HOST);
        curl_setopt($this->curl, CURLOPT_COOKIELIST, sprintf("%s\tFALSE\t/\tFALSE\t0\t%s\t%s", $host, self::COOKIE_SESSAO, $valor));
    }

    public static function extrairCsrf(string $html): ?string
    {
        if (preg_match('~name="csrf_token"[^>]*value="([0-9a-f]{64})"~', $html, $m)) {
            return $m[1];
        }

        return null;
    }

    private function url(string $caminho): string
    {
        return $this->base . '/' . ltrim($caminho, '/');
    }

    private function executar(): Resposta
    {
        $bruto = curl_exec($this->curl);
        if ($bruto === false) {
            throw new RuntimeException('Falha HTTP: ' . curl_error($this->curl));
        }
        $tamanho = (int) curl_getinfo($this->curl, CURLINFO_HEADER_SIZE);
        $status = (int) curl_getinfo($this->curl, CURLINFO_RESPONSE_CODE);

        return Resposta::deBruto($status, substr((string) $bruto, 0, $tamanho), substr((string) $bruto, $tamanho));
    }
}
```

- [ ] **Step 5: Rodar (GREEN)**

Run: `php vendor/bin/phpunit --testsuite unit --filter HttpClientTest`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add tests/Support/Http/Resposta.php tests/Support/Http/HttpClient.php tests/Unit/Support/HttpClientTest.php
git commit -F <mensagem: "test: cliente HTTP do portão com cookie isolado e host local">
```

---

## Pendente (a escrever pelo humano)

Tasks não redigidas neste documento. O desenho combinado está em "Global Constraints", "Fatos verificados" e "Review Focus".

| Task | Assunto | Notas |
| --- | --- | --- |
| 3 | `ConexaoEscrita` + `ContasTeste` + `Contas` | contas por perfil e entidades `TESTE_GATE` (2 IECPs, 2 congregações, balancetes do mês corrente); remoção só de ids que voltam a casar o prefixo; varredura de sobras por `rm`/`idIecp`/`idCongregacao` |
| 4 | `EtapaHttp` + suíte `http` no `phpunit.xml` + registro no `gate.php` (depois de `integrity-*`) | `mysqldump` do banco local antes da 1ª execução; remoção em `finally`; prefixo `Tests\Http\` no filtro de allowlist do `gate.php` |
| 5 | Autenticação | sem sessão não acessa; ID de sessão muda no login; cookie antigo morto após logout; login sem token não autentica |
| 6 | Autorização por perfil e IDOR | matriz derivada das guardas listadas em "Fatos verificados"; amostra com entidades de teste |
| 7 | CSRF dinâmico curado | só handlers da lista curada, com controle positivo e fixtures restauradas |
| 8 | Rodar o portão, preencher `casos_http`, README, relatório | |

Depois: Plano 2b (regras do balancete, exposição, headers, força bruta, SQLi/XSS refletido, upload).
