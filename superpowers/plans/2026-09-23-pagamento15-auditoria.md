# Pagamentos de 15% — auditoria cruzada: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir a tela "Pagamentos de 15%" (CONIECP e IECP) por uma tela única, com números corretos, situação por célula, detalhamento com comprovantes, exportação e impressão.

**Architecture:** Três classes PHP separam regras puras (`Pagamento15Regras`), consultas somente-leitura com PDO injetado (`Pagamento15`) e montagem do JSON (`Pagamento15Relatorio`). Três endpoints JSON (POST + CSRF) servem um partial de marcação comum às duas páginas; um módulo JS único renderiza tabelas, indicadores, gráficos ECharts, notas, diálogo de detalhamento, CSV e impressão.

**Tech Stack:** PHP 8.4, MySQL 5.7 (sem `REGEXP_SUBSTR`), PDO, jQuery 3.7.1 (`vendor/components/jquery`), ECharts (`node_modules/echarts/dist/echarts.min.js`), testes como scripts PHP em `tests/<modulo>/`.

**Spec:** `docs/superpowers/specs/2026-09-23-pagamento15-auditoria-design.md` (ler inteira antes de começar).

## Global Constraints

- Defasagem: balancete IECP de (ano, mês) → mês CONIECP (ano, mês+1); dezembro → janeiro do ano seguinte.
- Mês de referência sempre `balancete.mes/ano`, `balancete_congregacao.mes/ano`, `balancete_coniecp.mes/ano` — nunca a data do item.
- Declarado = grupo 21 da sede + congregações. Devido = 15% de `tipoContabil = 1` exceto grupos 32 e 34. Registrado = grupo 1 (`tipoContabil = 1`) da CONIECP.
- Identificação na CONIECP: `idIecp ≠ 0` → CNPJ da descrição em `iecp_cnpj_historico` vigente na data → CNPJ atual de `iecp` → "Registrado sem IECP identificada".
- Só `Finalizado` é definitivo. Situações: `futuro`, `aguardando_coniecp`, `aguardando_iecp`, `provisorio`, `definitivo` (precedência nessa ordem).
- Divergência: `|diferença| ≥ R$ 0,01` com cada lado arredondado a 2 casas.
- `IECPS_EXCLUIDAS = [15]`, somente por lista de ids.
- **Nunca** executar UPDATE/DELETE nos livros (`itembalancete*`, `balancete*`). Todo acesso a dados desta feature é SELECT, exceto a migração da tabela nova.
- Sempre `PDO::FETCH_ASSOC` explícito (o `Connect` usa `FETCH_OBJ` como padrão). Prepared statements; sem `SELECT *`.
- Saída HTML com `htmlspecialchars`; no JS, dados sempre via `textContent`/propriedades, nunca `innerHTML` com dado.
- Linguagem neutra; mesmos textos nas páginas CONIECP e IECP.
- Layout Bootstrap do projeto: `<div class="row">`, nunca `row g-0`.
- Git: o repositório principal tem milhares de alterações anteriores. **Nunca** `git add .`/`-A`; adicionar só os caminhos da tarefa. Prefixar comandos git com `rtk` (CLAUDE.md do projeto).
- Antes de mexer em `classes/`, ler `docs/claude/contexto-classes.md`.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `sql/migrate_iecp_cnpj_historico_20260923.php` (novo) | Cria `iecp_cnpj_historico` e insere a carga inicial; idempotente |
| `sql/schema.sql` (alterar) | Registrar a tabela nova |
| `classes/Pagamento15Regras.php` (novo) | Regras puras: calendário, situação, CNPJ, diferença, validação de entrada, acesso, textos |
| `classes/Pagamento15.php` (novo) | Consultas somente-leitura (PDO injetado) |
| `classes/Pagamento15Relatorio.php` (novo) | Monta os payloads JSON (mensal, histórico, detalhamento) a partir dos arrays das consultas |
| `coniecp/tesouraria/reuniao_dados/api/_inicio.php` (novo) | Sessão, método, CSRF, perfil, resposta JSON, mapeamento de exceções |
| `coniecp/tesouraria/reuniao_dados/api/dadosMensal.php` (novo) | Ano + IECP |
| `coniecp/tesouraria/reuniao_dados/api/dadosHistorico.php` (novo) | Janela de 10 anos + IECP |
| `coniecp/tesouraria/reuniao_dados/api/dadosLancamentos.php` (novo) | Detalhamento de uma célula |
| `coniecp/tesouraria/reuniao_dados/partials/pagamento15.php` (novo) | Marcação comum às duas páginas |
| `coniecp/tesouraria/reuniao_dados/css/pagamento15.css` (novo) | Estilos, tokens, impressão |
| `coniecp/tesouraria/reuniao_dados/js/pagamento15.js` (novo) | Comportamento da tela |
| `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php` (temporário) | Rota paralela para validação visual |
| `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15.php` (substituir no fim) | Página CONIECP fina |
| `iecp/tesouraria/reuniao_dados/tabela_pagamento_15.php` (substituir no fim) | Página IECP fina |
| `tests/pagamento15/assercoes.php` (novo) | Asserções e conexão de teste compartilhadas |
| `tests/pagamento15/pagamento15_regras_test.php` (novo) | Testes de `Pagamento15Regras` |
| `tests/pagamento15/pagamento15_relatorio_test.php` (novo) | Testes de `Pagamento15Relatorio` |
| `tests/pagamento15/pagamento15_consultas_test.php` (novo) | Testes de `Pagamento15` no `sisconiecp_test` |
| `tests/pagamento15/pagamento15_conferencia.php` (novo) | Conferência somente-leitura na base real |

---

### Task 0: Pré-requisito — banco de teste isolado (usuário)

Os testes de consultas usam o banco dedicado `sisconiecp_test` (padrão de `tests/portaria/README.md`). Ele **não existe** nesta máquina (verificado em 2026-09-23).

- [ ] **Step 1: Pedir ao usuário que crie o banco e o usuário de teste**

Mensagem ao usuário (ele executa no MySQL local do WAMP, como root):

```sql
CREATE DATABASE sisconiecp_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'sisconiecp_test'@'localhost' IDENTIFIED BY '<senha escolhida>';
GRANT ALL PRIVILEGES ON sisconiecp_test.* TO 'sisconiecp_test'@'localhost';
FLUSH PRIVILEGES;
```

E informar a senha escolhida (credencial local de teste, sem acesso ao banco real).

- [ ] **Step 2: Confirmar a conexão**

Run (Bash, trocando `<senha>`):
```bash
SISCONIECP_TEST_DSN='mysql:host=localhost;dbname=sisconiecp_test;charset=utf8mb4' SISCONIECP_TEST_DB_USER='sisconiecp_test' SISCONIECP_TEST_DB_PASSWORD='<senha>' php -r '$p=new PDO(getenv("SISCONIECP_TEST_DSN"),getenv("SISCONIECP_TEST_DB_USER"),getenv("SISCONIECP_TEST_DB_PASSWORD"));echo $p->query("SELECT DATABASE()")->fetchColumn(),PHP_EOL;'
```
Expected: `sisconiecp_test`

Se o usuário preferir não criar o banco agora, seguir as Tasks 1–3 e marcar a Task 4 como bloqueada até lá (a Task 6, conferência na base real, cobre as consultas de ponta a ponta).

---

### Task 1: Migração `iecp_cnpj_historico`

**Files:**
- Create: `sql/migrate_iecp_cnpj_historico_20260923.php`
- Modify: `sql/schema.sql` (inserir bloco antes da última linha `SET FOREIGN_KEY_CHECKS = 1;`)

**Interfaces:**
- Produces: tabela `iecp_cnpj_historico(id, idIecp, cnpj, vigente_de, vigente_ate, observacao, cadastradoEm)` com 2 linhas (IECP 6 / 29.178.753/0001-73 até 2014-09-30; IECP 14 / 00.000.000/0000-02 até 2020-04-30).

- [ ] **Step 1: Escrever a migração**

```php
<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/classes/Connect.php';

use Classes\Connect;

const TABELA_HISTORICO_CNPJ = 'iecp_cnpj_historico';
const CARGA_HISTORICO_CNPJ = [
    [
        'idIecp' => 6,
        'cnpj' => '29.178.753/0001-73',
        'vigente_de' => null,
        'vigente_ate' => '2014-09-30',
        'observacao' => 'Resende: CNPJ usado nas descrições da CONIECP até set/2014',
    ],
    [
        'idIecp' => 14,
        'cnpj' => '00.000.000/0000-02',
        'vigente_de' => null,
        'vigente_ate' => '2020-04-30',
        'observacao' => 'Pirapora: CNPJ provisório até o definitivo',
    ],
];

function falharMigracao(string $mensagem, int $codigo = 1): never
{
    fwrite(STDERR, $mensagem . PHP_EOL);
    exit($codigo);
}

function modoMigracao(array $argumentos): string
{
    if (count($argumentos) !== 2 || !in_array($argumentos[1], ['--dry-run', '--apply'], true)) {
        fwrite(STDOUT, "Uso: php sql/migrate_iecp_cnpj_historico_20260923.php --dry-run|--apply\n");
        exit(2);
    }

    return $argumentos[1];
}

function tabelaExiste(PDO $pdo, string $tabela): bool
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*)
           FROM information_schema.tables
          WHERE table_schema = DATABASE()
            AND table_name = :tabela'
    );
    $stmt->execute([':tabela' => $tabela]);

    return (int) $stmt->fetchColumn() > 0;
}

function linhaHistoricoExiste(PDO $pdo, int $idIecp, string $cnpj): bool
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM iecp_cnpj_historico WHERE idIecp = :idIecp AND cnpj = :cnpj'
    );
    $stmt->execute([':idIecp' => $idIecp, ':cnpj' => $cnpj]);

    return (int) $stmt->fetchColumn() > 0;
}

$modo = modoMigracao($argv);

try {
    $pdo = Connect::getInstance();
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $existe = tabelaExiste($pdo, TABELA_HISTORICO_CNPJ);

    if ($modo === '--dry-run') {
        fwrite(STDOUT, "DRY-RUN: nenhuma DDL ou DML será executada.\n");
        fwrite(STDOUT, $existe
            ? "A tabela iecp_cnpj_historico já existe.\n"
            : "Seria criada a tabela iecp_cnpj_historico.\n");
        foreach (CARGA_HISTORICO_CNPJ as $linha) {
            $jaExiste = $existe && linhaHistoricoExiste($pdo, $linha['idIecp'], $linha['cnpj']);
            fwrite(STDOUT, sprintf(
                "%s: IECP %d, CNPJ %s\n",
                $jaExiste ? 'Já existe' : 'Seria inserida',
                $linha['idIecp'],
                $linha['cnpj']
            ));
        }
        exit(0);
    }

    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS iecp_cnpj_historico (
            id INT NOT NULL AUTO_INCREMENT,
            idIecp INT NOT NULL,
            cnpj VARCHAR(18) NOT NULL,
            vigente_de DATE NULL,
            vigente_ate DATE NULL,
            observacao VARCHAR(255) NULL,
            cadastradoEm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_iecp_cnpj_historico_cnpj (cnpj),
            KEY idx_iecp_cnpj_historico_iecp (idIecp)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
    );

    $inserir = $pdo->prepare(
        'INSERT INTO iecp_cnpj_historico (idIecp, cnpj, vigente_de, vigente_ate, observacao)
         VALUES (:idIecp, :cnpj, :vigente_de, :vigente_ate, :observacao)'
    );
    $inseridas = 0;
    foreach (CARGA_HISTORICO_CNPJ as $linha) {
        if (linhaHistoricoExiste($pdo, $linha['idIecp'], $linha['cnpj'])) {
            continue;
        }
        $inserir->execute([
            ':idIecp' => $linha['idIecp'],
            ':cnpj' => $linha['cnpj'],
            ':vigente_de' => $linha['vigente_de'],
            ':vigente_ate' => $linha['vigente_ate'],
            ':observacao' => $linha['observacao'],
        ]);
        $inseridas++;
    }

    fwrite(STDOUT, "Tabela iecp_cnpj_historico pronta; {$inseridas} linha(s) inserida(s).\n");
} catch (Throwable $erro) {
    falharMigracao('Falha na migração: ' . $erro->getMessage());
}
```

- [ ] **Step 2: Registrar em `sql/schema.sql`**

Inserir imediatamente antes da última linha (`SET FOREIGN_KEY_CHECKS = 1;`):

```sql
-- ----------------------------
-- Table structure for iecp_cnpj_historico
-- CNPJs antigos/provisórios usados nas descrições do balancete da CONIECP
-- (conferência dos 15%; ver sql/migrate_iecp_cnpj_historico_20260923.php)
-- ----------------------------
CREATE TABLE IF NOT EXISTS `iecp_cnpj_historico` (
  `id` int NOT NULL AUTO_INCREMENT,
  `idIecp` int NOT NULL,
  `cnpj` varchar(18) NOT NULL,
  `vigente_de` date NULL DEFAULT NULL,
  `vigente_ate` date NULL DEFAULT NULL,
  `observacao` varchar(255) NULL DEFAULT NULL,
  `cadastradoEm` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_iecp_cnpj_historico_cnpj` (`cnpj`),
  KEY `idx_iecp_cnpj_historico_iecp` (`idIecp`)
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

```

- [ ] **Step 3: Sintaxe e dry-run**

Run: `php -l sql/migrate_iecp_cnpj_historico_20260923.php && php sql/migrate_iecp_cnpj_historico_20260923.php --dry-run`
Expected: `No syntax errors detected`, `Seria criada a tabela iecp_cnpj_historico.` e duas linhas `Seria inserida: ...`.

- [ ] **Step 4: Aplicar no banco local (WAMP) e conferir idempotência**

Aprovado pelo usuário (criação da tabela). Produção continua sendo aplicada pelo usuário.

Run: `php sql/migrate_iecp_cnpj_historico_20260923.php --apply && php sql/migrate_iecp_cnpj_historico_20260923.php --apply`
Expected: primeira execução `2 linha(s) inserida(s)`; segunda `0 linha(s) inserida(s)`.

- [ ] **Step 5: Commit**

```bash
rtk git add sql/migrate_iecp_cnpj_historico_20260923.php sql/schema.sql
rtk git commit -m "feat(pagamento15): tabela iecp_cnpj_historico para identificar depósitos por CNPJ antigo"
```

---

### Task 2: `Pagamento15Regras` (regras puras)

**Files:**
- Create: `tests/pagamento15/assercoes.php`
- Create: `tests/pagamento15/pagamento15_regras_test.php`
- Create: `classes/Pagamento15Regras.php`

**Interfaces:**
- Produces (todas `public static`, classe `final class Pagamento15Regras`, sem namespace):
  - constantes `IECPS_EXCLUIDAS = [15]`, `GRUPO_REGISTRADO_CONIECP = 1`, `GRUPO_15_IECP = 21`, `GRUPOS_FORA_DA_BASE = [32, 34]`, `PERCENTUAL = 0.15`, `ANO_MINIMO = 2014`, `ANOS_HISTORICO = 10`, `STATUS_DEFINITIVO = 'Finalizado'`, `FUTURO`, `AGUARDANDO_CONIECP`, `AGUARDANDO_IECP`, `PROVISORIO`, `DEFINITIVO`
  - `mesConiecp(int $ano, int $mes): array{ano:int, mes:int}`
  - `mesOrigemIecp(int $ano, int $mes): array{ano:int, mes:int}`
  - `rotuloMes(int $ano, int $mes): string` → `'Jan/25'`
  - `janelaHistorico(int $anoCorrente): array{anoIni:int, anoFim:int}`
  - `situacao(int $ano, int $mes, int $anoCorrente, int $mesCorrente, ?string $statusConiecp, ?string $statusSede, array $statusCongregacoes, string $lado = 'ambos'): string` (`$lado` ∈ `'ambos'|'coniecp'|'iecp'`)
  - `pior(array $situacoes): string`
  - `extrairCnpj(string $descricao): ?string`
  - `diferenca(float $registrado, float $outro): float`
  - `divergente(float $diferenca): bool`
  - `moeda(float $valor): string` → `'R$ 1.234,56'`
  - `validarAno(mixed $valor, int $anoCorrente): int` — lança `InvalidArgumentException('ANO_INVALIDO')`
  - `validarMes(mixed $valor): int` — lança `InvalidArgumentException('MES_INVALIDO')`
  - `resolverIecp(array $niveisAcesso, ?int $idIecpSessao, mixed $idIecpPedido, bool $permitirTodas): int` — lança `InvalidArgumentException('IECP_INVALIDA')` ou `DomainException('ACESSO_NEGADO')`
  - `leitura(float $registrado, float $declarado): string`
  - `nota(string $periodo, float $registrado, float $declarado, bool $provisorio): array{periodo:string, tipo:string, titulo:string, texto:string}`

- [ ] **Step 1: Criar as asserções compartilhadas**

`tests/pagamento15/assercoes.php`:

```php
<?php

declare(strict_types=1);

function p15Falhar(string $mensagem, int $codigo = 1): never
{
    fwrite(STDERR, 'FALHOU: ' . $mensagem . PHP_EOL);
    exit($codigo);
}

function p15Igual(mixed $esperado, mixed $obtido, string $contexto): void
{
    if ($esperado !== $obtido) {
        p15Falhar($contexto . ' — esperado ' . var_export($esperado, true) . ', obtido ' . var_export($obtido, true));
    }
}

function p15Lanca(string $classe, string $mensagem, callable $acao, string $contexto): void
{
    try {
        $acao();
    } catch (Throwable $erro) {
        if ($erro instanceof $classe && $erro->getMessage() === $mensagem) {
            return;
        }
        p15Falhar($contexto . ' — lançou ' . $erro::class . '(' . $erro->getMessage() . ')');
    }
    p15Falhar($contexto . ' — não lançou exceção');
}

/** Conexão com o banco isolado sisconiecp_test (mesmas travas de tests/portaria). */
function p15ConexaoTeste(): PDO
{
    $dsn = getenv('SISCONIECP_TEST_DSN');
    if (!is_string($dsn) || $dsn === '') {
        p15Falhar('SISCONIECP_TEST_DSN não configurado (ver Task 0 do plano).', 2);
    }
    if (!str_starts_with(strtolower($dsn), 'mysql:')
        || !preg_match('/(?:^|;)dbname=([^;]+)/i', $dsn, $partes)
        || trim($partes[1], " \t\n\r\0\x0B'\"") !== 'sisconiecp_test') {
        p15Falhar('SISCONIECP_TEST_DSN deve apontar exatamente para mysql dbname=sisconiecp_test.', 2);
    }

    try {
        $pdo = new PDO($dsn, (string) getenv('SISCONIECP_TEST_DB_USER'), (string) getenv('SISCONIECP_TEST_DB_PASSWORD'), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_OBJ,
        ]);
    } catch (PDOException) {
        p15Falhar('Não foi possível conectar ao sisconiecp_test.', 2);
    }
    if ($pdo->query('SELECT DATABASE()')->fetchColumn() !== 'sisconiecp_test') {
        p15Falhar('A conexão não confirmou o banco sisconiecp_test.', 2);
    }

    return $pdo;
}
```

(`FETCH_OBJ` como padrão reproduz o `Connect` real e garante que a classe peça `FETCH_ASSOC`.)

- [ ] **Step 2: Escrever o teste que falha**

`tests/pagamento15/pagamento15_regras_test.php`:

```php
<?php

declare(strict_types=1);

require_once __DIR__ . '/assercoes.php';
require_once dirname(__DIR__, 2) . '/classes/Pagamento15Regras.php';

$r = Pagamento15Regras::class;

// Calendário: balancete IECP (ano, mês) → mês CONIECP (ano, mês + 1).
p15Igual(['ano' => 2026, 'mes' => 1], $r::mesConiecp(2025, 12), 'dezembro vai para janeiro do ano seguinte');
p15Igual(['ano' => 2025, 'mes' => 12], $r::mesConiecp(2025, 11), 'novembro vai para dezembro');
p15Igual(['ano' => 2025, 'mes' => 2], $r::mesConiecp(2025, 1), 'janeiro vai para fevereiro');
p15Igual(['ano' => 2024, 'mes' => 12], $r::mesOrigemIecp(2025, 1), 'origem de janeiro é dezembro anterior');
p15Igual(['ano' => 2025, 'mes' => 5], $r::mesOrigemIecp(2025, 6), 'origem de junho é maio');
p15Igual('Jan/25', $r::rotuloMes(2025, 1), 'rótulo de mês');
p15Igual('Dez/24', $r::rotuloMes(2024, 12), 'rótulo de dezembro');
p15Igual(['anoIni' => 2017, 'anoFim' => 2026], $r::janelaHistorico(2026), 'janela de 10 anos');
p15Igual(['anoIni' => 2014, 'anoFim' => 2018], $r::janelaHistorico(2018), 'janela não começa antes de 2014');

// Situação, na ordem de precedência.
$fin = 'Finalizado';
p15Igual($r::FUTURO, $r::situacao(2025, 10, 2025, 9, $fin, $fin, []), 'mês posterior ao corrente é futuro');
p15Igual($r::AGUARDANDO_CONIECP, $r::situacao(2025, 9, 2025, 9, null, $fin, []), 'sem balancete CONIECP');
p15Igual($r::AGUARDANDO_IECP, $r::situacao(2025, 9, 2025, 9, $fin, null, []), 'sem balancete da sede');
p15Igual($r::PROVISORIO, $r::situacao(2025, 3, 2025, 9, 'Em Elaboracao', $fin, []), 'CONIECP aberta');
p15Igual($r::PROVISORIO, $r::situacao(2025, 3, 2025, 9, $fin, 'Enviado', []), 'sede enviada não é definitiva');
p15Igual($r::PROVISORIO, $r::situacao(2025, 3, 2025, 9, $fin, $fin, [$fin, 'Devolvido']), 'congregação devolvida');
p15Igual($r::DEFINITIVO, $r::situacao(2025, 3, 2025, 9, $fin, $fin, [$fin]), 'tudo finalizado');
p15Igual($r::DEFINITIVO, $r::situacao(2025, 3, 2025, 9, $fin, null, [], 'coniecp'), 'lado CONIECP ignora a IECP');
p15Igual($r::PROVISORIO, $r::situacao(2025, 3, 2025, 9, null, 'Modificado', [], 'iecp'), 'lado IECP ignora a CONIECP');
p15Igual($r::AGUARDANDO_CONIECP, $r::pior([$r::DEFINITIVO, $r::AGUARDANDO_CONIECP, $r::PROVISORIO]), 'pior situação');
p15Igual($r::DEFINITIVO, $r::pior([$r::FUTURO, $r::DEFINITIVO]), 'futuro não piora');
p15Igual($r::FUTURO, $r::pior([]), 'lista vazia é futuro');

// CNPJ.
p15Igual('29.178.753/0001-73', $r::extrairCnpj(' Resende - CNPJ: 29.178.753/0001-73'), 'extrai CNPJ');
p15Igual(null, $r::extrairCnpj('Oferta especial'), 'sem CNPJ');

// Diferença e tolerância.
p15Igual(-10.0, $r::diferenca(200.0, 210.0), 'diferença simples');
p15Igual(0.01, $r::diferenca(0.1 + 0.2, 0.29), 'arredonda cada lado antes de subtrair');
p15Igual(true, $r::divergente(0.01), 'um centavo diverge');
p15Igual(true, $r::divergente(-0.01), 'um centavo negativo diverge');
p15Igual(false, $r::divergente(0.0), 'zero não diverge');
p15Igual('R$ 1.234,56', $r::moeda(1234.56), 'moeda');

// Validação de entrada.
p15Igual(2025, $r::validarAno('2025', 2026), 'ano válido');
p15Lanca(InvalidArgumentException::class, 'ANO_INVALIDO', fn () => $r::validarAno('2013', 2026), 'ano antes de 2014');
p15Lanca(InvalidArgumentException::class, 'ANO_INVALIDO', fn () => $r::validarAno('2027', 2026), 'ano futuro');
p15Lanca(InvalidArgumentException::class, 'ANO_INVALIDO', fn () => $r::validarAno('abc', 2026), 'ano não numérico');
p15Igual(12, $r::validarMes('12'), 'mês válido');
p15Lanca(InvalidArgumentException::class, 'MES_INVALIDO', fn () => $r::validarMes('13'), 'mês 13');
p15Lanca(InvalidArgumentException::class, 'MES_INVALIDO', fn () => $r::validarMes(null), 'mês ausente');

// Acesso.
p15Igual(0, $r::resolverIecp([1], null, '0', true), 'CONIECP pode pedir todas');
p15Igual(7, $r::resolverIecp([1, 3], null, '7', true), 'CONIECP pode pedir qualquer IECP');
p15Lanca(InvalidArgumentException::class, 'IECP_INVALIDA', fn () => $r::resolverIecp([1], null, '0', false), 'detalhamento exige IECP');
p15Lanca(InvalidArgumentException::class, 'IECP_INVALIDA', fn () => $r::resolverIecp([1], null, 'x', true), 'IECP não numérica');
p15Igual(5, $r::resolverIecp([2], 5, '5', true), 'IECP pede a própria');
p15Lanca(DomainException::class, 'ACESSO_NEGADO', fn () => $r::resolverIecp([2], 5, '6', true), 'IECP pede outra');
p15Lanca(DomainException::class, 'ACESSO_NEGADO', fn () => $r::resolverIecp([2], 5, '0', true), 'IECP pede todas');
p15Lanca(DomainException::class, 'ACESSO_NEGADO', fn () => $r::resolverIecp([2], null, '5', true), 'IECP sem sessão');

// Textos neutros.
p15Igual(
    'Declarado pela IECP e não registrado na CONIECP. A IECP não depositou ou a CONIECP não registrou; o comprovante de depósito decide.',
    $r::leitura(0.0, 100.0),
    'leitura: declarado sem registro'
);
p15Igual(
    'Registrado na CONIECP sem declaração da IECP. A IECP não lançou a saída ou o depósito foi atribuído à IECP errada.',
    $r::leitura(100.0, 0.0),
    'leitura: registrado sem declaração'
);
p15Igual('Valores diferentes entre os dois livros. Conferir os lançamentos e os comprovantes.', $r::leitura(90.0, 100.0), 'leitura: diferentes');
p15Igual('Valores coincidentes.', $r::leitura(100.0, 100.0), 'leitura: iguais');
p15Igual('Não há lançamentos nos dois livros neste mês.', $r::leitura(0.0, 0.0), 'leitura: vazio');

$nota = $r::nota('2018', 0.0, 956.69, false);
p15Igual('critical', $nota['tipo'], 'nota crítica');
p15Igual('Declarado pela IECP, sem registro na CONIECP', $nota['titulo'], 'título crítico');
p15Igual('2018', $nota['periodo'], 'período da nota');
p15Igual('Registrado na CONIECP acima do declarado pela IECP (valores provisórios)', $r::nota('2025', 200.0, 100.0, true)['titulo'], 'nota provisória');
p15Igual('Declarado pela IECP acima do registrado na CONIECP', $r::nota('2024', 100.0, 200.0, false)['titulo'], 'nota negativa');
p15Igual('ok', $r::nota('2023', 50.0, 50.0, false)['tipo'], 'nota coincidente');

echo "pagamento15_regras_test: OK\n";
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `php tests/pagamento15/pagamento15_regras_test.php`
Expected: erro fatal `Failed opening required '.../classes/Pagamento15Regras.php'`.

- [ ] **Step 4: Implementar**

`classes/Pagamento15Regras.php`:

```php
<?php

declare(strict_types=1);

/**
 * Regras puras da conferência dos pagamentos de 15% (sem banco).
 * Spec: docs/superpowers/specs/2026-09-23-pagamento15-auditoria-design.md
 */
final class Pagamento15Regras
{
    public const IECPS_EXCLUIDAS = [15];
    public const GRUPO_REGISTRADO_CONIECP = 1;
    public const GRUPO_15_IECP = 21;
    public const GRUPOS_FORA_DA_BASE = [32, 34];
    public const PERCENTUAL = 0.15;
    public const ANO_MINIMO = 2014;
    public const ANOS_HISTORICO = 10;
    public const STATUS_DEFINITIVO = 'Finalizado';

    public const FUTURO = 'futuro';
    public const AGUARDANDO_CONIECP = 'aguardando_coniecp';
    public const AGUARDANDO_IECP = 'aguardando_iecp';
    public const PROVISORIO = 'provisorio';
    public const DEFINITIVO = 'definitivo';

    private const GRAVIDADE = [
        self::FUTURO => 0,
        self::DEFINITIVO => 1,
        self::PROVISORIO => 2,
        self::AGUARDANDO_IECP => 3,
        self::AGUARDANDO_CONIECP => 4,
    ];

    private const MESES = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    /** @return array{ano:int, mes:int} */
    public static function mesConiecp(int $ano, int $mes): array
    {
        return $mes === 12 ? ['ano' => $ano + 1, 'mes' => 1] : ['ano' => $ano, 'mes' => $mes + 1];
    }

    /** @return array{ano:int, mes:int} */
    public static function mesOrigemIecp(int $ano, int $mes): array
    {
        return $mes === 1 ? ['ano' => $ano - 1, 'mes' => 12] : ['ano' => $ano, 'mes' => $mes - 1];
    }

    public static function rotuloMes(int $ano, int $mes): string
    {
        return self::MESES[$mes - 1] . '/' . substr((string) $ano, -2);
    }

    /** @return array{anoIni:int, anoFim:int} */
    public static function janelaHistorico(int $anoCorrente): array
    {
        return [
            'anoIni' => max(self::ANO_MINIMO, $anoCorrente - self::ANOS_HISTORICO + 1),
            'anoFim' => $anoCorrente,
        ];
    }

    /**
     * @param list<string> $statusCongregacoes status dos balancetes das congregações no mês de origem
     * @param 'ambos'|'coniecp'|'iecp' $lado
     */
    public static function situacao(
        int $ano,
        int $mes,
        int $anoCorrente,
        int $mesCorrente,
        ?string $statusConiecp,
        ?string $statusSede,
        array $statusCongregacoes,
        string $lado = 'ambos'
    ): string {
        if ($ano * 12 + $mes > $anoCorrente * 12 + $mesCorrente) {
            return self::FUTURO;
        }

        $usaConiecp = $lado !== 'iecp';
        $usaIecp = $lado !== 'coniecp';
        if ($usaConiecp && $statusConiecp === null) {
            return self::AGUARDANDO_CONIECP;
        }
        if ($usaIecp && $statusSede === null) {
            return self::AGUARDANDO_IECP;
        }

        $envolvidos = [];
        if ($usaConiecp) {
            $envolvidos[] = $statusConiecp;
        }
        if ($usaIecp) {
            $envolvidos[] = $statusSede;
            array_push($envolvidos, ...$statusCongregacoes);
        }
        foreach ($envolvidos as $status) {
            if ($status !== self::STATUS_DEFINITIVO) {
                return self::PROVISORIO;
            }
        }

        return self::DEFINITIVO;
    }

    /** @param list<string> $situacoes */
    public static function pior(array $situacoes): string
    {
        $pior = self::FUTURO;
        foreach ($situacoes as $situacao) {
            if (self::GRAVIDADE[$situacao] > self::GRAVIDADE[$pior]) {
                $pior = $situacao;
            }
        }

        return $pior;
    }

    public static function extrairCnpj(string $descricao): ?string
    {
        return preg_match('/\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}/', $descricao, $partes) === 1 ? $partes[0] : null;
    }

    public static function diferenca(float $registrado, float $outro): float
    {
        return round(round($registrado, 2) - round($outro, 2), 2);
    }

    public static function divergente(float $diferenca): bool
    {
        return abs($diferenca) >= 0.005;
    }

    public static function moeda(float $valor): string
    {
        return 'R$ ' . number_format($valor, 2, ',', '.');
    }

    public static function validarAno(mixed $valor, int $anoCorrente): int
    {
        $ano = filter_var($valor, FILTER_VALIDATE_INT, [
            'options' => ['min_range' => self::ANO_MINIMO, 'max_range' => $anoCorrente],
        ]);
        if ($ano === false) {
            throw new InvalidArgumentException('ANO_INVALIDO');
        }

        return $ano;
    }

    public static function validarMes(mixed $valor): int
    {
        $mes = filter_var($valor, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 12]]);
        if ($mes === false) {
            throw new InvalidArgumentException('MES_INVALIDO');
        }

        return $mes;
    }

    /**
     * CONIECP (nível 1) consulta qualquer IECP (0 = todas, quando permitido);
     * os demais perfis só a IECP da própria sessão.
     *
     * @param list<int> $niveisAcesso
     */
    public static function resolverIecp(array $niveisAcesso, ?int $idIecpSessao, mixed $idIecpPedido, bool $permitirTodas): int
    {
        $pedido = filter_var($idIecpPedido, FILTER_VALIDATE_INT, [
            'options' => ['min_range' => $permitirTodas ? 0 : 1],
        ]);
        if ($pedido === false) {
            throw new InvalidArgumentException('IECP_INVALIDA');
        }
        if (in_array(1, $niveisAcesso, true)) {
            return $pedido;
        }
        if ($idIecpSessao === null || $idIecpSessao < 1 || $pedido !== $idIecpSessao) {
            throw new DomainException('ACESSO_NEGADO');
        }

        return $pedido;
    }

    public static function leitura(float $registrado, float $declarado): string
    {
        $registrado = round($registrado, 2);
        $declarado = round($declarado, 2);
        if ($registrado == 0.0 && $declarado == 0.0) {
            return 'Não há lançamentos nos dois livros neste mês.';
        }
        if ($registrado == 0.0) {
            return 'Declarado pela IECP e não registrado na CONIECP. A IECP não depositou ou a CONIECP não registrou; o comprovante de depósito decide.';
        }
        if ($declarado == 0.0) {
            return 'Registrado na CONIECP sem declaração da IECP. A IECP não lançou a saída ou o depósito foi atribuído à IECP errada.';
        }
        if (self::divergente(self::diferenca($registrado, $declarado))) {
            return 'Valores diferentes entre os dois livros. Conferir os lançamentos e os comprovantes.';
        }

        return 'Valores coincidentes.';
    }

    /** @return array{periodo:string, tipo:string, titulo:string, texto:string} */
    public static function nota(string $periodo, float $registrado, float $declarado, bool $provisorio): array
    {
        $registrado = round($registrado, 2);
        $declarado = round($declarado, 2);
        $diferenca = self::diferenca($registrado, $declarado);

        if ($registrado == 0.0 && $declarado == 0.0) {
            [$tipo, $titulo, $texto] = ['ok', 'Sem lançamentos', 'Não há valor em nenhum dos dois livros neste ano.'];
        } elseif ($registrado == 0.0) {
            [$tipo, $titulo, $texto] = [
                'critical',
                'Declarado pela IECP, sem registro na CONIECP',
                'A IECP declarou ' . self::moeda($declarado) . ' e não há registro na CONIECP. Conferir o comprovante de depósito e o balancete da CONIECP.',
            ];
        } elseif ($declarado == 0.0) {
            [$tipo, $titulo, $texto] = [
                'warning',
                'Registrado na CONIECP, sem declaração da IECP',
                'A CONIECP registrou ' . self::moeda($registrado) . ' e a IECP não declarou valor. Conferir se a IECP lançou a saída e se o depósito foi atribuído à IECP correta.',
            ];
        } elseif (!self::divergente($diferenca)) {
            [$tipo, $titulo, $texto] = ['ok', 'Conferência coincidente', 'Os dois livros registram ' . self::moeda($registrado) . '.'];
        } elseif ($diferenca < 0) {
            [$tipo, $titulo, $texto] = [
                'warning',
                'Declarado pela IECP acima do registrado na CONIECP',
                'A IECP declarou ' . self::moeda($declarado) . ' e a CONIECP registrou ' . self::moeda($registrado) . ': diferença de ' . self::moeda(abs($diferenca)) . '. Conferir os lançamentos e os comprovantes.',
            ];
        } else {
            [$tipo, $titulo, $texto] = [
                'warning',
                'Registrado na CONIECP acima do declarado pela IECP',
                'A CONIECP registrou ' . self::moeda($registrado) . ' e a IECP declarou ' . self::moeda($declarado) . ': diferença de ' . self::moeda($diferenca) . '. Conferir os lançamentos dos dois livros.',
            ];
        }

        return [
            'periodo' => $periodo,
            'tipo' => $tipo,
            'titulo' => $provisorio ? $titulo . ' (valores provisórios)' : $titulo,
            'texto' => $texto,
        ];
    }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `php -l classes/Pagamento15Regras.php && php tests/pagamento15/pagamento15_regras_test.php`
Expected: `No syntax errors detected` e `pagamento15_regras_test: OK`

- [ ] **Step 6: Commit**

```bash
rtk git add classes/Pagamento15Regras.php tests/pagamento15/assercoes.php tests/pagamento15/pagamento15_regras_test.php
rtk git commit -m "feat(pagamento15): regras puras de calendário, situação, acesso e textos"
```

---

### Task 3: `Pagamento15Relatorio` (montagem do JSON, pura)

**Files:**
- Create: `tests/pagamento15/pagamento15_relatorio_test.php`
- Create: `classes/Pagamento15Relatorio.php`

**Interfaces:**
- Consumes: `Pagamento15Regras` (Task 2).
- Consumes (formato dos arrays que a Task 4 vai produzir):
  - `$registrado`: `array{valores: array<int, array<int, array<int, float>>>, naoIdentificado: array<int, array<int, float>>}` — `[idIecp][anoConiecp][mesConiecp]` e `[ano][mes]`.
  - `$declarado`, `$devido`: `array<int, array<int, array<int, float>>>` — `[idIecp][anoConiecp][mesConiecp]`.
  - `$status`: `array{coniecp: array<int, array<int, string>>, sede: array<int, array<int, array<int, string>>>, congregacoes: array<int, array<int, array<int, list<string>>>>}` — sede/congregações já indexadas pelo mês CONIECP.
  - `$iecps`: `list<array{id:int, nome:string}>`.
  - `$lancamentos` (detalhamento): `array{coniecp: list<array{data:string, descricao:string, valor:float, statusBalancete:string, identificadoPor:string}>, iecp: list<array{tipo:string, origem:string, mesBalancete:string, data:string, descricao:string, valor:float, statusBalancete:string, comprovanteUrl:?string}>}`.
- Produces (`final class Pagamento15Relatorio`, construtor `__construct(int $anoCorrente, int $mesCorrente)`):
  - `mensal(int $ano, array $iecps, array $registrado, array $declarado, array $devido, array $status): array` — chaves `ano, periodos, linhas, naoIdentificado, totais, resumo, avisos`.
  - `historico(int $anoIni, int $anoFim, array $iecps, array $registrado, array $declarado, array $devido, array $status): array` — chaves `anoIni, anoFim, periodos, linhas, naoIdentificado, totais, indicadores, notas`.
  - `detalhamento(int $ano, int $mes, string $nomeIecp, array $lancamentos): array` — `$lancamentos` + `titulo, totais, leitura`.
  - Célula: `{registrado, declarado, devido, situacao, situacaoConiecp, situacaoIecp}` (floats com 2 casas). Período: `{chave, rotulo, referencia}`.

- [ ] **Step 1: Escrever o teste que falha**

`tests/pagamento15/pagamento15_relatorio_test.php`:

```php
<?php

declare(strict_types=1);

require_once __DIR__ . '/assercoes.php';
require_once dirname(__DIR__, 2) . '/classes/Pagamento15Regras.php';
require_once dirname(__DIR__, 2) . '/classes/Pagamento15Relatorio.php';

// "Hoje" = março/2025: abril em diante é futuro.
$relatorio = new Pagamento15Relatorio(2025, 3);
$iecps = [['id' => 1, 'nome' => 'Alfa']];
$registrado = [
    'valores' => [1 => [2025 => [1 => 130.0, 2 => 200.0]]],
    'naoIdentificado' => [2025 => [2 => 50.0]],
];
$declarado = [1 => [2025 => [1 => 130.0, 2 => 210.0]]];
$devido = [1 => [2025 => [1 => 240.0, 2 => 60.0]]];
$status = [
    'coniecp' => [2025 => [1 => 'Finalizado', 2 => 'Em Elaboracao']],
    'sede' => [1 => [2025 => [1 => 'Finalizado', 2 => 'Enviado']]],
    'congregacoes' => [1 => [2025 => [1 => ['Finalizado']]]],
];

$mensal = $relatorio->mensal(2025, $iecps, $registrado, $declarado, $devido, $status);

p15Igual(['chave' => '1', 'rotulo' => 'Jan/25', 'referencia' => 'ref. Dez/24'], $mensal['periodos'][0], 'período de janeiro');
p15Igual(12, count($mensal['periodos']), 'doze meses');

$jan = $mensal['linhas'][0]['celulas']['1'];
p15Igual(130.0, $jan['registrado'], 'registrado jan');
p15Igual(130.0, $jan['declarado'], 'declarado jan');
p15Igual(240.0, $jan['devido'], 'devido jan');
p15Igual('definitivo', $jan['situacao'], 'jan definitivo');

$fev = $mensal['linhas'][0]['celulas']['2'];
p15Igual('provisorio', $fev['situacao'], 'fev provisório');
p15Igual('provisorio', $fev['situacaoConiecp'], 'fev CONIECP em elaboração');
p15Igual('provisorio', $fev['situacaoIecp'], 'fev IECP enviada');

$mar = $mensal['linhas'][0]['celulas']['3'];
p15Igual('aguardando_coniecp', $mar['situacao'], 'mar sem balancete CONIECP');
p15Igual('aguardando_iecp', $mar['situacaoIecp'], 'mar sem balancete da sede');
p15Igual('futuro', $mensal['linhas'][0]['celulas']['4']['situacao'], 'abr futuro');

$total = $mensal['linhas'][0]['total'];
p15Igual(330.0, $total['registrado'], 'total registrado da linha');
p15Igual(340.0, $total['declarado'], 'total declarado da linha');
p15Igual('aguardando_coniecp', $total['situacao'], 'pior situação da linha');

p15Igual(50.0, $mensal['naoIdentificado']['celulas']['2'], 'não identificado em fev');
p15Igual(50.0, $mensal['naoIdentificado']['total'], 'total não identificado');
p15Igual(330.0, $mensal['totais']['total']['registrado'], 'total geral registrado');
p15Igual(130.0, $mensal['totais']['celulas']['1']['declarado'], 'total da coluna jan');

p15Igual(330.0, $mensal['resumo']['registrado'], 'resumo registrado');
p15Igual(340.0, $mensal['resumo']['declarado'], 'resumo declarado');
p15Igual(-10.0, $mensal['resumo']['diferenca'], 'resumo diferença');
p15Igual(300.0, $mensal['resumo']['devido'], 'resumo devido');
p15Igual(30.0, $mensal['resumo']['diferencaDevido'], 'resumo diferença devido');
p15Igual(1, $mensal['resumo']['iecpsComDivergencia'], 'uma IECP com divergência');
p15Igual(50.0, $mensal['resumo']['naoIdentificado'], 'resumo não identificado');

p15Igual([
    'CONIECP: balancete de Fev/25 ainda não finalizado — valores provisórios.',
    'CONIECP: sem balancete de Mar/25 — aguardando lançamento.',
], $mensal['avisos'], 'avisos da CONIECP');

$semLinhas = $relatorio->mensal(2025, [], $registrado, $declarado, $devido, $status);
p15Igual(0.0, $semLinhas['totais']['total']['registrado'], 'sem IECPs, total zero');
p15Igual(0, $semLinhas['resumo']['iecpsComDivergencia'], 'sem IECPs, sem divergência');

// Histórico 2024–2025 ("hoje" = março/2025).
$registradoHist = [
    'valores' => [1 => [2024 => [5 => 100.0], 2025 => [1 => 130.0]]],
    'naoIdentificado' => [],
];
$declaradoHist = [1 => [2024 => [5 => 100.0], 2025 => [1 => 150.0]]];
$statusHist = [
    'coniecp' => [2024 => array_fill(1, 12, 'Finalizado'), 2025 => [1 => 'Finalizado', 2 => 'Finalizado', 3 => 'Finalizado']],
    'sede' => [1 => [2024 => array_fill(1, 12, 'Finalizado'), 2025 => [1 => 'Finalizado', 2 => 'Finalizado', 3 => 'Finalizado']]],
    'congregacoes' => [],
];
$hist = $relatorio->historico(2024, 2025, $iecps, $registradoHist, $declaradoHist, [], $statusHist);

p15Igual(['chave' => '2024', 'rotulo' => '2024', 'referencia' => 'ref. Dez/23–Nov/24'], $hist['periodos'][0], 'período anual');
p15Igual(100.0, $hist['linhas'][0]['celulas']['2024']['registrado'], 'soma anual 2024');
p15Igual('definitivo', $hist['linhas'][0]['celulas']['2024']['situacao'], '2024 definitivo');
p15Igual('definitivo', $hist['linhas'][0]['celulas']['2025']['situacao'], '2025 ignora meses futuros');
p15Igual(-20.0, $hist['indicadores']['diferencaAcumulada'], 'diferença acumulada');
p15Igual(230.0, $hist['indicadores']['registrado'], 'registrado acumulado');
p15Igual(250.0, $hist['indicadores']['declarado'], 'declarado acumulado');
p15Igual(1, $hist['indicadores']['periodosDivergentes'], 'um ano divergente');
p15Igual(['rotulo' => '2025', 'valor' => -20.0], $hist['indicadores']['maiorDiferenca'], 'maior diferença');
p15Igual('Conferência coincidente', $hist['notas'][0]['titulo'], 'nota de 2024');
p15Igual('Declarado pela IECP acima do registrado na CONIECP', $hist['notas'][1]['titulo'], 'nota de 2025');

// Detalhamento.
$detalhe = $relatorio->detalhamento(2025, 1, 'Alfa', [
    'coniecp' => [['data' => '2025-01-06', 'descricao' => 'Alfa', 'valor' => 130.0, 'statusBalancete' => 'Finalizado', 'identificadoPor' => 'idIecp']],
    'iecp' => [
        ['tipo' => 'sede', 'origem' => 'Sede', 'mesBalancete' => '12/2024', 'data' => '2024-12-10', 'descricao' => '15%', 'valor' => 100.0, 'statusBalancete' => 'Finalizado', 'comprovanteUrl' => null],
        ['tipo' => 'congregacao', 'origem' => 'Norte', 'mesBalancete' => '12/2024', 'data' => '2024-12-11', 'descricao' => '15%', 'valor' => 30.0, 'statusBalancete' => 'Finalizado', 'comprovanteUrl' => null],
    ],
]);
p15Igual('Alfa — Jan/25 (ref. Dez/24)', $detalhe['titulo'], 'título do detalhamento');
p15Igual(['registrado' => 130.0, 'declarado' => 130.0, 'diferenca' => 0.0], $detalhe['totais'], 'totais do detalhamento');
p15Igual('Valores coincidentes.', $detalhe['leitura'], 'leitura do detalhamento');
p15Igual(2, count($detalhe['iecp']), 'itens IECP preservados');

echo "pagamento15_relatorio_test: OK\n";
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `php tests/pagamento15/pagamento15_relatorio_test.php`
Expected: erro fatal `Failed opening required '.../classes/Pagamento15Relatorio.php'`.

- [ ] **Step 3: Implementar**

`classes/Pagamento15Relatorio.php`:

```php
<?php

declare(strict_types=1);

require_once __DIR__ . '/Pagamento15Regras.php';

/**
 * Monta os payloads JSON da conferência dos 15% a partir dos arrays de Pagamento15.
 * Não acessa banco; "hoje" é injetado para decidir o que é mês futuro.
 */
final class Pagamento15Relatorio
{
    private const CAMPOS_VALOR = ['registrado', 'declarado', 'devido'];
    private const CAMPOS_SITUACAO = ['situacao', 'situacaoConiecp', 'situacaoIecp'];

    public function __construct(private int $anoCorrente, private int $mesCorrente)
    {
    }

    public function mensal(int $ano, array $iecps, array $registrado, array $declarado, array $devido, array $status): array
    {
        $periodos = [];
        for ($mes = 1; $mes <= 12; $mes++) {
            $origem = Pagamento15Regras::mesOrigemIecp($ano, $mes);
            $periodos[] = [
                'chave' => (string) $mes,
                'rotulo' => Pagamento15Regras::rotuloMes($ano, $mes),
                'referencia' => 'ref. ' . Pagamento15Regras::rotuloMes($origem['ano'], $origem['mes']),
            ];
        }

        $linhas = [];
        foreach ($iecps as $iecp) {
            $celulas = [];
            for ($mes = 1; $mes <= 12; $mes++) {
                $celulas[(string) $mes] = $this->celula($iecp['id'], $ano, $mes, $registrado, $declarado, $devido, $status);
            }
            $linhas[] = ['id' => $iecp['id'], 'nome' => $iecp['nome'], 'celulas' => $celulas, 'total' => $this->somar($celulas)];
        }

        $naoIdentificado = [];
        for ($mes = 1; $mes <= 12; $mes++) {
            $naoIdentificado[(string) $mes] = round((float) ($registrado['naoIdentificado'][$ano][$mes] ?? 0.0), 2);
        }
        $totalNaoIdentificado = round(array_sum($naoIdentificado), 2);
        $totais = $this->totais($linhas, array_column($periodos, 'chave'));

        return [
            'ano' => $ano,
            'periodos' => $periodos,
            'linhas' => $linhas,
            'naoIdentificado' => ['celulas' => $naoIdentificado, 'total' => $totalNaoIdentificado],
            'totais' => $totais,
            'resumo' => $this->resumo($linhas, $totais['total'], $totalNaoIdentificado),
            'avisos' => $this->avisos($ano, $status),
        ];
    }

    public function historico(int $anoIni, int $anoFim, array $iecps, array $registrado, array $declarado, array $devido, array $status): array
    {
        $periodos = [];
        for ($ano = $anoIni; $ano <= $anoFim; $ano++) {
            $periodos[] = [
                'chave' => (string) $ano,
                'rotulo' => (string) $ano,
                'referencia' => 'ref. ' . Pagamento15Regras::rotuloMes($ano - 1, 12) . '–' . Pagamento15Regras::rotuloMes($ano, 11),
            ];
        }

        $linhas = [];
        foreach ($iecps as $iecp) {
            $celulas = [];
            for ($ano = $anoIni; $ano <= $anoFim; $ano++) {
                $meses = [];
                for ($mes = 1; $mes <= 12; $mes++) {
                    $meses[] = $this->celula($iecp['id'], $ano, $mes, $registrado, $declarado, $devido, $status);
                }
                $celulas[(string) $ano] = $this->somar($meses);
            }
            $linhas[] = ['id' => $iecp['id'], 'nome' => $iecp['nome'], 'celulas' => $celulas, 'total' => $this->somar($celulas)];
        }

        $naoIdentificado = [];
        for ($ano = $anoIni; $ano <= $anoFim; $ano++) {
            $naoIdentificado[(string) $ano] = round(array_sum($registrado['naoIdentificado'][$ano] ?? []), 2);
        }
        $totais = $this->totais($linhas, array_column($periodos, 'chave'));

        return [
            'anoIni' => $anoIni,
            'anoFim' => $anoFim,
            'periodos' => $periodos,
            'linhas' => $linhas,
            'naoIdentificado' => ['celulas' => $naoIdentificado, 'total' => round(array_sum($naoIdentificado), 2)],
            'totais' => $totais,
            'indicadores' => $this->indicadores($periodos, $totais),
            'notas' => $this->notas($periodos, $totais),
        ];
    }

    public function detalhamento(int $ano, int $mes, string $nomeIecp, array $lancamentos): array
    {
        $registrado = round(array_sum(array_column($lancamentos['coniecp'], 'valor')), 2);
        $declarado = round(array_sum(array_column($lancamentos['iecp'], 'valor')), 2);
        $origem = Pagamento15Regras::mesOrigemIecp($ano, $mes);

        return $lancamentos + [
            'titulo' => $nomeIecp . ' — ' . Pagamento15Regras::rotuloMes($ano, $mes)
                . ' (ref. ' . Pagamento15Regras::rotuloMes($origem['ano'], $origem['mes']) . ')',
            'totais' => [
                'registrado' => $registrado,
                'declarado' => $declarado,
                'diferenca' => Pagamento15Regras::diferenca($registrado, $declarado),
            ],
            'leitura' => Pagamento15Regras::leitura($registrado, $declarado),
        ];
    }

    private function celula(int $idIecp, int $ano, int $mes, array $registrado, array $declarado, array $devido, array $status): array
    {
        $statusConiecp = $status['coniecp'][$ano][$mes] ?? null;
        $statusSede = $status['sede'][$idIecp][$ano][$mes] ?? null;
        $statusCongregacoes = $status['congregacoes'][$idIecp][$ano][$mes] ?? [];
        $situacao = fn (string $lado): string => Pagamento15Regras::situacao(
            $ano,
            $mes,
            $this->anoCorrente,
            $this->mesCorrente,
            $statusConiecp,
            $statusSede,
            $statusCongregacoes,
            $lado
        );

        return [
            'registrado' => round((float) ($registrado['valores'][$idIecp][$ano][$mes] ?? 0.0), 2),
            'declarado' => round((float) ($declarado[$idIecp][$ano][$mes] ?? 0.0), 2),
            'devido' => round((float) ($devido[$idIecp][$ano][$mes] ?? 0.0), 2),
            'situacao' => $situacao('ambos'),
            'situacaoConiecp' => $situacao('coniecp'),
            'situacaoIecp' => $situacao('iecp'),
        ];
    }

    /** Soma valores e escolhe a pior situação de um conjunto de células. */
    private function somar(array $celulas): array
    {
        $total = [];
        foreach (self::CAMPOS_VALOR as $campo) {
            $total[$campo] = round(array_sum(array_column($celulas, $campo)), 2);
        }
        foreach (self::CAMPOS_SITUACAO as $campo) {
            $total[$campo] = Pagamento15Regras::pior(array_column($celulas, $campo));
        }

        return $total;
    }

    private function totais(array $linhas, array $chaves): array
    {
        $celulas = [];
        foreach ($chaves as $chave) {
            $celulas[$chave] = $this->somar(array_map(static fn (array $linha): array => $linha['celulas'][$chave], $linhas));
        }

        return [
            'celulas' => $celulas,
            'total' => $this->somar(array_column($linhas, 'total')),
        ];
    }

    private function resumo(array $linhas, array $total, float $naoIdentificado): array
    {
        $comDivergencia = 0;
        foreach ($linhas as $linha) {
            foreach ($linha['celulas'] as $celula) {
                if ($celula['situacao'] !== Pagamento15Regras::FUTURO
                    && Pagamento15Regras::divergente(Pagamento15Regras::diferenca($celula['registrado'], $celula['declarado']))) {
                    $comDivergencia++;
                    break;
                }
            }
        }

        return [
            'registrado' => $total['registrado'],
            'declarado' => $total['declarado'],
            'diferenca' => Pagamento15Regras::diferenca($total['registrado'], $total['declarado']),
            'devido' => $total['devido'],
            'diferencaDevido' => Pagamento15Regras::diferenca($total['registrado'], $total['devido']),
            'iecpsComDivergencia' => $comDivergencia,
            'naoIdentificado' => $naoIdentificado,
        ];
    }

    /** Agrupa meses consecutivos sem balancete ou com balancete aberto na CONIECP. */
    private function avisos(int $ano, array $status): array
    {
        $grupos = [];
        for ($mes = 1; $mes <= 12; $mes++) {
            if ($ano * 12 + $mes > $this->anoCorrente * 12 + $this->mesCorrente) {
                break;
            }
            $statusMes = $status['coniecp'][$ano][$mes] ?? null;
            $estado = $statusMes === null ? 'sem' : ($statusMes === Pagamento15Regras::STATUS_DEFINITIVO ? null : 'aberto');
            if ($estado === null) {
                continue;
            }
            $ultimo = array_key_last($grupos);
            if ($ultimo !== null && $grupos[$ultimo]['estado'] === $estado && $grupos[$ultimo]['fim'] === $mes - 1) {
                $grupos[$ultimo]['fim'] = $mes;
                continue;
            }
            $grupos[] = ['estado' => $estado, 'inicio' => $mes, 'fim' => $mes];
        }

        $avisos = [];
        foreach ($grupos as $grupo) {
            $inicio = Pagamento15Regras::rotuloMes($ano, $grupo['inicio']);
            $fim = Pagamento15Regras::rotuloMes($ano, $grupo['fim']);
            $unico = $grupo['inicio'] === $grupo['fim'];
            if ($grupo['estado'] === 'aberto') {
                $avisos[] = $unico
                    ? "CONIECP: balancete de {$inicio} ainda não finalizado — valores provisórios."
                    : "CONIECP: balancetes de {$inicio} a {$fim} ainda não finalizados — valores provisórios.";
            } else {
                $avisos[] = $unico
                    ? "CONIECP: sem balancete de {$inicio} — aguardando lançamento."
                    : "CONIECP: sem balancetes de {$inicio} a {$fim} — aguardando lançamento.";
            }
        }

        return $avisos;
    }

    private function indicadores(array $periodos, array $totais): array
    {
        $divergentes = 0;
        $maior = null;
        foreach ($periodos as $periodo) {
            $celula = $totais['celulas'][$periodo['chave']];
            if ($celula['situacao'] === Pagamento15Regras::FUTURO) {
                continue;
            }
            $diferenca = Pagamento15Regras::diferenca($celula['registrado'], $celula['declarado']);
            if (!Pagamento15Regras::divergente($diferenca)) {
                continue;
            }
            $divergentes++;
            if ($maior === null || abs($diferenca) > abs($maior['valor'])) {
                $maior = ['rotulo' => $periodo['rotulo'], 'valor' => $diferenca];
            }
        }

        return [
            'registrado' => $totais['total']['registrado'],
            'declarado' => $totais['total']['declarado'],
            'diferencaAcumulada' => Pagamento15Regras::diferenca($totais['total']['registrado'], $totais['total']['declarado']),
            'periodosDivergentes' => $divergentes,
            'maiorDiferenca' => $maior,
        ];
    }

    private function notas(array $periodos, array $totais): array
    {
        $notas = [];
        foreach ($periodos as $periodo) {
            $celula = $totais['celulas'][$periodo['chave']];
            if ($celula['situacao'] === Pagamento15Regras::FUTURO) {
                continue;
            }
            $notas[] = Pagamento15Regras::nota(
                $periodo['rotulo'],
                $celula['registrado'],
                $celula['declarado'],
                $celula['situacao'] !== Pagamento15Regras::DEFINITIVO
            );
        }

        return $notas;
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `php -l classes/Pagamento15Relatorio.php && php tests/pagamento15/pagamento15_relatorio_test.php`
Expected: `No syntax errors detected` e `pagamento15_relatorio_test: OK`

- [ ] **Step 5: Commit**

```bash
rtk git add classes/Pagamento15Relatorio.php tests/pagamento15/pagamento15_relatorio_test.php
rtk git commit -m "feat(pagamento15): montagem dos payloads mensal, histórico e detalhamento"
```

---

### Task 4: `Pagamento15` (consultas somente-leitura)

**Files:**
- Create: `tests/pagamento15/pagamento15_consultas_test.php`
- Create: `classes/Pagamento15.php`

**Interfaces:**
- Consumes: `Pagamento15Regras` (Task 2); tabela `iecp_cnpj_historico` (Task 1); `p15ConexaoTeste()` (Task 2).
- Produces (`final class Pagamento15`, `__construct(PDO $pdo)`), nos formatos listados em "Consumes" da Task 3:
  - `iecps(int $idIecp): list<array{id:int, nome:string}>`
  - `registradoConiecp(int $anoIni, int $anoFim): array{valores:..., naoIdentificado:...}`
  - `declaradoIecp(int $anoIni, int $anoFim): array`
  - `devidoArrecadacao(int $anoIni, int $anoFim): array`
  - `statusBalancetes(int $anoIni, int $anoFim): array{coniecp:..., sede:..., congregacoes:...}`
  - `lancamentos(int $idIecp, int $ano, int $mes): array{coniecp: list, iecp: list}` (`$ano`/`$mes` = mês CONIECP)
- Restrição do MySQL: uma tabela `TEMPORARY` não pode aparecer duas vezes na mesma consulta; nenhuma consulta abaixo faz isso.

- [ ] **Step 1: Escrever o teste que falha**

`tests/pagamento15/pagamento15_consultas_test.php`:

```php
<?php

declare(strict_types=1);

require_once __DIR__ . '/assercoes.php';
require_once dirname(__DIR__, 2) . '/classes/Pagamento15Regras.php';
require_once dirname(__DIR__, 2) . '/classes/Pagamento15.php';

$pdo = p15ConexaoTeste();

foreach ([
    'CREATE TEMPORARY TABLE iecp (idIecp INT, iecp VARCHAR(255), cnpj VARCHAR(18), ativo TINYINT)',
    'CREATE TEMPORARY TABLE iecp_cnpj_historico (id INT AUTO_INCREMENT PRIMARY KEY, idIecp INT, cnpj VARCHAR(18), vigente_de DATE NULL, vigente_ate DATE NULL)',
    'CREATE TEMPORARY TABLE congregacao (idCongregacao INT, idIecp INT, congregacao VARCHAR(255))',
    'CREATE TEMPORARY TABLE balancete (idBalancete INT, idIecp INT, mes VARCHAR(255), ano YEAR, statusBalancete VARCHAR(255))',
    'CREATE TEMPORARY TABLE itembalancete (idItem INT, idBalancete INT, tipoContabil INT, dia DATE, idGrupo INT, descricao VARCHAR(255), valor DOUBLE)',
    'CREATE TEMPORARY TABLE balancete_congregacao (idBalancete_Congregacao INT, idCongregacao INT, idIecp INT, mes INT, ano YEAR, statusBalancete VARCHAR(255))',
    'CREATE TEMPORARY TABLE itembalancete_congregacao (idItem INT, idBalancete_Congregacao INT, tipoContabil INT, dia DATE, idGrupo INT, descricao VARCHAR(255), valor DOUBLE)',
    'CREATE TEMPORARY TABLE balancete_coniecp (idBalanceteConiecp INT, mes VARCHAR(10), ano YEAR, statusBalancete VARCHAR(50))',
    'CREATE TEMPORARY TABLE itembalancete_coniecp (idItem INT, idBalanceteConiecp INT, tipoContabil INT, dia DATE, idGrupoConiecp INT, descricao VARCHAR(255), valor DOUBLE, idIecp INT)',
    'CREATE TEMPORARY TABLE recibo_armazenado_iecp (idRecibo_arm INT AUTO_INCREMENT PRIMARY KEY, idItem_balancete INT, local VARCHAR(255))',
    'CREATE TEMPORARY TABLE recibo_armazenado_congregacao (idRecibo_arm INT AUTO_INCREMENT PRIMARY KEY, idItem_balancete INT, local VARCHAR(255))',
    "INSERT INTO iecp VALUES
        (1, 'Igreja Evangélica Cristã Pentecostal em Alfa', '11.111.111/0001-11', 1),
        (2, 'Igreja Evangélica Cristã Pentecostal em Beta', '22.222.222/0001-22', 1),
        (3, 'Igreja Evangélica Cristã Pentecostal em Inativa', '33.333.333/0001-33', 0),
        (15, 'Igreja Evangélica Cristã Pentecostal em Testes', '00.000.000/0001-00', 1)",
    "INSERT INTO iecp_cnpj_historico (idIecp, cnpj, vigente_de, vigente_ate) VALUES (2, '00.000.000/0000-02', NULL, '2019-12-31')",
    "INSERT INTO congregacao VALUES (10, 1, 'Alfa Norte')",
    "INSERT INTO balancete VALUES
        (100, 1, '12', 2024, 'Finalizado'),
        (101, 1, '01', 2025, 'Enviado'),
        (102, 2, '03', 2025, 'Finalizado'),
        (103, 1, '', 2025, 'Em Elaboracao'),
        (104, 1, '12', 2025, 'Finalizado')",
    "INSERT INTO itembalancete VALUES
        (1000, 100, 2, '2024-12-10', 21, '15% CONIECP', 100),
        (1001, 100, 1, '2024-12-05', 1, 'Dízimo', 1000),
        (1002, 100, 1, '2024-12-06', 32, 'Recebido da congregação', 500),
        (1003, 101, 2, '2025-02-01', 21, '15% CONIECP', 200),
        (1004, 101, 1, '2025-01-07', 34, 'Recebido da IECP', 300),
        (1005, 101, 1, '2025-01-08', 2, 'Oferta', 400),
        (1006, 102, 2, '2025-03-10', 21, '15% CONIECP', 50),
        (1007, 103, 2, '2025-05-10', 21, 'Mês inválido', 999),
        (1008, 104, 2, '2025-12-10', 21, 'Vai para 2026', 77)",
    "INSERT INTO balancete_congregacao VALUES (200, 10, 1, 12, 2024, 'Finalizado')",
    "INSERT INTO itembalancete_congregacao VALUES
        (2000, 200, 2, '2024-12-11', 21, '15% CONIECP', 30),
        (2001, 200, 1, '2024-12-03', 1, 'Dízimo', 600)",
    "INSERT INTO recibo_armazenado_iecp (idItem_balancete, local) VALUES (1000, 'recibos/1/a.webp')",
    "INSERT INTO balancete_coniecp VALUES
        (300, '01', 2025, 'Finalizado'),
        (301, '02', 2025, 'Em Elaboracao'),
        (302, '04', 2025, 'Finalizado'),
        (303, '06', 2019, 'Finalizado')",
    "INSERT INTO itembalancete_coniecp VALUES
        (3000, 300, 1, '2025-01-06', 1, 'Alfa - CNPJ: 11.111.111/0001-11', 130, 1),
        (3001, 301, 1, '2025-02-05', 1, 'Alfa - CNPJ: 11.111.111/0001-11', 200, 0),
        (3002, 302, 1, '2025-04-03', 1, 'Beta - CNPJ: 00.000.000/0000-02', 50, 0),
        (3003, 303, 1, '2019-06-10', 1, 'Beta - CNPJ: 00.000.000/0000-02', 70, 0),
        (3004, 300, 1, '2025-01-09', 5, 'Outro grupo', 999, 1)",
] as $sql) {
    $pdo->exec($sql);
}

$consultas = new Pagamento15($pdo);

p15Igual([['id' => 1, 'nome' => 'Alfa'], ['id' => 2, 'nome' => 'Beta']], $consultas->iecps(0), 'ativas, sem a IECP 15');
p15Igual([['id' => 2, 'nome' => 'Beta']], $consultas->iecps(2), 'uma IECP');
p15Igual([], $consultas->iecps(15), 'IECP excluída');

$declarado = $consultas->declaradoIecp(2025, 2025);
p15Igual(130.0, round($declarado[1][2025][1], 2), 'jan/25 = dez/24 da sede (100) + congregação (30)');
p15Igual(200.0, round($declarado[1][2025][2], 2), 'item datado em fev fica no balancete de jan → fev/25');
p15Igual(50.0, round($declarado[2][2025][4], 2), 'mar/25 da Beta → abr/25');
p15Igual(false, isset($declarado[1][2026]), 'dez/25 fica fora da janela 2025');
p15Igual(3, count($declarado[1][2025]) + count($declarado[2][2025]), 'mês inválido ignorado');

$devido = $consultas->devidoArrecadacao(2025, 2025);
p15Igual(240.0, round($devido[1][2025][1], 2), '15% de (1000 + 600); grupo 32 fora');
p15Igual(60.0, round($devido[1][2025][2], 2), '15% de 400; grupo 34 fora');

$registrado = $consultas->registradoConiecp(2025, 2025);
p15Igual(130.0, round($registrado['valores'][1][2025][1], 2), 'por idIecp');
p15Igual(200.0, round($registrado['valores'][1][2025][2], 2), 'idIecp = 0 identificado pelo CNPJ atual');
p15Igual(50.0, round($registrado['naoIdentificado'][2025][4], 2), 'CNPJ provisório fora da vigência = não identificado');
p15Igual(false, isset($registrado['valores'][2]), 'nada atribuído à Beta em 2025');
$registrado2019 = $consultas->registradoConiecp(2019, 2019);
p15Igual(70.0, round($registrado2019['valores'][2][2019][6], 2), 'CNPJ provisório dentro da vigência → Beta');

$status = $consultas->statusBalancetes(2025, 2025);
p15Igual('Finalizado', $status['coniecp'][2025][1], 'status CONIECP jan');
p15Igual('Em Elaboracao', $status['coniecp'][2025][2], 'status CONIECP fev');
p15Igual('Finalizado', $status['sede'][1][2025][1], 'sede dez/24 indexada em jan/25');
p15Igual('Enviado', $status['sede'][1][2025][2], 'sede jan/25 indexada em fev/25');
p15Igual(['Finalizado'], $status['congregacoes'][1][2025][1], 'congregação dez/24 em jan/25');
p15Igual(false, isset($status['sede'][1][2026]), 'dez/25 fora da janela');

$janeiro = $consultas->lancamentos(1, 2025, 1);
p15Igual(1, count($janeiro['coniecp']), 'um lançamento CONIECP em jan');
p15Igual('idIecp', $janeiro['coniecp'][0]['identificadoPor'], 'identificado pelo vínculo');
p15Igual(2, count($janeiro['iecp']), 'sede + congregação');
p15Igual('Sede', $janeiro['iecp'][0]['origem'], 'sede primeiro');
p15Igual('12/2024', $janeiro['iecp'][0]['mesBalancete'], 'mês do balancete');
p15Igual('iecp/tesouraria/balanceteMensal/recibos/1/a.webp', $janeiro['iecp'][0]['comprovanteUrl'], 'URL do recibo');
p15Igual('Alfa Norte', $janeiro['iecp'][1]['origem'], 'nome da congregação');
p15Igual(null, $janeiro['iecp'][1]['comprovanteUrl'], 'sem comprovante');

$fevereiro = $consultas->lancamentos(1, 2025, 2);
p15Igual('cnpj_atual', $fevereiro['coniecp'][0]['identificadoPor'], 'identificado pelo CNPJ');
p15Igual(200.0, $fevereiro['iecp'][0]['valor'], 'item de jan/25');

$abril = $consultas->lancamentos(2, 2025, 4);
p15Igual([], $abril['coniecp'], 'depósito não identificado não aparece na Beta');
p15Igual(50.0, $abril['iecp'][0]['valor'], 'declarado da Beta');

echo "pagamento15_consultas_test: OK\n";
```

- [ ] **Step 2: Rodar e ver falhar**

Run (Bash, com a senha da Task 0):
```bash
SISCONIECP_TEST_DSN='mysql:host=localhost;dbname=sisconiecp_test;charset=utf8mb4' SISCONIECP_TEST_DB_USER='sisconiecp_test' SISCONIECP_TEST_DB_PASSWORD='<senha>' php tests/pagamento15/pagamento15_consultas_test.php
```
Expected: erro fatal `Failed opening required '.../classes/Pagamento15.php'`.

- [ ] **Step 3: Implementar**

`classes/Pagamento15.php`:

```php
<?php

declare(strict_types=1);

require_once __DIR__ . '/Pagamento15Regras.php';

/**
 * Consultas somente-leitura da conferência dos 15%.
 * Anos/meses recebidos e devolvidos são do calendário CONIECP; o lado IECP já sai
 * deslocado (balancete M → mês CONIECP M+1). Nunca altera os livros.
 */
final class Pagamento15
{
    private const PREFIXO_NOME = 'Igreja Evangélica Cristã Pentecostal em';
    private const PASTA_RECIBOS = 'iecp/tesouraria/balanceteMensal/';

    /** @var list<array<string, mixed>>|null */
    private ?array $historicoCnpj = null;
    /** @var array<string, int>|null */
    private ?array $cnpjAtual = null;

    public function __construct(private PDO $pdo)
    {
    }

    /** @return list<array{id:int, nome:string}> */
    public function iecps(int $idIecp): array
    {
        $sql = 'SELECT idIecp, iecp FROM iecp WHERE ativo = 1'
            . ($idIecp > 0 ? ' AND idIecp = :idIecp' : '')
            . ' ORDER BY iecp';
        $linhas = $this->buscar($sql, $idIecp > 0 ? [':idIecp' => $idIecp] : []);

        $lista = [];
        foreach ($linhas as $linha) {
            $id = (int) $linha['idIecp'];
            if (in_array($id, Pagamento15Regras::IECPS_EXCLUIDAS, true)) {
                continue;
            }
            $lista[] = ['id' => $id, 'nome' => trim(str_replace(self::PREFIXO_NOME, '', (string) $linha['iecp']))];
        }

        return $lista;
    }

    public function declaradoIecp(int $anoIni, int $anoFim): array
    {
        return $this->somarIecp(sprintf('it.idGrupo = %d', Pagamento15Regras::GRUPO_15_IECP), $anoIni, $anoFim, 1.0);
    }

    public function devidoArrecadacao(int $anoIni, int $anoFim): array
    {
        $condicao = sprintf(
            'it.tipoContabil = 1 AND it.idGrupo NOT IN (%s)',
            implode(', ', array_map('intval', Pagamento15Regras::GRUPOS_FORA_DA_BASE))
        );

        return $this->somarIecp($condicao, $anoIni, $anoFim, Pagamento15Regras::PERCENTUAL);
    }

    public function registradoConiecp(int $anoIni, int $anoFim): array
    {
        $valores = [];
        $agrupados = $this->buscar(
            'SELECT it.idIecp, b.ano, CAST(b.mes AS UNSIGNED) AS mes, SUM(it.valor) AS valor
               FROM balancete_coniecp b
               JOIN itembalancete_coniecp it ON it.idBalanceteConiecp = b.idBalanceteConiecp
              WHERE it.idGrupoConiecp = :grupo
                AND it.tipoContabil = 1
                AND it.idIecp <> 0
                AND b.ano BETWEEN :anoIni AND :anoFim
              GROUP BY it.idIecp, b.ano, b.mes',
            [':grupo' => Pagamento15Regras::GRUPO_REGISTRADO_CONIECP, ':anoIni' => $anoIni, ':anoFim' => $anoFim]
        );
        foreach ($agrupados as $linha) {
            $this->acumular($valores, (int) $linha['idIecp'], (int) $linha['ano'], (int) $linha['mes'], (float) $linha['valor']);
        }

        $naoIdentificado = [];
        $semVinculo = $this->buscar(
            'SELECT it.dia, it.descricao, it.valor, b.ano, CAST(b.mes AS UNSIGNED) AS mes
               FROM balancete_coniecp b
               JOIN itembalancete_coniecp it ON it.idBalanceteConiecp = b.idBalanceteConiecp
              WHERE it.idGrupoConiecp = :grupo
                AND it.tipoContabil = 1
                AND it.idIecp = 0
                AND b.ano BETWEEN :anoIni AND :anoFim',
            [':grupo' => Pagamento15Regras::GRUPO_REGISTRADO_CONIECP, ':anoIni' => $anoIni, ':anoFim' => $anoFim]
        );
        foreach ($semVinculo as $linha) {
            $ano = (int) $linha['ano'];
            $mes = (int) $linha['mes'];
            $identificado = $this->identificarPorCnpj((string) $linha['descricao'], (string) $linha['dia']);
            if ($identificado === null) {
                $naoIdentificado[$ano][$mes] = ($naoIdentificado[$ano][$mes] ?? 0.0) + (float) $linha['valor'];
                continue;
            }
            $this->acumular($valores, $identificado['idIecp'], $ano, $mes, (float) $linha['valor']);
        }

        return ['valores' => $valores, 'naoIdentificado' => $naoIdentificado];
    }

    public function statusBalancetes(int $anoIni, int $anoFim): array
    {
        [$inicio, $fim] = $this->faixaOrigem($anoIni, $anoFim);
        $status = ['coniecp' => [], 'sede' => [], 'congregacoes' => []];

        foreach ($this->buscar(
            'SELECT ano, CAST(mes AS UNSIGNED) AS mes, statusBalancete
               FROM balancete_coniecp
              WHERE ano BETWEEN :anoIni AND :anoFim',
            [':anoIni' => $anoIni, ':anoFim' => $anoFim]
        ) as $linha) {
            $status['coniecp'][(int) $linha['ano']][(int) $linha['mes']] = (string) $linha['statusBalancete'];
        }

        foreach ($this->buscar(
            "SELECT idIecp, ano, CAST(mes AS UNSIGNED) AS mes, statusBalancete
               FROM balancete
              WHERE mes <> ''
                AND ano * 100 + CAST(mes AS UNSIGNED) BETWEEN :inicio AND :fim",
            [':inicio' => $inicio, ':fim' => $fim]
        ) as $linha) {
            $destino = $this->destino((int) $linha['ano'], (int) $linha['mes']);
            if ($destino !== null) {
                $status['sede'][(int) $linha['idIecp']][$destino['ano']][$destino['mes']] = (string) $linha['statusBalancete'];
            }
        }

        foreach ($this->buscar(
            'SELECT idIecp, ano, mes, statusBalancete
               FROM balancete_congregacao
              WHERE ano * 100 + mes BETWEEN :inicio AND :fim',
            [':inicio' => $inicio, ':fim' => $fim]
        ) as $linha) {
            $destino = $this->destino((int) $linha['ano'], (int) $linha['mes']);
            if ($destino !== null) {
                $status['congregacoes'][(int) $linha['idIecp']][$destino['ano']][$destino['mes']][] = (string) $linha['statusBalancete'];
            }
        }

        return $status;
    }

    /** Lançamentos dos dois livros por trás de uma célula (mês CONIECP). */
    public function lancamentos(int $idIecp, int $ano, int $mes): array
    {
        $coniecp = [];
        foreach ($this->buscar(
            'SELECT it.idIecp, it.dia, it.descricao, it.valor, b.statusBalancete
               FROM balancete_coniecp b
               JOIN itembalancete_coniecp it ON it.idBalanceteConiecp = b.idBalanceteConiecp
              WHERE it.idGrupoConiecp = :grupo
                AND it.tipoContabil = 1
                AND b.ano = :ano
                AND CAST(b.mes AS UNSIGNED) = :mes
                AND it.idIecp IN (:idIecp, 0)
              ORDER BY it.dia, it.idItem',
            [':grupo' => Pagamento15Regras::GRUPO_REGISTRADO_CONIECP, ':ano' => $ano, ':mes' => $mes, ':idIecp' => $idIecp]
        ) as $linha) {
            $por = 'idIecp';
            if ((int) $linha['idIecp'] === 0) {
                $identificado = $this->identificarPorCnpj((string) $linha['descricao'], (string) $linha['dia']);
                if ($identificado === null || $identificado['idIecp'] !== $idIecp) {
                    continue;
                }
                $por = $identificado['por'];
            }
            $coniecp[] = [
                'data' => (string) $linha['dia'],
                'descricao' => trim((string) $linha['descricao']),
                'valor' => round((float) $linha['valor'], 2),
                'statusBalancete' => (string) $linha['statusBalancete'],
                'identificadoPor' => $por,
            ];
        }

        $origem = Pagamento15Regras::mesOrigemIecp($ano, $mes);
        $parametros = [
            ':idIecp' => $idIecp,
            ':ano' => $origem['ano'],
            ':mes' => $origem['mes'],
            ':grupo' => Pagamento15Regras::GRUPO_15_IECP,
        ];

        $sede = $this->buscar(
            'SELECT it.dia, it.descricao, it.valor, b.statusBalancete, b.ano, CAST(b.mes AS UNSIGNED) AS mes,
                    (SELECT r.local FROM recibo_armazenado_iecp r
                      WHERE r.idItem_balancete = it.idItem
                      ORDER BY r.idRecibo_arm LIMIT 1) AS recibo
               FROM balancete b
               JOIN itembalancete it ON it.idBalancete = b.idBalancete
              WHERE b.idIecp = :idIecp
                AND b.ano = :ano
                AND CAST(b.mes AS UNSIGNED) = :mes
                AND it.idGrupo = :grupo
              ORDER BY it.dia, it.idItem',
            $parametros
        );
        $congregacoes = $this->buscar(
            'SELECT c.congregacao, it.dia, it.descricao, it.valor, bc.statusBalancete, bc.ano, bc.mes,
                    (SELECT r.local FROM recibo_armazenado_congregacao r
                      WHERE r.idItem_balancete = it.idItem
                      ORDER BY r.idRecibo_arm LIMIT 1) AS recibo
               FROM balancete_congregacao bc
               JOIN itembalancete_congregacao it ON it.idBalancete_Congregacao = bc.idBalancete_Congregacao
               LEFT JOIN congregacao c ON c.idCongregacao = bc.idCongregacao
              WHERE bc.idIecp = :idIecp
                AND bc.ano = :ano
                AND bc.mes = :mes
                AND it.idGrupo = :grupo
              ORDER BY c.congregacao, it.dia, it.idItem',
            $parametros
        );

        $iecp = [];
        foreach ($sede as $linha) {
            $iecp[] = $this->itemIecp('sede', 'Sede', $linha);
        }
        foreach ($congregacoes as $linha) {
            $iecp[] = $this->itemIecp('congregacao', trim((string) ($linha['congregacao'] ?? 'Congregação')), $linha);
        }

        return ['coniecp' => $coniecp, 'iecp' => $iecp];
    }

    /** Soma itens da sede e das congregações por IECP e mês CONIECP. */
    private function somarIecp(string $condicaoItem, int $anoIni, int $anoFim, float $fator): array
    {
        [$inicio, $fim] = $this->faixaOrigem($anoIni, $anoFim);
        $linhas = $this->buscar(
            "SELECT b.idIecp, b.ano, CAST(b.mes AS UNSIGNED) AS mes, SUM(it.valor) AS valor
               FROM balancete b
               JOIN itembalancete it ON it.idBalancete = b.idBalancete
              WHERE {$condicaoItem}
                AND b.mes <> ''
                AND b.ano * 100 + CAST(b.mes AS UNSIGNED) BETWEEN :inicioSede AND :fimSede
              GROUP BY b.idIecp, b.ano, b.mes
             UNION ALL
             SELECT bc.idIecp, bc.ano, bc.mes, SUM(it.valor)
               FROM balancete_congregacao bc
               JOIN itembalancete_congregacao it ON it.idBalancete_Congregacao = bc.idBalancete_Congregacao
              WHERE {$condicaoItem}
                AND bc.ano * 100 + bc.mes BETWEEN :inicioCongregacao AND :fimCongregacao
              GROUP BY bc.idIecp, bc.ano, bc.mes",
            [':inicioSede' => $inicio, ':fimSede' => $fim, ':inicioCongregacao' => $inicio, ':fimCongregacao' => $fim]
        );

        $soma = [];
        $invalidos = 0;
        foreach ($linhas as $linha) {
            $destino = $this->destino((int) $linha['ano'], (int) $linha['mes']);
            if ($destino === null) {
                $invalidos++;
                continue;
            }
            $this->acumular($soma, (int) $linha['idIecp'], $destino['ano'], $destino['mes'], (float) $linha['valor'] * $fator);
        }
        if ($invalidos > 0) {
            error_log("pagamento15: {$invalidos} grupo(s) de balancete com mês inválido ignorado(s).");
        }

        return $soma;
    }

    /** Faixa ano*100+mes dos balancetes IECP que caem nos anos CONIECP informados. */
    private function faixaOrigem(int $anoIni, int $anoFim): array
    {
        return [($anoIni - 1) * 100 + 12, $anoFim * 100 + 11];
    }

    /** @return array{ano:int, mes:int}|null */
    private function destino(int $ano, int $mes): ?array
    {
        return $mes >= 1 && $mes <= 12 ? Pagamento15Regras::mesConiecp($ano, $mes) : null;
    }

    private function acumular(array &$destino, int $idIecp, int $ano, int $mes, float $valor): void
    {
        $destino[$idIecp][$ano][$mes] = ($destino[$idIecp][$ano][$mes] ?? 0.0) + $valor;
    }

    /** @return array{idIecp:int, por:string}|null */
    private function identificarPorCnpj(string $descricao, string $dia): ?array
    {
        $cnpj = Pagamento15Regras::extrairCnpj($descricao);
        if ($cnpj === null) {
            return null;
        }

        $this->historicoCnpj ??= $this->buscar('SELECT idIecp, cnpj, vigente_de, vigente_ate FROM iecp_cnpj_historico');
        foreach ($this->historicoCnpj as $historico) {
            if ($historico['cnpj'] === $cnpj
                && ($historico['vigente_de'] === null || $dia >= $historico['vigente_de'])
                && ($historico['vigente_ate'] === null || $dia <= $historico['vigente_ate'])) {
                return ['idIecp' => (int) $historico['idIecp'], 'por' => 'cnpj_historico'];
            }
        }

        if ($this->cnpjAtual === null) {
            $this->cnpjAtual = [];
            foreach ($this->buscar('SELECT idIecp, cnpj FROM iecp') as $linha) {
                $this->cnpjAtual[trim((string) $linha['cnpj'])] = (int) $linha['idIecp'];
            }
        }
        $idIecp = $this->cnpjAtual[$cnpj] ?? null;

        return $idIecp === null ? null : ['idIecp' => $idIecp, 'por' => 'cnpj_atual'];
    }

    private function itemIecp(string $tipo, string $origem, array $linha): array
    {
        return [
            'tipo' => $tipo,
            'origem' => $origem,
            'mesBalancete' => sprintf('%02d/%d', (int) $linha['mes'], (int) $linha['ano']),
            'data' => (string) $linha['dia'],
            'descricao' => trim((string) $linha['descricao']),
            'valor' => round((float) $linha['valor'], 2),
            'statusBalancete' => (string) $linha['statusBalancete'],
            'comprovanteUrl' => $linha['recibo'] !== null && $linha['recibo'] !== ''
                ? self::PASTA_RECIBOS . ltrim((string) $linha['recibo'], '/')
                : null,
        ];
    }

    /** @return list<array<string, mixed>> */
    private function buscar(string $sql, array $parametros = []): array
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($parametros);

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `php -l classes/Pagamento15.php` e o comando do Step 2.
Expected: `No syntax errors detected` e `pagamento15_consultas_test: OK`

- [ ] **Step 5: Commit**

```bash
rtk git add classes/Pagamento15.php tests/pagamento15/pagamento15_consultas_test.php
rtk git commit -m "feat(pagamento15): consultas agregadas por mês do balancete com identificação por CNPJ"
```

---

### Task 5: Endpoints JSON

**Files:**
- Create: `coniecp/tesouraria/reuniao_dados/api/_inicio.php`
- Create: `coniecp/tesouraria/reuniao_dados/api/dadosMensal.php`
- Create: `coniecp/tesouraria/reuniao_dados/api/dadosHistorico.php`
- Create: `coniecp/tesouraria/reuniao_dados/api/dadosLancamentos.php`

**Interfaces:**
- Consumes: `Pagamento15Regras`, `Pagamento15`, `Pagamento15Relatorio` (Tasks 2–4); `valida_sessao_all.php` (define `$conexao`), `validar_usuario_coniecp.php`, `validar_usuario_iecp.php` (define `$idIecp`), `Classes\Csrf`.
- Produces: `POST coniecp/tesouraria/reuniao_dados/api/{dadosMensal,dadosHistorico,dadosLancamentos}.php` com `csrf_token`; resposta `{"ok": bool, "mensagem": string, "dados": object|null}`; parâmetros: mensal `idIecp`, `ano`; histórico `idIecp`; lançamentos `idIecp` (≥ 1), `ano`, `mes`.

- [ ] **Step 1: `_inicio.php`**

```php
<?php

declare(strict_types=1);

/*
 * Início comum dos endpoints da conferência dos 15%:
 * sessão, método, CSRF, perfil (CONIECP ou IECP) e resposta JSON.
 */

$pagamento15Raiz = dirname(__DIR__, 4);

require_once $pagamento15Raiz . '/classes/StartSecureSession.php';

header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store');

function pagamento15Responder(bool $ok, string $mensagem, int $status = 200, ?array $dados = null): never
{
    http_response_code($status);
    echo json_encode(
        ['ok' => $ok, 'mensagem' => $mensagem, 'dados' => $dados],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
    );
    exit;
}

function pagamento15Executar(callable $acao): never
{
    try {
        $dados = $acao();
    } catch (InvalidArgumentException) {
        pagamento15Responder(false, 'Filtros inválidos. Revise a IECP, o ano e o mês.', 422);
    } catch (DomainException) {
        pagamento15Responder(false, 'A IECP selecionada não está disponível para este usuário.', 403);
    } catch (Throwable $erro) {
        error_log('pagamento15: ' . $erro->getMessage() . ' em ' . $erro->getFile() . ':' . $erro->getLine());
        pagamento15Responder(false, 'Não foi possível carregar a conferência. Tente novamente.', 500);
    }

    pagamento15Responder(true, 'ok', 200, $dados);
}

if (empty($_SESSION['email']) || empty($_SESSION['senha'])) {
    pagamento15Responder(false, 'Sua sessão expirou. Entre novamente no sistema.', 401);
}
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    pagamento15Responder(false, 'Método não permitido.', 405);
}

require_once $pagamento15Raiz . '/valida_sessao_all.php';
require_once $pagamento15Raiz . '/classes/Csrf.php';
require_once $pagamento15Raiz . '/classes/Pagamento15Regras.php';
require_once $pagamento15Raiz . '/classes/Pagamento15.php';
require_once $pagamento15Raiz . '/classes/Pagamento15Relatorio.php';

if (!Classes\Csrf::validateToken((string) ($_POST['csrf_token'] ?? ''))) {
    pagamento15Responder(false, 'Sua sessão de segurança expirou. Atualize a página e tente novamente.', 403);
}

$pagamento15Niveis = array_map('intval', array_values($_SESSION['nivelAcesso'] ?? []));
$pagamento15IdIecpSessao = null;
if (in_array(1, $pagamento15Niveis, true)) {
    require_once $pagamento15Raiz . '/validar_usuario_coniecp.php';
} else {
    require_once $pagamento15Raiz . '/validar_usuario_iecp.php';
    $pagamento15IdIecpSessao = isset($idIecp) ? (int) $idIecp : null;
}

$pagamento15Hoje = new DateTimeImmutable('now');
$pagamento15AnoCorrente = (int) $pagamento15Hoje->format('Y');
$pagamento15MesCorrente = (int) $pagamento15Hoje->format('n');
```

- [ ] **Step 2: `dadosMensal.php`**

```php
<?php

declare(strict_types=1);

require __DIR__ . '/_inicio.php';

pagamento15Executar(static function () use ($conexao, $pagamento15Niveis, $pagamento15IdIecpSessao, $pagamento15AnoCorrente, $pagamento15MesCorrente): array {
    $ano = Pagamento15Regras::validarAno($_POST['ano'] ?? null, $pagamento15AnoCorrente);
    $idIecp = Pagamento15Regras::resolverIecp($pagamento15Niveis, $pagamento15IdIecpSessao, $_POST['idIecp'] ?? null, true);
    $consultas = new Pagamento15($conexao);

    return (new Pagamento15Relatorio($pagamento15AnoCorrente, $pagamento15MesCorrente))->mensal(
        $ano,
        $consultas->iecps($idIecp),
        $consultas->registradoConiecp($ano, $ano),
        $consultas->declaradoIecp($ano, $ano),
        $consultas->devidoArrecadacao($ano, $ano),
        $consultas->statusBalancetes($ano, $ano)
    );
});
```

- [ ] **Step 3: `dadosHistorico.php`**

```php
<?php

declare(strict_types=1);

require __DIR__ . '/_inicio.php';

pagamento15Executar(static function () use ($conexao, $pagamento15Niveis, $pagamento15IdIecpSessao, $pagamento15AnoCorrente, $pagamento15MesCorrente): array {
    $idIecp = Pagamento15Regras::resolverIecp($pagamento15Niveis, $pagamento15IdIecpSessao, $_POST['idIecp'] ?? null, true);
    $janela = Pagamento15Regras::janelaHistorico($pagamento15AnoCorrente);
    $consultas = new Pagamento15($conexao);

    return (new Pagamento15Relatorio($pagamento15AnoCorrente, $pagamento15MesCorrente))->historico(
        $janela['anoIni'],
        $janela['anoFim'],
        $consultas->iecps($idIecp),
        $consultas->registradoConiecp($janela['anoIni'], $janela['anoFim']),
        $consultas->declaradoIecp($janela['anoIni'], $janela['anoFim']),
        $consultas->devidoArrecadacao($janela['anoIni'], $janela['anoFim']),
        $consultas->statusBalancetes($janela['anoIni'], $janela['anoFim'])
    );
});
```

- [ ] **Step 4: `dadosLancamentos.php`**

```php
<?php

declare(strict_types=1);

require __DIR__ . '/_inicio.php';

pagamento15Executar(static function () use ($conexao, $pagamento15Niveis, $pagamento15IdIecpSessao, $pagamento15AnoCorrente, $pagamento15MesCorrente): array {
    $idIecp = Pagamento15Regras::resolverIecp($pagamento15Niveis, $pagamento15IdIecpSessao, $_POST['idIecp'] ?? null, false);
    $ano = Pagamento15Regras::validarAno($_POST['ano'] ?? null, $pagamento15AnoCorrente);
    $mes = Pagamento15Regras::validarMes($_POST['mes'] ?? null);
    $consultas = new Pagamento15($conexao);
    $iecp = $consultas->iecps($idIecp);
    if ($iecp === []) {
        throw new InvalidArgumentException('IECP_INVALIDA');
    }

    return (new Pagamento15Relatorio($pagamento15AnoCorrente, $pagamento15MesCorrente))->detalhamento(
        $ano,
        $mes,
        $iecp[0]['nome'],
        $consultas->lancamentos($idIecp, $ano, $mes)
    );
});
```

- [ ] **Step 5: Sintaxe**

Run: `for f in coniecp/tesouraria/reuniao_dados/api/*.php; do php -l "$f"; done`
Expected: `No syntax errors detected` para os quatro.

- [ ] **Step 6: Fumaça sem sessão**

Descobrir a URL base do WAMP (tentar `http://localhost/sisconiecp2/`; se 404, perguntar ao usuário).

Run: `curl -s -X POST -w ' %{http_code}' http://localhost/sisconiecp2/coniecp/tesouraria/reuniao_dados/api/dadosMensal.php`
Expected: `{"ok":false,"mensagem":"Sua sessão expirou. Entre novamente no sistema.","dados":null} 401`

(Os casos 403/422/405 com sessão são verificados no navegador na Task 7, Step 6.)

- [ ] **Step 7: Commit**

```bash
rtk git add coniecp/tesouraria/reuniao_dados/api/_inicio.php coniecp/tesouraria/reuniao_dados/api/dadosMensal.php coniecp/tesouraria/reuniao_dados/api/dadosHistorico.php coniecp/tesouraria/reuniao_dados/api/dadosLancamentos.php
rtk git commit -m "feat(pagamento15): endpoints JSON mensal, histórico e detalhamento"
```

---

### Task 6: Conferência na base real — PARADA com o usuário

**Files:**
- Create: `tests/pagamento15/pagamento15_conferencia.php`

**Interfaces:**
- Consumes: `Pagamento15`, `Pagamento15Regras` (Tasks 2 e 4), `Classes\Connect` (base real, somente SELECT), `tests/pagamento15/assercoes.php`.

A conferência tem quatro partes:
- **A.** Conservação: os totais novos batem, centavo a centavo, com consultas independentes escritas de outro jeito (ano fiscal calculado no SQL).
- **B.** Lógica antiga dos anuais ④ e ⑥ (algoritmo de ano fiscal com estado) × nova: toda diferença precisa ser explicada por um de três mecanismos, detectados nos dados:
  1. o próprio algoritmo antigo difere da fórmula de ano fiscal;
  2. o item está datado num ano fiscal diferente do seu balancete;
  3. grupo 34.
- **C.** Lógica antiga da tabela ① (CNPJ atual na descrição, mês da data) × nova: toda diferença precisa vir de lançamento cuja IECP mudou pela regra nova.
- **D.** Casos fixos da spec (seção 9).

- [ ] **Step 1: Escrever o script**

```php
<?php

declare(strict_types=1);

/*
 * Conferência SOMENTE-LEITURA na base real (spec, seções 8.4 e 9).
 * Uso: php tests/pagamento15/pagamento15_conferencia.php
 * Sai com 1 se aparecer diferença que nenhum mecanismo conhecido explica.
 */

chdir(dirname(__DIR__, 2));
require_once 'classes/Connect.php';
require_once 'classes/Pagamento15Regras.php';
require_once 'classes/Pagamento15.php';
require_once __DIR__ . '/assercoes.php';

$pdo = Classes\Connect::getInstance();
$consultas = new Pagamento15($pdo);
$janela = Pagamento15Regras::janelaHistorico((int) date('Y'));
[$anoIni, $anoFim] = [$janela['anoIni'], $janela['anoFim']];
$ids = array_column($consultas->iecps(0), 'id');
$inesperadas = 0;

function p15Sql(PDO $pdo, string $sql, array $parametros = []): array
{
    $stmt = $pdo->prepare($sql);
    $stmt->execute($parametros);

    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

/** [id][ano][mes] → ["id:ano" => valor] só para as IECPs listadas e a janela. */
function p15PorAno(array $porMes, array $ids, int $anoIni, int $anoFim): array
{
    $saida = [];
    foreach ($porMes as $id => $anos) {
        if (!in_array((int) $id, $ids, true)) {
            continue;
        }
        foreach ($anos as $ano => $meses) {
            if ($ano >= $anoIni && $ano <= $anoFim) {
                $saida["{$id}:{$ano}"] = ($saida["{$id}:{$ano}"] ?? 0.0) + array_sum($meses);
            }
        }
    }

    return $saida;
}

/** Linhas {idIecp, anoFiscal, valor} → ["id:ano" => valor]. */
function p15Mapa(array $linhas, array $ids, int $anoIni, int $anoFim, float $fator = 1.0): array
{
    $saida = [];
    foreach ($linhas as $linha) {
        $id = (int) $linha['idIecp'];
        $ano = (int) $linha['anoFiscal'];
        if (in_array($id, $ids, true) && $ano >= $anoIni && $ano <= $anoFim) {
            $saida["{$id}:{$ano}"] = ($saida["{$id}:{$ano}"] ?? 0.0) + (float) $linha['valor'] * $fator;
        }
    }

    return $saida;
}

function p15Comparar(string $titulo, array $novo, array $referencia, array $explicacoes): int
{
    $inesperadas = 0;
    $explicadas = 0;
    $chaves = array_unique(array_merge(array_keys($novo), array_keys($referencia)));
    sort($chaves);
    foreach ($chaves as $chave) {
        $diferenca = round(($novo[$chave] ?? 0.0) - ($referencia[$chave] ?? 0.0), 2);
        if (abs($diferenca) < 0.005) {
            continue;
        }
        $motivo = $explicacoes[$chave] ?? null;
        if ($motivo !== null) {
            $explicadas++;
        } else {
            $inesperadas++;
        }
        printf(
            "  %-10s %-12s novo=%13s  ref=%13s  dif=%11s  %s\n",
            $motivo !== null ? 'explicada' : 'INESPERADA',
            $chave,
            number_format($novo[$chave] ?? 0.0, 2, ',', '.'),
            number_format($referencia[$chave] ?? 0.0, 2, ',', '.'),
            number_format($diferenca, 2, ',', '.'),
            $motivo ?? ''
        );
    }
    printf("%s: %d explicada(s), %d inesperada(s)\n\n", $titulo, $explicadas, $inesperadas);

    return $inesperadas;
}

/** Algoritmo antigo de ano fiscal com estado (pagRegBalTabela2/4.php, linhas 92–172). */
function p15AlgoritmoAntigo(array $linhas, int $anoReferencia, float $fator, array $ids): array
{
    $resultado = [];
    $idRef = 0;
    $fiscalInicio = '';
    $fiscalFim = '';
    $indice = 0;
    $anoInicio = 0;
    foreach ($linhas as $linha) {
        $id = (int) $linha['idIecp'];
        if (!in_array($id, $ids, true)) {
            continue;
        }
        $ano = (int) $linha['ano'];
        $dia = (string) $linha['dia'];
        $valor = (float) $linha['valor'] * $fator;
        if ($idRef !== $id) {
            $fiscalInicio = ($anoReferencia - 1) . '-12-01';
            $fiscalFim = $anoReferencia . '-11-30';
            $idRef = $id;
            $indice = $anoReferencia;
            $anoInicio = $anoReferencia;
        }
        if ($dia >= $fiscalInicio && $dia <= $fiscalFim) {
            $resultado["{$id}:{$indice}"] = ($resultado["{$id}:{$indice}"] ?? 0.0) + $valor;
        } elseif ($dia > $fiscalFim) {
            $anoInicio = $ano > $anoInicio ? ($ano - $anoInicio > 1 ? $ano - 1 : $ano) : $ano;
            $fiscalInicio = $anoInicio . '-12-01';
            $fiscalFim = ($anoInicio + 1) . '-11-30';
            $indice = $anoInicio + 1;
            $resultado["{$id}:{$indice}"] = ($resultado["{$id}:{$indice}"] ?? 0.0) + $valor;
        }
    }

    return $resultado;
}

/** Mesmo dado da lógica antiga, somado pela fórmula ano + (mês da data = 12). */
function p15FormulaPorData(array $linhas, float $fator, array $ids, int $anoIni, int $anoFim): array
{
    $saida = [];
    foreach ($linhas as $linha) {
        $id = (int) $linha['idIecp'];
        $data = new DateTimeImmutable((string) $linha['dia']);
        $ano = (int) $data->format('Y') + ((int) $data->format('n') === 12 ? 1 : 0);
        if (in_array($id, $ids, true) && $ano >= $anoIni && $ano <= $anoFim) {
            $saida["{$id}:{$ano}"] = ($saida["{$id}:{$ano}"] ?? 0.0) + (float) $linha['valor'] * $fator;
        }
    }

    return $saida;
}

/** Marca as chaves em que o algoritmo antigo difere da fórmula (defeito do estado). */
function p15ExplicarAlgoritmo(array $antigo, array $formula, array &$explicacoes): void
{
    foreach (array_unique(array_merge(array_keys($antigo), array_keys($formula))) as $chave) {
        if (abs(($antigo[$chave] ?? 0.0) - ($formula[$chave] ?? 0.0)) >= 0.005) {
            $explicacoes[$chave] = 'algoritmo antigo de ano fiscal';
        }
    }
}

$inicioJanela = ($anoIni - 1) . '-12-01';
$fimJanela = $anoFim . '-11-30';
$tempo = microtime(true);
$declaradoNovo = p15PorAno($consultas->declaradoIecp($anoIni, $anoFim), $ids, $anoIni, $anoFim);
$devidoNovo = p15PorAno($consultas->devidoArrecadacao($anoIni, $anoFim), $ids, $anoIni, $anoFim);
$registradoJanela = $consultas->registradoConiecp($anoIni, $anoFim);
printf("Janela %d–%d; consultas novas em %.0f ms\n\n", $anoIni, $anoFim, (microtime(true) - $tempo) * 1000);

// ---------------- A. Conservação ----------------
$fiscalSede = "b.ano + (CAST(b.mes AS UNSIGNED) = 12)";
$fiscalCongregacao = 'bc.ano + (bc.mes = 12)';
$somaIndependente = static fn (string $condicao): string => "
    SELECT b.idIecp, {$fiscalSede} AS anoFiscal, SUM(it.valor) AS valor
      FROM balancete b JOIN itembalancete it ON it.idBalancete = b.idBalancete
     WHERE {$condicao} AND b.mes <> '' GROUP BY 1, 2
    UNION ALL
    SELECT bc.idIecp, {$fiscalCongregacao}, SUM(it.valor)
      FROM balancete_congregacao bc
      JOIN itembalancete_congregacao it ON it.idBalancete_Congregacao = bc.idBalancete_Congregacao
     WHERE {$condicao} GROUP BY 1, 2";

$inesperadas += p15Comparar(
    'A1 declarado (novo × SQL independente)',
    $declaradoNovo,
    p15Mapa(p15Sql($pdo, $somaIndependente('it.idGrupo = 21')), $ids, $anoIni, $anoFim),
    []
);
$inesperadas += p15Comparar(
    'A2 devido (novo × SQL independente)',
    $devidoNovo,
    p15Mapa(p15Sql($pdo, $somaIndependente('it.tipoContabil = 1 AND it.idGrupo NOT IN (32, 34)')), $ids, $anoIni, $anoFim, 0.15),
    []
);

$registradoPorAnoNovo = [];
foreach ($registradoJanela['valores'] as $anos) {
    foreach ($anos as $ano => $meses) {
        $registradoPorAnoNovo["total:{$ano}"] = ($registradoPorAnoNovo["total:{$ano}"] ?? 0.0) + array_sum($meses);
    }
}
foreach ($registradoJanela['naoIdentificado'] as $ano => $meses) {
    $registradoPorAnoNovo["total:{$ano}"] = ($registradoPorAnoNovo["total:{$ano}"] ?? 0.0) + array_sum($meses);
}
$registradoPorAnoIndependente = [];
foreach (p15Sql($pdo,
    'SELECT b.ano, SUM(it.valor) AS valor
       FROM balancete_coniecp b JOIN itembalancete_coniecp it ON it.idBalanceteConiecp = b.idBalanceteConiecp
      WHERE it.idGrupoConiecp = 1 AND it.tipoContabil = 1 AND b.ano BETWEEN :i AND :f GROUP BY b.ano',
    [':i' => $anoIni, ':f' => $anoFim]
) as $linha) {
    $registradoPorAnoIndependente['total:' . $linha['ano']] = (float) $linha['valor'];
}
$inesperadas += p15Comparar('A3 registrado total por ano (nada se perde)', $registradoPorAnoNovo, $registradoPorAnoIndependente, []);

// ---------------- B. Lógica antiga dos anuais ----------------
$explicacoesDiaBalancete = static function (PDO $pdo, string $condicao) use ($fiscalSede, $fiscalCongregacao): array {
    $explicacoes = [];
    foreach (p15Sql($pdo, "
        SELECT b.idIecp, YEAR(it.dia) + (MONTH(it.dia) = 12) AS anoData, {$fiscalSede} AS anoBalancete
          FROM balancete b JOIN itembalancete it ON it.idBalancete = b.idBalancete
         WHERE {$condicao} AND b.mes <> ''
        HAVING anoData <> anoBalancete
        UNION ALL
        SELECT bc.idIecp, YEAR(it.dia) + (MONTH(it.dia) = 12) AS anoData, {$fiscalCongregacao} AS anoBalancete
          FROM balancete_congregacao bc
          JOIN itembalancete_congregacao it ON it.idBalancete_Congregacao = bc.idBalancete_Congregacao
         WHERE {$condicao}
        HAVING anoData <> anoBalancete") as $linha) {
        $explicacoes[$linha['idIecp'] . ':' . $linha['anoData']] = 'item datado fora do ano fiscal do balancete';
        $explicacoes[$linha['idIecp'] . ':' . $linha['anoBalancete']] = 'item datado fora do ano fiscal do balancete';
    }

    return $explicacoes;
};

// B1: tabela ④ antiga (Iecp::buscaValores15PorAno).
$antigas15 = p15Sql($pdo, "
    (SELECT it.valor, b.idIecp, it.dia, YEAR(it.dia) AS ano
       FROM itembalancete it JOIN balancete b ON it.idBalancete = b.idBalancete
       JOIN iecp i ON b.idIecp = i.idIecp AND i.ativo = 1
      WHERE it.dia BETWEEN :i1 AND :f1 AND it.idGrupo = 21)
    UNION ALL
    (SELECT itcg.valor, bc.idIecp, itcg.dia, YEAR(itcg.dia) AS ano
       FROM itembalancete_congregacao itcg
       JOIN balancete_congregacao bc ON bc.idBalancete_Congregacao = itcg.idBalancete_Congregacao
       JOIN iecp i ON bc.idIecp = i.idIecp AND i.ativo = 1
      WHERE itcg.dia BETWEEN :i2 AND :f2 AND itcg.idGrupo = 21)
    ORDER BY idIecp, dia", [':i1' => $inicioJanela, ':f1' => $fimJanela, ':i2' => $inicioJanela, ':f2' => $fimJanela]);
$antigo4 = p15AlgoritmoAntigo($antigas15, $anoIni, 1.0, $ids);
$explicacoes4 = $explicacoesDiaBalancete($pdo, 'it.idGrupo = 21');
p15ExplicarAlgoritmo($antigo4, p15FormulaPorData($antigas15, 1.0, $ids, $anoIni, $anoFim), $explicacoes4);
$inesperadas += p15Comparar('B1 tabela ④ antiga × declarado novo', $declaradoNovo, $antigo4, $explicacoes4);

// B2: tabela ⑥ antiga (Iecp::buscaValores15BaseArrecadacao; incluía o grupo 34).
$antigasBase = p15Sql($pdo, "
    (SELECT it.valor, b.idIecp, it.dia, YEAR(it.dia) AS ano
       FROM itembalancete it JOIN balancete b ON it.idBalancete = b.idBalancete
      WHERE it.dia BETWEEN :i1 AND :f1 AND it.idGrupo <> 32 AND it.tipoContabil = 1)
    UNION ALL
    (SELECT itcg.valor, bc.idIecp, itcg.dia, YEAR(itcg.dia) AS ano
       FROM itembalancete_congregacao itcg
       JOIN balancete_congregacao bc ON bc.idBalancete_Congregacao = itcg.idBalancete_Congregacao
      WHERE itcg.dia BETWEEN :i2 AND :f2 AND itcg.idGrupo <> 32 AND itcg.tipoContabil = 1)
    ORDER BY idIecp, dia", [':i1' => $inicioJanela, ':f1' => $fimJanela, ':i2' => $inicioJanela, ':f2' => $fimJanela]);
$antigo6 = p15AlgoritmoAntigo($antigasBase, $anoIni, 0.15, $ids);
$explicacoes6 = $explicacoesDiaBalancete($pdo, 'it.tipoContabil = 1 AND it.idGrupo <> 32');
p15ExplicarAlgoritmo($antigo6, p15FormulaPorData($antigasBase, 0.15, $ids, $anoIni, $anoFim), $explicacoes6);
foreach (p15Sql($pdo, $somaIndependente('it.idGrupo = 34')) as $linha) {
    $explicacoes6[$linha['idIecp'] . ':' . $linha['anoFiscal']] = 'grupo 34 saiu da base';
}
foreach (p15Sql($pdo, "
    SELECT b.idIecp, YEAR(it.dia) + (MONTH(it.dia) = 12) AS anoFiscal FROM balancete b
      JOIN itembalancete it ON it.idBalancete = b.idBalancete WHERE it.idGrupo = 34
    UNION ALL
    SELECT bc.idIecp, YEAR(it.dia) + (MONTH(it.dia) = 12) FROM balancete_congregacao bc
      JOIN itembalancete_congregacao it ON it.idBalancete_Congregacao = bc.idBalancete_Congregacao WHERE it.idGrupo = 34") as $linha) {
    $explicacoes6[$linha['idIecp'] . ':' . $linha['anoFiscal']] = 'grupo 34 saiu da base';
}
$inesperadas += p15Comparar('B2 tabela ⑥ antiga × devido novo', $devidoNovo, $antigo6, $explicacoes6);

// ---------------- C. Tabela ① antiga (CNPJ atual, mês da data) ----------------
$cnpjAtual = [];
foreach (p15Sql($pdo, 'SELECT idIecp, cnpj FROM iecp') as $linha) {
    $cnpjAtual[trim((string) $linha['cnpj'])] = (int) $linha['idIecp'];
}
$historico = p15Sql($pdo, 'SELECT idIecp, cnpj, vigente_de, vigente_ate FROM iecp_cnpj_historico');
$idNovo = static function (int $idColuna, string $descricao, string $dia) use ($historico, $cnpjAtual): ?int {
    if ($idColuna !== 0) {
        return $idColuna;
    }
    $cnpj = Pagamento15Regras::extrairCnpj($descricao);
    if ($cnpj === null) {
        return null;
    }
    foreach ($historico as $h) {
        if ($h['cnpj'] === $cnpj && ($h['vigente_de'] === null || $dia >= $h['vigente_de']) && ($h['vigente_ate'] === null || $dia <= $h['vigente_ate'])) {
            return (int) $h['idIecp'];
        }
    }

    return $cnpjAtual[$cnpj] ?? null;
};

$anoCorrente = (int) date('Y');
$antigo1 = [];
$explicacoes1 = [];
foreach (p15Sql($pdo,
    'SELECT it.idIecp, it.dia, it.descricao, it.valor, b.ano, CAST(b.mes AS UNSIGNED) AS mes
       FROM balancete_coniecp b JOIN itembalancete_coniecp it ON it.idBalanceteConiecp = b.idBalanceteConiecp
      WHERE it.idGrupoConiecp = 1 AND it.tipoContabil = 1 AND b.ano BETWEEN :i AND :f',
    [':i' => Pagamento15Regras::ANO_MINIMO, ':f' => $anoCorrente]
) as $linha) {
    $cnpj = Pagamento15Regras::extrairCnpj((string) $linha['descricao']);
    $idAntigo = $cnpj !== null ? ($cnpjAtual[$cnpj] ?? null) : null;
    $data = new DateTimeImmutable((string) $linha['dia']);
    if ($idAntigo !== null && in_array($idAntigo, $ids, true)) {
        $chave = $idAntigo . ':' . $data->format('Y') . ':' . (int) $data->format('n');
        $antigo1[$chave] = ($antigo1[$chave] ?? 0.0) + (float) $linha['valor'];
    }
    $novo = $idNovo((int) $linha['idIecp'], (string) $linha['descricao'], (string) $linha['dia']);
    $mesBalancete = (int) $linha['mes'];
    if ($novo !== $idAntigo || (int) $data->format('n') !== $mesBalancete) {
        foreach ([$idAntigo, $novo] as $id) {
            if ($id !== null) {
                $explicacoes1[$id . ':' . $data->format('Y') . ':' . (int) $data->format('n')] = 'IECP ou mês mudou pela regra nova';
                $explicacoes1[$id . ':' . $linha['ano'] . ':' . $mesBalancete] = 'IECP ou mês mudou pela regra nova';
            }
        }
    }
}
$novo1 = [];
foreach ($consultas->registradoConiecp(Pagamento15Regras::ANO_MINIMO, $anoCorrente)['valores'] as $id => $anos) {
    if (!in_array((int) $id, $ids, true)) {
        continue;
    }
    foreach ($anos as $ano => $meses) {
        foreach ($meses as $mes => $valor) {
            $novo1["{$id}:{$ano}:{$mes}"] = $valor;
        }
    }
}
$inesperadas += p15Comparar('C tabela ① antiga × registrado novo (mensal, desde 2014)', $novo1, $antigo1, $explicacoes1);

// ---------------- D. Casos fixos da spec (seção 9) ----------------
if (2018 >= $anoIni) {
    p15Igual(5492.87, round($declaradoNovo['13:2018'] ?? 0.0, 2), 'Jardim Aliança 2 declarado em 2018');
    p15Igual(956.69, round($declaradoNovo['14:2018'] ?? 0.0, 2), 'Pirapora declarado em 2018');
}
$pirapora = $consultas->registradoConiecp(2018, 2020)['valores'][14] ?? [];
p15Igual(666.0, round(array_sum($pirapora[2018] ?? []), 2), 'Pirapora registrado 2018 (CNPJ provisório)');
p15Igual(2088.0, round(array_sum($pirapora[2019] ?? []), 2), 'Pirapora registrado 2019 (CNPJ provisório)');
p15Igual(4429.0, round(array_sum($pirapora[2020] ?? []), 2), 'Pirapora registrado 2020 (id 14 + CNPJ provisório)');
$naoIdentificado = 0.0;
foreach ($consultas->registradoConiecp(Pagamento15Regras::ANO_MINIMO, $anoCorrente)['naoIdentificado'] as $meses) {
    $naoIdentificado += array_sum($meses);
}
p15Igual(0.0, round($naoIdentificado, 2), 'nenhum depósito sem IECP identificada desde 2014');
p15Igual(false, in_array(15, $ids, true), 'IECP Testes fora do relatório');
echo "D casos fixos: OK\n\n";

if ($inesperadas > 0) {
    p15Falhar("{$inesperadas} diferença(s) sem explicação.");
}
echo "pagamento15_conferencia: OK\n";
```

- [ ] **Step 2: Rodar**

Run: `php -l tests/pagamento15/pagamento15_conferencia.php && php tests/pagamento15/pagamento15_conferencia.php`
Expected: A1, A2, A3 com `0 explicada(s), 0 inesperada(s)`; B1 com as chaves `13:2018`, `13:2019`, `14:2018`, `14:2019` (algoritmo antigo) e `10:2017`, `10:2018` (item datado fora do ano fiscal) explicadas; B2 com essas e as do grupo 34; C com as de Resende 2014 e Pirapora 2018–2020; `D casos fixos: OK`; `pagamento15_conferencia: OK`; tempo das consultas novas impresso.

Se aparecer `INESPERADA`: **não** ajustar o script para esconder a diferença. Investigar o lançamento (superpowers:systematic-debugging) e trazer ao usuário.

- [ ] **Step 3: Commit**

```bash
rtk git add tests/pagamento15/pagamento15_conferencia.php
rtk git commit -m "test(pagamento15): conferência somente-leitura da lógica nova na base real"
```

- [ ] **Step 4: PARAR — apresentar ao usuário**

Mostrar a saída completa da conferência (diferenças explicadas por mecanismo, tempo) e aguardar o OK antes da Task 7.

---

### Task 7: Tela nova em rota paralela — PARADA para avaliação visual

**Files:**
- Create: `coniecp/tesouraria/reuniao_dados/partials/pagamento15.php`
- Create: `coniecp/tesouraria/reuniao_dados/css/pagamento15.css`
- Create: `coniecp/tesouraria/reuniao_dados/js/pagamento15.js`
- Create: `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php`

**Interfaces:**
- Consumes: endpoints da Task 5 (formato do JSON: Task 3); `Pagamento15::iecps` e `Pagamento15Regras::ANO_MINIMO`; variáveis `$conexao` (valida_sessao_all), `$nome` (validar_usuario_*), `$idIecp` (validar_usuario_iecp); `Classes\Csrf::htmlField()` (gera `#csrf_token`).
- Produces: partial que espera `$pagamento15Modo` (`'coniecp'|'iecp'`) definido antes do `require`.

- [ ] **Step 1: Partial**

`coniecp/tesouraria/reuniao_dados/partials/pagamento15.php`:

```php
<?php

declare(strict_types=1);

/*
 * Marcação comum da conferência dos 15% (páginas CONIECP e IECP).
 * Espera: $pagamento15Modo ('coniecp'|'iecp'), $conexao, $nome e, no modo IECP, $idIecp.
 */

$pagamento15RaizProjeto = dirname(__DIR__, 4);
require_once $pagamento15RaizProjeto . '/classes/Csrf.php';
require_once $pagamento15RaizProjeto . '/classes/Pagamento15Regras.php';
require_once $pagamento15RaizProjeto . '/classes/Pagamento15.php';

$pagamento15Esc = static fn (mixed $valor): string => htmlspecialchars((string) $valor, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
$pagamento15Versao = static function (string $arquivo): string {
    $caminho = dirname(__DIR__) . '/' . $arquivo;

    return is_file($caminho) ? '?v=' . filemtime($caminho) : '';
};
$pagamento15AnoCorrente = (int) date('Y');
$pagamento15Iecps = (new Pagamento15($conexao))->iecps($pagamento15Modo === 'iecp' ? (int) $idIecp : 0);
$pagamento15Base = 'coniecp/tesouraria/reuniao_dados/';
?>
<link rel="stylesheet" href="<?= $pagamento15Base; ?>css/pagamento15.css<?= $pagamento15Versao('css/pagamento15.css'); ?>">
<div class="container-fluid">
    <div class="row">
        <div class="col-1 col-md-1 p-0 menu_sistema">
            <?php require('menu.php'); ?>
        </div>
        <div class="col-11 col-sm-11 col-md-11">
            <main id="pagamento15" class="p15" aria-labelledby="p15-titulo"
                data-modo="<?= $pagamento15Esc($pagamento15Modo); ?>"
                data-ano-corrente="<?= $pagamento15AnoCorrente; ?>"
                data-usuario="<?= $pagamento15Esc($nome ?? ''); ?>">
                <?= \Classes\Csrf::htmlField(); ?>

                <header class="p15-cabecalho">
                    <p class="p15-sobretitulo">Tesouraria · Conferência cruzada</p>
                    <h1 id="p15-titulo">Pagamentos de 15%</h1>
                    <p class="p15-descricao">Compara, mês a mês, o que as IECPs declararam nos balancetes com o que a CONIECP registrou.</p>
                    <div class="p15-filtros p15-nao-imprimir" role="group" aria-label="Filtros da conferência">
                        <div class="p15-campo">
                            <label for="p15-iecp">IECP</label>
                            <select id="p15-iecp">
                                <?php if ($pagamento15Modo === 'coniecp') : ?>
                                    <option value="0">Todas as IECPs</option>
                                <?php endif; ?>
                                <?php foreach ($pagamento15Iecps as $pagamento15Opcao) : ?>
                                    <option value="<?= (int) $pagamento15Opcao['id']; ?>"><?= $pagamento15Esc($pagamento15Opcao['nome']); ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="p15-campo">
                            <label for="p15-ano">Ano</label>
                            <select id="p15-ano">
                                <?php for ($pagamento15AnoOpcao = $pagamento15AnoCorrente; $pagamento15AnoOpcao >= Pagamento15Regras::ANO_MINIMO; $pagamento15AnoOpcao--) : ?>
                                    <option value="<?= $pagamento15AnoOpcao; ?>"><?= $pagamento15AnoOpcao; ?></option>
                                <?php endfor; ?>
                            </select>
                        </div>
                        <button type="button" id="p15-limpar" class="p15-botao p15-botao--secundario">Limpar</button>
                    </div>
                    <p id="p15-status" class="p15-status" role="status" aria-live="polite">Carregando a conferência…</p>
                </header>

                <ul id="p15-avisos" class="p15-avisos"></ul>

                <section class="p15-resumo" aria-labelledby="p15-resumo-titulo">
                    <h2 id="p15-resumo-titulo" class="p15-sr">Resumo do ano</h2>
                    <dl id="p15-resumo" class="p15-cartoes">
                        <div class="p15-cartao"><dt>Registrado CONIECP</dt><dd data-resumo="registrado">—</dd></div>
                        <div class="p15-cartao"><dt>Declarado IECPs</dt><dd data-resumo="declarado">—</dd></div>
                        <div class="p15-cartao"><dt>Diferença (CONIECP − IECP)</dt><dd data-resumo="diferenca">—</dd></div>
                        <div class="p15-cartao"><dt>Devido (15% da arrecadação)</dt><dd data-resumo="devido">—</dd></div>
                        <div class="p15-cartao"><dt>Diferença (CONIECP − devido)</dt><dd data-resumo="diferencaDevido">—</dd></div>
                        <div class="p15-cartao"><dt>IECPs com divergência</dt><dd data-resumo="iecpsComDivergencia">—</dd></div>
                        <div class="p15-cartao p15-cartao--alerta" data-cartao="naoIdentificado" hidden>
                            <dt>Registrado sem IECP identificada</dt><dd data-resumo="naoIdentificado">—</dd>
                        </div>
                    </dl>
                </section>

                <div class="p15-abas p15-nao-imprimir" role="tablist" aria-label="Período da conferência">
                    <button type="button" role="tab" id="p15-aba-ano" aria-controls="p15-painel" aria-selected="true">Ano</button>
                    <button type="button" role="tab" id="p15-aba-historico" aria-controls="p15-painel" aria-selected="false" tabindex="-1">Histórico</button>
                </div>

                <section id="p15-painel" class="p15-painel" role="tabpanel" aria-labelledby="p15-aba-ano">
                    <div class="p15-ferramentas p15-nao-imprimir">
                        <fieldset class="p15-visoes-grupo">
                            <legend>Visão</legend>
                            <div id="p15-visoes" class="p15-visoes"></div>
                        </fieldset>
                        <div class="p15-campo p15-campo--busca">
                            <label for="p15-busca">Buscar IECP</label>
                            <input type="search" id="p15-busca" autocomplete="off">
                        </div>
                        <label class="p15-checagem" for="p15-divergencias">
                            <input type="checkbox" id="p15-divergencias"> Só divergências
                        </label>
                        <div class="p15-campo">
                            <label for="p15-ordem">Ordenar por</label>
                            <select id="p15-ordem">
                                <option value="diferenca">Maior diferença</option>
                                <option value="nome">Nome da IECP</option>
                            </select>
                        </div>
                        <div class="p15-acoes">
                            <button type="button" id="p15-csv" class="p15-botao p15-botao--secundario">Exportar CSV</button>
                            <button type="button" id="p15-imprimir" class="p15-botao p15-botao--secundario">Imprimir</button>
                        </div>
                    </div>

                    <div class="p15-legenda">
                        <p>
                            Diferença = registrado pela CONIECP − declarado pela IECP.
                            <strong>Negativo:</strong> declarado pela IECP e não registrado na CONIECP.
                            <strong>Positivo:</strong> registrado na CONIECP sem declaração correspondente da IECP.
                            O depósito do mês M da IECP é registrado no mês M+1 da CONIECP.
                        </p>
                        <ul class="p15-legenda-marcas">
                            <li><span class="p15-marca p15-marca--provisorio" aria-hidden="true">◐</span> provisório (balancete não finalizado)</li>
                            <li><span class="p15-marca p15-marca--aguardando_coniecp" aria-hidden="true">○</span> aguardando lançamento da CONIECP</li>
                            <li><span class="p15-marca p15-marca--aguardando_iecp" aria-hidden="true">◌</span> aguardando balancete da IECP</li>
                            <li>sem marca: definitivo (balancetes finalizados)</li>
                        </ul>
                    </div>

                    <div id="p15-tabela" class="p15-tabela-contencao" aria-busy="true"></div>
                    <div id="p15-impressao" class="p15-impressao"></div>

                    <section id="p15-historico-extra" class="p15-historico-extra" aria-labelledby="p15-indicadores-titulo" hidden>
                        <h2 id="p15-indicadores-titulo">Indicadores do histórico</h2>
                        <dl id="p15-indicadores" class="p15-cartoes">
                            <div class="p15-cartao"><dt>Registrado CONIECP</dt><dd data-indicador="registrado">—</dd></div>
                            <div class="p15-cartao"><dt>Declarado IECPs</dt><dd data-indicador="declarado">—</dd></div>
                            <div class="p15-cartao"><dt>Diferença acumulada</dt><dd data-indicador="diferencaAcumulada">—</dd></div>
                            <div class="p15-cartao"><dt>Anos com divergência</dt><dd data-indicador="periodosDivergentes">—</dd></div>
                            <div class="p15-cartao"><dt>Maior diferença</dt><dd data-indicador="maiorDiferenca">—</dd></div>
                        </dl>

                        <div class="p15-graficos-cabecalho p15-nao-imprimir">
                            <h2>Gráficos</h2>
                            <button type="button" id="p15-alternar-graficos" class="p15-botao p15-botao--secundario" aria-expanded="false" aria-controls="p15-graficos">Mostrar gráficos</button>
                        </div>
                        <div id="p15-graficos" class="p15-graficos" hidden>
                            <div id="p15-grafico-comparativo" class="p15-grafico" role="img" aria-label="Gráfico por ano do registrado pela CONIECP e do declarado pela IECP"></div>
                            <div id="p15-grafico-divergencia" class="p15-grafico" role="img" aria-label="Gráfico por ano da diferença entre o registrado pela CONIECP e o declarado pela IECP"></div>
                            <p id="p15-grafico-status" class="p15-status" hidden></p>
                        </div>

                        <h2>Notas por ano</h2>
                        <ul id="p15-notas" class="p15-notas"></ul>
                    </section>
                </section>

                <dialog id="p15-detalhe" class="p15-detalhe" aria-labelledby="p15-detalhe-titulo">
                    <div class="p15-detalhe-cabecalho">
                        <h2 id="p15-detalhe-titulo">Lançamentos</h2>
                        <button type="button" id="p15-detalhe-fechar" class="p15-botao p15-botao--icone" aria-label="Fechar">×</button>
                    </div>
                    <div id="p15-detalhe-corpo" class="p15-detalhe-corpo"></div>
                </dialog>
            </main>
        </div>
    </div>
</div>
<script src="node_modules/echarts/dist/echarts.min.js"></script>
<script src="<?= $pagamento15Base; ?>js/pagamento15.js<?= $pagamento15Versao('js/pagamento15.js'); ?>"></script>
```

- [ ] **Step 2: CSS**

`coniecp/tesouraria/reuniao_dados/css/pagamento15.css`:

```css
/* Conferência dos pagamentos de 15% — páginas CONIECP e IECP. */
.p15 {
    --p15-tinta: #12233f;
    --p15-suave: #475569;
    --p15-borda: #d9e1ec;
    --p15-superficie: #ffffff;
    --p15-fundo: #f5f8fc;
    --p15-primaria: #123b67;
    --p15-primaria-suave: #eaf2fb;
    --p15-positivo: #1d4ed8;
    --p15-negativo: #b42318;
    --p15-alerta: #8a5b00;
    --p15-alerta-suave: #fff7e6;
    --p15-foco: #1d4ed8;
    background: var(--p15-fundo);
    color: var(--p15-tinta);
    display: flex;
    flex-direction: column;
    gap: 20px;
    max-width: 100%;
    padding: clamp(16px, 3vw, 32px) clamp(12px, 2vw, 28px) 48px;
}

.p15 *,
.p15 *::before,
.p15 *::after {
    box-sizing: border-box;
}

.p15 :focus-visible {
    outline: 3px solid var(--p15-foco);
    outline-offset: 2px;
}

.p15-sr {
    border: 0;
    clip: rect(0 0 0 0);
    height: 1px;
    margin: -1px;
    overflow: hidden;
    padding: 0;
    position: absolute;
    white-space: nowrap;
    width: 1px;
}

.p15-cabecalho,
.p15-painel,
.p15-resumo {
    background: var(--p15-superficie);
    border: 1px solid var(--p15-borda);
    border-radius: 14px;
    padding: clamp(16px, 2.5vw, 28px);
}

.p15-sobretitulo {
    color: var(--p15-primaria);
    font-size: 0.78rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    margin: 0 0 6px;
    text-transform: uppercase;
}

.p15-cabecalho h1 {
    font-size: clamp(1.5rem, 2.6vw, 2.1rem);
    font-weight: 750;
    line-height: 1.15;
    margin: 0;
}

.p15-descricao {
    color: var(--p15-suave);
    line-height: 1.55;
    margin: 8px 0 18px;
    max-width: 70ch;
}

.p15-filtros,
.p15-ferramentas {
    align-items: end;
    display: flex;
    flex-wrap: wrap;
    gap: 12px 16px;
}

.p15-campo {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 160px;
}

.p15-campo--busca {
    flex: 1 1 200px;
}

.p15-campo label,
.p15-visoes-grupo legend {
    font-size: 0.9rem;
    font-weight: 700;
}

.p15-campo select,
.p15-campo input {
    background: var(--p15-superficie);
    border: 1px solid #94a3b8;
    border-radius: 8px;
    color: var(--p15-tinta);
    font-size: 1rem;
    min-height: 44px;
    padding: 8px 12px;
}

.p15-botao {
    border: 1px solid var(--p15-primaria);
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.95rem;
    font-weight: 650;
    min-height: 44px;
    padding: 8px 16px;
    transition: background-color 150ms ease, color 150ms ease;
}

.p15-botao--secundario {
    background: var(--p15-superficie);
    color: var(--p15-primaria);
}

.p15-botao--secundario:hover {
    background: var(--p15-primaria-suave);
}

.p15-botao--icone {
    background: transparent;
    border-color: transparent;
    color: var(--p15-tinta);
    font-size: 1.5rem;
    line-height: 1;
    min-width: 44px;
    padding: 0;
}

.p15-acoes {
    display: flex;
    gap: 8px;
    margin-left: auto;
}

.p15-checagem {
    align-items: center;
    cursor: pointer;
    display: inline-flex;
    font-weight: 650;
    gap: 8px;
    min-height: 44px;
}

.p15-checagem input {
    height: 20px;
    width: 20px;
}

.p15-status {
    color: var(--p15-suave);
    font-size: 0.92rem;
    margin: 14px 0 0;
}

.p15-status--erro {
    color: var(--p15-negativo);
    font-weight: 700;
}

.p15-avisos {
    display: flex;
    flex-direction: column;
    gap: 8px;
    list-style: none;
    margin: 0;
    padding: 0;
}

.p15-avisos:empty {
    display: none;
}

.p15-avisos li {
    background: var(--p15-alerta-suave);
    border: 1px solid #f3d38a;
    border-radius: 10px;
    color: var(--p15-alerta);
    font-weight: 650;
    padding: 10px 14px;
}

.p15-cartoes {
    display: grid;
    gap: 12px;
    grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
    margin: 0;
}

.p15-cartao {
    background: var(--p15-fundo);
    border: 1px solid var(--p15-borda);
    border-radius: 10px;
    padding: 12px 14px;
}

.p15-cartao dt {
    color: var(--p15-suave);
    font-size: 0.85rem;
    font-weight: 650;
}

.p15-cartao dd {
    font-size: 1.2rem;
    font-variant-numeric: tabular-nums;
    font-weight: 750;
    margin: 4px 0 0;
}

.p15-cartao--alerta {
    background: var(--p15-alerta-suave);
    border-color: #f3d38a;
}

.p15-abas {
    display: flex;
    gap: 4px;
}

.p15-abas [role="tab"] {
    background: transparent;
    border: 1px solid var(--p15-borda);
    border-bottom: 0;
    border-radius: 10px 10px 0 0;
    color: var(--p15-suave);
    cursor: pointer;
    font-weight: 700;
    min-height: 44px;
    padding: 8px 18px;
}

.p15-abas [role="tab"][aria-selected="true"] {
    background: var(--p15-superficie);
    color: var(--p15-primaria);
}

.p15-painel {
    border-top-left-radius: 0;
    display: flex;
    flex-direction: column;
    gap: 16px;
}

.p15-visoes-grupo {
    border: 0;
    margin: 0;
    padding: 0;
}

.p15-visoes {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-top: 6px;
}

.p15-visao {
    align-items: center;
    border: 1px solid var(--p15-borda);
    border-radius: 999px;
    cursor: pointer;
    display: inline-flex;
    gap: 6px;
    min-height: 44px;
    padding: 6px 14px;
}

.p15-visao:has(input:checked) {
    background: var(--p15-primaria-suave);
    border-color: var(--p15-primaria);
    color: var(--p15-primaria);
    font-weight: 700;
}

.p15-legenda {
    color: var(--p15-suave);
    font-size: 0.9rem;
    line-height: 1.5;
}

.p15-legenda p {
    margin: 0 0 6px;
}

.p15-legenda-marcas {
    display: flex;
    flex-wrap: wrap;
    gap: 6px 18px;
    list-style: none;
    margin: 0;
    padding: 0;
}

.p15-tabela-contencao {
    border: 1px solid var(--p15-borda);
    border-radius: 10px;
    max-height: 70vh;
    max-width: 100%;
    overflow: auto;
}

.p15-tabela {
    border-collapse: separate;
    border-spacing: 0;
    font-size: 0.9rem;
    min-width: 100%;
}

.p15-tabela caption {
    caption-side: top;
    font-weight: 700;
    padding: 10px 12px;
    text-align: left;
}

.p15-tabela th,
.p15-tabela td {
    border-bottom: 1px solid var(--p15-borda);
    padding: 0;
    white-space: nowrap;
}

.p15-tabela thead th {
    background: var(--p15-primaria-suave);
    padding: 8px 10px;
    position: sticky;
    text-align: right;
    top: 0;
    z-index: 2;
}

.p15-tabela thead th:first-child,
.p15-tabela tbody th,
.p15-tabela tfoot th {
    background: var(--p15-superficie);
    left: 0;
    padding: 8px 12px;
    position: sticky;
    text-align: left;
    white-space: normal;
    z-index: 1;
}

.p15-tabela thead th:first-child {
    background: var(--p15-primaria-suave);
    z-index: 3;
}

.p15-tabela tfoot th,
.p15-tabela tfoot td {
    background: var(--p15-fundo);
    font-weight: 750;
}

.p15-ref {
    color: var(--p15-suave);
    display: block;
    font-size: 0.75rem;
    font-weight: 500;
}

.p15-tabela td {
    font-variant-numeric: tabular-nums;
    text-align: right;
}

.p15-tabela td > .p15-numero,
.p15-tabela td > .p15-marca {
    display: inline-block;
    padding: 8px 0;
}

.p15-tabela td > .p15-numero {
    padding-left: 10px;
}

.p15-tabela td > .p15-marca:last-child,
.p15-tabela td > .p15-numero:last-child {
    padding-right: 10px;
}

.p15-celula {
    align-items: center;
    background: transparent;
    border: 0;
    color: inherit;
    cursor: pointer;
    display: flex;
    font: inherit;
    gap: 4px;
    justify-content: flex-end;
    min-height: 44px;
    padding: 6px 10px;
    width: 100%;
}

.p15-celula:hover {
    background: var(--p15-primaria-suave);
}

.p15-negativo {
    color: var(--p15-negativo);
    font-weight: 700;
}

.p15-positivo {
    color: var(--p15-positivo);
    font-weight: 700;
}

.p15-futuro {
    color: var(--p15-suave);
}

.p15-marca {
    color: var(--p15-alerta);
    font-size: 0.85rem;
}

.p15-vazio {
    color: var(--p15-suave);
    padding: 16px;
    text-align: center;
}

.p15-impressao {
    display: none;
}

.p15-graficos-cabecalho {
    align-items: center;
    display: flex;
    justify-content: space-between;
}

.p15-historico-extra h2 {
    font-size: 1.1rem;
    margin: 18px 0 10px;
}

.p15-graficos {
    display: grid;
    gap: 16px;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
}

.p15-grafico {
    border: 1px solid var(--p15-borda);
    border-radius: 10px;
    height: 320px;
}

.p15-notas {
    display: flex;
    flex-direction: column;
    gap: 8px;
    list-style: none;
    margin: 0;
    padding: 0;
}

.p15-nota {
    border-left: 4px solid var(--p15-borda);
    border-radius: 6px;
    display: grid;
    gap: 2px 12px;
    grid-template-columns: 64px 1fr;
    padding: 8px 12px;
}

.p15-nota--critical {
    background: #fff1f0;
    border-left-color: var(--p15-negativo);
}

.p15-nota--warning {
    background: var(--p15-alerta-suave);
    border-left-color: var(--p15-alerta);
}

.p15-nota--ok {
    background: #ecfdf3;
    border-left-color: #087443;
}

.p15-nota strong {
    display: block;
}

.p15-detalhe {
    border: 1px solid var(--p15-borda);
    border-radius: 14px;
    max-height: 90vh;
    max-width: min(1100px, 96vw);
    padding: 0;
    width: 100%;
}

.p15-detalhe::backdrop {
    background: rgba(18, 35, 63, 0.45);
}

.p15-detalhe-cabecalho {
    align-items: center;
    background: var(--p15-superficie);
    border-bottom: 1px solid var(--p15-borda);
    display: flex;
    justify-content: space-between;
    padding: 12px 16px;
    position: sticky;
    top: 0;
}

.p15-detalhe-cabecalho h2 {
    font-size: 1.15rem;
    margin: 0;
}

.p15-detalhe-corpo {
    display: grid;
    gap: 16px;
    grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
    padding: 16px;
}

.p15-detalhe-lado h3 {
    font-size: 1rem;
    margin: 0 0 8px;
}

.p15-detalhe-lado h4 {
    color: var(--p15-suave);
    font-size: 0.9rem;
    margin: 12px 0 6px;
}

.p15-detalhe-lado table {
    border-collapse: collapse;
    font-size: 0.85rem;
    width: 100%;
}

.p15-detalhe-lado th,
.p15-detalhe-lado td {
    border-bottom: 1px solid var(--p15-borda);
    padding: 6px;
    text-align: left;
    vertical-align: top;
}

.p15-detalhe-rodape {
    border-top: 1px solid var(--p15-borda);
    grid-column: 1 / -1;
    padding-top: 12px;
}

.p15-detalhe-totais {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 24px;
    margin: 0 0 8px;
}

.p15-detalhe-totais dd {
    font-variant-numeric: tabular-nums;
    font-weight: 750;
    margin: 0;
}

.p15-leitura {
    font-weight: 650;
    margin: 0;
}

.p15-erro {
    color: var(--p15-negativo);
    font-weight: 700;
}

@media (max-width: 768px) {
    .p15-acoes {
        margin-left: 0;
    }

    .p15-campo {
        flex: 1 1 100%;
    }

    .p15-tabela {
        font-size: 0.82rem;
    }
}

@media (prefers-reduced-motion: reduce) {
    .p15-botao {
        transition: none;
    }
}

@media print {
    body * {
        visibility: hidden;
    }

    #pagamento15,
    #pagamento15 * {
        visibility: visible;
    }

    #pagamento15 {
        left: 0;
        position: absolute;
        top: 0;
        width: 100%;
    }

    .p15-nao-imprimir,
    #p15-tabela,
    .p15-detalhe,
    .p15-graficos {
        display: none !important;
    }

    .p15-impressao {
        display: block !important;
    }

    .p15-impressao .p15-tabela {
        margin-bottom: 16px;
        page-break-inside: auto;
    }

    .p15-tabela thead th,
    .p15-tabela tbody th,
    .p15-tabela tfoot th {
        position: static;
    }
}
```

- [ ] **Step 3: JS**

`coniecp/tesouraria/reuniao_dados/js/pagamento15.js`:

```js
/*
 * Conferência dos pagamentos de 15% — módulo comum das páginas CONIECP e IECP.
 * Spec: docs/superpowers/specs/2026-09-23-pagamento15-auditoria-design.md
 */
(function ($) {
  'use strict';

  var raiz = document.getElementById('pagamento15');
  if (!raiz) {
    return;
  }

  var API = 'coniecp/tesouraria/reuniao_dados/api/';
  var SITUACOES = {
    futuro: { marca: '', texto: 'mês futuro' },
    aguardando_coniecp: { marca: '○', texto: 'aguardando lançamento da CONIECP' },
    aguardando_iecp: { marca: '◌', texto: 'aguardando balancete da IECP' },
    provisorio: { marca: '◐', texto: 'provisório' },
    definitivo: { marca: '', texto: 'definitivo' }
  };
  var VISOES = {
    ano: [
      { id: 'comparacao', rotulo: 'Comparação', campo: 'diferenca', divergencia: 'diferenca', situacao: 'situacao', detalhe: true, referencia: true },
      { id: 'coniecp', rotulo: 'Registrado CONIECP', campo: 'registrado', divergencia: 'diferenca', situacao: 'situacaoConiecp', detalhe: true, referencia: false },
      { id: 'iecp', rotulo: 'Declarado IECP', campo: 'declarado', divergencia: 'diferenca', situacao: 'situacaoIecp', detalhe: true, referencia: true },
      { id: 'devido', rotulo: '15% da arrecadação', campo: 'devido', divergencia: 'diferencaDevido', situacao: 'situacaoIecp', detalhe: false, referencia: true }
    ],
    historico: [
      { id: 'declarado', rotulo: 'Registrado × declarado', campo: 'diferenca', divergencia: 'diferenca', situacao: 'situacao', abreAno: true, referencia: true },
      { id: 'devido', rotulo: 'Registrado × devido', campo: 'diferencaDevido', divergencia: 'diferencaDevido', situacao: 'situacao', abreAno: true, referencia: true }
    ]
  };
  var ROTULOS_IDENTIFICACAO = {
    idIecp: 'vínculo da IECP',
    cnpj_historico: 'CNPJ (histórico)',
    cnpj_atual: 'CNPJ da descrição'
  };
  var moeda = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

  var el = {
    iecp: document.getElementById('p15-iecp'),
    ano: document.getElementById('p15-ano'),
    limpar: document.getElementById('p15-limpar'),
    status: document.getElementById('p15-status'),
    avisos: document.getElementById('p15-avisos'),
    resumo: document.getElementById('p15-resumo'),
    abaAno: document.getElementById('p15-aba-ano'),
    abaHistorico: document.getElementById('p15-aba-historico'),
    painel: document.getElementById('p15-painel'),
    visoes: document.getElementById('p15-visoes'),
    busca: document.getElementById('p15-busca'),
    divergencias: document.getElementById('p15-divergencias'),
    ordem: document.getElementById('p15-ordem'),
    csv: document.getElementById('p15-csv'),
    imprimir: document.getElementById('p15-imprimir'),
    tabela: document.getElementById('p15-tabela'),
    impressao: document.getElementById('p15-impressao'),
    extra: document.getElementById('p15-historico-extra'),
    indicadores: document.getElementById('p15-indicadores'),
    graficos: document.getElementById('p15-graficos'),
    alternarGraficos: document.getElementById('p15-alternar-graficos'),
    graficoStatus: document.getElementById('p15-grafico-status'),
    notas: document.getElementById('p15-notas'),
    dialogo: document.getElementById('p15-detalhe'),
    dialogoTitulo: document.getElementById('p15-detalhe-titulo'),
    dialogoCorpo: document.getElementById('p15-detalhe-corpo'),
    dialogoFechar: document.getElementById('p15-detalhe-fechar'),
    token: document.getElementById('csrf_token')
  };

  var estado = {
    aba: 'ano',
    visao: { ano: 'comparacao', historico: 'declarado' },
    mensal: null,
    historico: null,
    sequencia: 0,
    origemFoco: null
  };
  var cacheHistorico = {};
  var graficos = {};

  // ---------- utilitários ----------
  function criar(tag, classe, texto) {
    var elemento = document.createElement(tag);
    if (classe) {
      elemento.className = classe;
    }
    if (texto !== undefined && texto !== null) {
      elemento.textContent = texto;
    }
    return elemento;
  }

  function arred(valor) {
    return Math.round(valor * 100) / 100;
  }

  function divergente(valor) {
    return Math.abs(valor) >= 0.005;
  }

  function ehDiferenca(campo) {
    return campo === 'diferenca' || campo === 'diferencaDevido';
  }

  function valorDe(celula, campo) {
    if (campo === 'diferenca') {
      return arred(celula.registrado - celula.declarado);
    }
    if (campo === 'diferencaDevido') {
      return arred(celula.registrado - celula.devido);
    }
    return celula[campo];
  }

  function formatarValor(valor) {
    return Math.abs(valor) < 0.005 ? '—' : moeda.format(valor);
  }

  function formatarDiferenca(valor) {
    if (Math.abs(valor) < 0.005) {
      return '—';
    }
    return (valor > 0 ? '+' : '−') + moeda.format(Math.abs(valor));
  }

  function formatarData(iso) {
    var partes = String(iso || '').split('-');
    return partes.length === 3 ? partes[2] + '/' + partes[1] + '/' + partes[0] : String(iso || '');
  }

  function normalizar(texto) {
    return String(texto || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  }

  function textoSelecionado(select) {
    return select.options[select.selectedIndex] ? select.options[select.selectedIndex].text : '';
  }

  function anunciar(mensagem, erro) {
    el.status.textContent = mensagem;
    el.status.classList.toggle('p15-status--erro', !!erro);
  }

  function requisitar(arquivo, dados) {
    return $.ajax({
      method: 'POST',
      url: API + arquivo,
      dataType: 'json',
      data: $.extend({ csrf_token: el.token ? el.token.value : '' }, dados)
    }).then(function (resposta) {
      if (!resposta || resposta.ok !== true) {
        return $.Deferred().reject(resposta && resposta.mensagem).promise();
      }
      return resposta.dados;
    }, function (xhr) {
      var mensagem = xhr.responseJSON && xhr.responseJSON.mensagem
        ? xhr.responseJSON.mensagem
        : 'Não foi possível carregar a conferência. Tente novamente.';
      return $.Deferred().reject(mensagem).promise();
    });
  }

  // ---------- carga ----------
  function carregar() {
    var idIecp = el.iecp.value;
    var sequencia = ++estado.sequencia;
    var historico = cacheHistorico[idIecp]
      ? $.Deferred().resolve(cacheHistorico[idIecp]).promise()
      : requisitar('dadosHistorico.php', { idIecp: idIecp });

    anunciar('Carregando a conferência…');
    el.tabela.setAttribute('aria-busy', 'true');

    $.when(requisitar('dadosMensal.php', { idIecp: idIecp, ano: el.ano.value }), historico)
      .done(function (mensal, hist) {
        if (sequencia !== estado.sequencia) {
          return;
        }
        cacheHistorico[idIecp] = hist;
        estado.mensal = mensal;
        estado.historico = hist;
        renderizar();
        anunciar('Atualizado: ' + mensal.ano + ' · ' + mensal.linhas.length
          + (mensal.linhas.length === 1 ? ' IECP' : ' IECPs') + ' · '
          + mensal.resumo.iecpsComDivergencia + ' com divergência.');
      })
      .fail(function (mensagem) {
        if (sequencia !== estado.sequencia) {
          return;
        }
        estado.mensal = null;
        estado.historico = null;
        el.tabela.textContent = '';
        anunciar(mensagem || 'Não foi possível carregar a conferência. Tente novamente.', true);
      })
      .always(function () {
        if (sequencia === estado.sequencia) {
          el.tabela.setAttribute('aria-busy', 'false');
        }
      });
  }

  // ---------- renderização ----------
  function dadosAtuais() {
    return estado.aba === 'ano' ? estado.mensal : estado.historico;
  }

  function visaoAtual() {
    var id = estado.visao[estado.aba];
    return VISOES[estado.aba].filter(function (visao) { return visao.id === id; })[0];
  }

  function renderizar() {
    if (!estado.mensal || !estado.historico) {
      return;
    }
    renderizarAbas();
    renderizarAvisos();
    renderizarResumo();
    renderizarVisoes();
    renderizarTabela();
    el.extra.hidden = estado.aba !== 'historico';
    if (estado.aba === 'historico') {
      renderizarIndicadores();
      renderizarNotas();
      renderizarGraficos();
    }
  }

  function renderizarAbas() {
    el.abaAno.textContent = 'Ano ' + estado.mensal.ano;
    el.abaHistorico.textContent = 'Histórico ' + estado.historico.anoIni + '–' + estado.historico.anoFim;
    [[el.abaAno, 'ano'], [el.abaHistorico, 'historico']].forEach(function (par) {
      var ativa = estado.aba === par[1];
      par[0].setAttribute('aria-selected', ativa ? 'true' : 'false');
      par[0].tabIndex = ativa ? 0 : -1;
    });
    el.painel.setAttribute('aria-labelledby', estado.aba === 'ano' ? 'p15-aba-ano' : 'p15-aba-historico');
  }

  function renderizarAvisos() {
    el.avisos.textContent = '';
    estado.mensal.avisos.forEach(function (aviso) {
      el.avisos.appendChild(criar('li', null, aviso));
    });
  }

  function renderizarResumo() {
    var resumo = estado.mensal.resumo;
    var formatos = {
      registrado: formatarValor(resumo.registrado),
      declarado: formatarValor(resumo.declarado),
      diferenca: formatarDiferenca(resumo.diferenca),
      devido: formatarValor(resumo.devido),
      diferencaDevido: formatarDiferenca(resumo.diferencaDevido),
      iecpsComDivergencia: String(resumo.iecpsComDivergencia),
      naoIdentificado: formatarValor(resumo.naoIdentificado)
    };
    Object.keys(formatos).forEach(function (chave) {
      var alvo = el.resumo.querySelector('[data-resumo="' + chave + '"]');
      if (alvo) {
        alvo.textContent = formatos[chave];
      }
    });
    el.resumo.querySelector('[data-cartao="naoIdentificado"]').hidden = !divergente(resumo.naoIdentificado);
  }

  function renderizarVisoes() {
    el.visoes.textContent = '';
    VISOES[estado.aba].forEach(function (visao) {
      var id = 'p15-visao-' + estado.aba + '-' + visao.id;
      var rotulo = criar('label', 'p15-visao');
      var entrada = document.createElement('input');
      rotulo.htmlFor = id;
      entrada.type = 'radio';
      entrada.name = 'p15-visao';
      entrada.id = id;
      entrada.value = visao.id;
      entrada.checked = estado.visao[estado.aba] === visao.id;
      entrada.addEventListener('change', function () {
        estado.visao[estado.aba] = visao.id;
        renderizarTabela();
      });
      rotulo.appendChild(entrada);
      rotulo.appendChild(document.createTextNode(visao.rotulo));
      el.visoes.appendChild(rotulo);
    });
  }

  function linhasFiltradas(dados, visao) {
    var termo = normalizar(el.busca.value.trim());
    var linhas = dados.linhas.filter(function (linha) {
      if (termo && normalizar(linha.nome).indexOf(termo) === -1) {
        return false;
      }
      if (!el.divergencias.checked) {
        return true;
      }
      return dados.periodos.some(function (periodo) {
        var celula = linha.celulas[periodo.chave];
        return celula.situacao !== 'futuro' && divergente(valorDe(celula, visao.divergencia));
      });
    });

    linhas.sort(el.ordem.value === 'nome'
      ? function (a, b) { return a.nome.localeCompare(b.nome, 'pt-BR'); }
      : function (a, b) {
        return Math.abs(valorDe(b.total, visao.divergencia)) - Math.abs(valorDe(a.total, visao.divergencia))
          || a.nome.localeCompare(b.nome, 'pt-BR');
      });

    return linhas;
  }

  function renderizarTabela() {
    var dados = dadosAtuais();
    var visao = visaoAtual();
    el.tabela.textContent = '';
    el.tabela.appendChild(montarTabela(dados, visao, linhasFiltradas(dados, visao)));
  }

  function celulaCabecalho(linha, texto, escopo) {
    var th = criar('th', null, texto);
    th.scope = escopo;
    linha.appendChild(th);
    return th;
  }

  function montarTabela(dados, visao, linhas) {
    var tabela = criar('table', 'p15-tabela');
    var periodoTexto = estado.aba === 'ano' ? 'ano ' + dados.ano : dados.anoIni + ' a ' + dados.anoFim;
    tabela.createCaption().textContent = visao.rotulo + ' — ' + periodoTexto + ' ('
      + linhas.length + (linhas.length === 1 ? ' IECP' : ' IECPs') + ')';

    var cabecalho = tabela.createTHead().insertRow();
    celulaCabecalho(cabecalho, 'IECP', 'col');
    dados.periodos.forEach(function (periodo) {
      var th = celulaCabecalho(cabecalho, periodo.rotulo, 'col');
      if (visao.referencia) {
        th.appendChild(criar('span', 'p15-ref', periodo.referencia));
      }
    });
    celulaCabecalho(cabecalho, 'Total', 'col');

    var corpo = tabela.createTBody();
    if (!linhas.length) {
      var vazia = corpo.insertRow().insertCell();
      vazia.colSpan = dados.periodos.length + 2;
      vazia.className = 'p15-vazio';
      vazia.textContent = 'Nenhuma IECP atende aos filtros.';
    }
    linhas.forEach(function (linha) {
      var tr = corpo.insertRow();
      celulaCabecalho(tr, linha.nome, 'row');
      dados.periodos.forEach(function (periodo) {
        tr.appendChild(celulaValor(linha.celulas[periodo.chave], visao, { idIecp: linha.id, nome: linha.nome, periodo: periodo }));
      });
      tr.appendChild(celulaValor(linha.total, visao, null));
    });

    var rodape = tabela.createTFoot();
    if (visao.campo !== 'declarado' && visao.campo !== 'devido' && divergente(dados.naoIdentificado.total)) {
      var semIecp = rodape.insertRow();
      celulaCabecalho(semIecp, 'Registrado sem IECP identificada', 'row');
      dados.periodos.forEach(function (periodo) {
        semIecp.appendChild(criar('td', null, formatarValor(dados.naoIdentificado.celulas[periodo.chave])));
      });
      semIecp.appendChild(criar('td', null, formatarValor(dados.naoIdentificado.total)));
    }
    var total = rodape.insertRow();
    celulaCabecalho(total, 'Total', 'row');
    dados.periodos.forEach(function (periodo) {
      total.appendChild(celulaValor(dados.totais.celulas[periodo.chave], visao, null));
    });
    total.appendChild(celulaValor(dados.totais.total, visao, null));

    return tabela;
  }

  function celulaValor(celula, visao, contexto) {
    var td = document.createElement('td');
    var situacao = celula[visao.situacao];
    var info = SITUACOES[situacao];
    if (situacao === 'futuro') {
      td.className = 'p15-futuro';
      td.appendChild(criar('span', 'p15-numero', '—'));
      td.appendChild(criar('span', 'p15-sr', 'mês futuro'));
      return td;
    }

    var valor = valorDe(celula, visao.campo);
    var texto = ehDiferenca(visao.campo) ? formatarDiferenca(valor) : formatarValor(valor);
    var alvo = td;
    if (contexto && (visao.detalhe || visao.abreAno)) {
      alvo = criar('button', 'p15-celula');
      alvo.type = 'button';
      alvo.setAttribute('aria-label', contexto.nome + ', ' + contexto.periodo.rotulo + ': ' + texto + ', '
        + info.texto + (visao.detalhe ? '. Ver lançamentos.' : '. Abrir o ano.'));
      alvo.addEventListener('click', function () {
        if (visao.detalhe) {
          abrirDetalhe(contexto.idIecp, contexto.periodo);
        } else {
          abrirAno(contexto.periodo.chave);
        }
      });
      td.appendChild(alvo);
    }

    alvo.appendChild(criar('span', 'p15-numero', texto));
    if (info.marca) {
      var marca = criar('span', 'p15-marca p15-marca--' + situacao, info.marca);
      marca.setAttribute('aria-hidden', 'true');
      marca.title = info.texto;
      alvo.appendChild(marca);
      if (alvo === td) {
        td.appendChild(criar('span', 'p15-sr', info.texto));
      }
    }
    if (ehDiferenca(visao.campo) && divergente(valor)) {
      td.classList.add(valor < 0 ? 'p15-negativo' : 'p15-positivo');
    }

    return td;
  }

  function renderizarIndicadores() {
    var ind = estado.historico.indicadores;
    var valores = {
      registrado: formatarValor(ind.registrado),
      declarado: formatarValor(ind.declarado),
      diferencaAcumulada: formatarDiferenca(ind.diferencaAcumulada),
      periodosDivergentes: ind.periodosDivergentes === 0
        ? 'Nenhum'
        : ind.periodosDivergentes + (ind.periodosDivergentes === 1 ? ' ano' : ' anos'),
      maiorDiferenca: ind.maiorDiferenca
        ? ind.maiorDiferenca.rotulo + ': ' + formatarDiferenca(ind.maiorDiferenca.valor)
        : 'Sem divergência'
    };
    Object.keys(valores).forEach(function (chave) {
      el.indicadores.querySelector('[data-indicador="' + chave + '"]').textContent = valores[chave];
    });
  }

  function renderizarNotas() {
    el.notas.textContent = '';
    estado.historico.notas.forEach(function (nota) {
      var item = criar('li', 'p15-nota p15-nota--' + nota.tipo);
      item.appendChild(criar('strong', null, nota.periodo));
      var mensagem = criar('div');
      mensagem.appendChild(criar('strong', null, nota.titulo));
      mensagem.appendChild(criar('span', null, nota.texto));
      item.appendChild(mensagem);
      el.notas.appendChild(item);
    });
  }

  function criarGrafico(id) {
    var elemento = document.getElementById(id);
    var existente = window.echarts.getInstanceByDom(elemento);
    if (existente) {
      existente.dispose();
    }
    graficos[id] = window.echarts.init(elemento, null, { renderer: 'canvas' });
    return graficos[id];
  }

  function renderizarGraficos() {
    if (el.graficos.hidden) {
      return;
    }
    if (!window.echarts) {
      el.graficoStatus.hidden = false;
      el.graficoStatus.textContent = 'Os gráficos não puderam ser carregados neste navegador. As tabelas continuam disponíveis.';
      return;
    }
    el.graficoStatus.hidden = true;

    var dados = estado.historico;
    var rotulos = dados.periodos.map(function (p) { return p.rotulo; });
    var registrado = dados.periodos.map(function (p) { return dados.totais.celulas[p.chave].registrado; });
    var declarado = dados.periodos.map(function (p) { return dados.totais.celulas[p.chave].declarado; });
    var diferencas = dados.periodos.map(function (p) { return valorDe(dados.totais.celulas[p.chave], 'diferenca'); });
    var animar = !(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    var eixo = { axisLabel: { color: '#475569' }, axisLine: { lineStyle: { color: '#d9e1ec' } } };
    var grade = { top: 52, right: 20, bottom: 54, left: 20, containLabel: true };
    var eixoValor = {
      type: 'value',
      axisLabel: { color: '#475569', formatter: function (v) { return moeda.format(v); } },
      splitLine: { lineStyle: { color: '#e5edf1' } }
    };

    criarGrafico('p15-grafico-comparativo').setOption({
      aria: { enabled: true },
      animation: animar,
      color: ['#1d4ed8', '#c2410c'],
      tooltip: { trigger: 'axis', valueFormatter: function (v) { return moeda.format(v); } },
      legend: { bottom: 4, left: 'center' },
      grid: grade,
      xAxis: $.extend({ type: 'category', data: rotulos }, eixo),
      yAxis: eixoValor,
      series: [
        { name: 'Registrado CONIECP', type: 'line', smooth: true, symbolSize: 7, data: registrado },
        { name: 'Declarado IECP', type: 'line', smooth: true, symbolSize: 7, data: declarado }
      ]
    });

    criarGrafico('p15-grafico-divergencia').setOption({
      aria: { enabled: true },
      animation: animar,
      tooltip: { trigger: 'axis', valueFormatter: function (v) { return moeda.format(v); } },
      legend: { bottom: 4, left: 'center' },
      grid: grade,
      xAxis: $.extend({ type: 'category', data: rotulos, axisLabel: { color: '#475569', interval: 0 } }, eixo),
      yAxis: eixoValor,
      series: [
        {
          name: 'CONIECP acima do declarado',
          type: 'bar',
          barMaxWidth: 32,
          itemStyle: { color: '#1d4ed8' },
          data: diferencas.map(function (v) { return v > 0.005 ? v : 0; })
        },
        {
          name: 'Declarado acima da CONIECP',
          type: 'bar',
          barMaxWidth: 32,
          itemStyle: { color: '#b42318' },
          data: diferencas.map(function (v) { return v < -0.005 ? v : 0; })
        }
      ]
    });
  }

  // ---------- detalhamento ----------
  function tabelaSimples(cabecalhos, linhas) {
    var tabela = document.createElement('table');
    var cab = tabela.createTHead().insertRow();
    cabecalhos.forEach(function (texto) {
      var th = criar('th', null, texto);
      th.scope = 'col';
      cab.appendChild(th);
    });
    var corpo = tabela.createTBody();
    linhas.forEach(function (valores) {
      var tr = corpo.insertRow();
      valores.forEach(function (valor) {
        var td = tr.insertCell();
        if (valor instanceof Node) {
          td.appendChild(valor);
        } else {
          td.textContent = valor;
        }
      });
    });
    return tabela;
  }

  function linkComprovante(url) {
    if (!url) {
      return criar('span', null, 'sem comprovante');
    }
    var link = criar('a', null, 'Ver recibo');
    link.href = url;
    link.target = '_blank';
    link.rel = 'noopener';
    link.setAttribute('aria-label', 'Ver recibo (abre em nova aba)');
    return link;
  }

  function montarDetalhe(dados) {
    var fragmento = document.createDocumentFragment();

    var ladoConiecp = criar('section', 'p15-detalhe-lado');
    ladoConiecp.appendChild(criar('h3', null, 'Registrado na CONIECP'));
    ladoConiecp.appendChild(dados.coniecp.length
      ? tabelaSimples(['Data', 'Descrição', 'Valor', 'Balancete', 'Identificação'], dados.coniecp.map(function (item) {
        return [formatarData(item.data), item.descricao, formatarValor(item.valor), item.statusBalancete,
          ROTULOS_IDENTIFICACAO[item.identificadoPor] || item.identificadoPor];
      }))
      : criar('p', 'p15-vazio', 'Nenhum lançamento registrado neste mês.'));
    fragmento.appendChild(ladoConiecp);

    var ladoIecp = criar('section', 'p15-detalhe-lado');
    ladoIecp.appendChild(criar('h3', null, 'Declarado pela IECP'));
    if (!dados.iecp.length) {
      ladoIecp.appendChild(criar('p', 'p15-vazio', 'Nenhum lançamento declarado no mês de referência.'));
    }
    var grupos = [];
    dados.iecp.forEach(function (item) {
      var ultimo = grupos[grupos.length - 1];
      if (!ultimo || ultimo.origem !== item.origem) {
        ultimo = { origem: item.origem, itens: [] };
        grupos.push(ultimo);
      }
      ultimo.itens.push(item);
    });
    grupos.forEach(function (grupo) {
      ladoIecp.appendChild(criar('h4', null, grupo.origem));
      ladoIecp.appendChild(tabelaSimples(['Balancete', 'Data', 'Descrição', 'Valor', 'Status', 'Comprovante'], grupo.itens.map(function (item) {
        return [item.mesBalancete, formatarData(item.data), item.descricao, formatarValor(item.valor), item.statusBalancete, linkComprovante(item.comprovanteUrl)];
      })));
    });
    fragmento.appendChild(ladoIecp);

    var rodape = criar('footer', 'p15-detalhe-rodape');
    var totais = criar('dl', 'p15-detalhe-totais');
    [
      ['Registrado', formatarValor(dados.totais.registrado)],
      ['Declarado', formatarValor(dados.totais.declarado)],
      ['Diferença', formatarDiferenca(dados.totais.diferenca)]
    ].forEach(function (par) {
      var grupo = criar('div');
      grupo.appendChild(criar('dt', null, par[0]));
      grupo.appendChild(criar('dd', null, par[1]));
      totais.appendChild(grupo);
    });
    rodape.appendChild(totais);
    rodape.appendChild(criar('p', 'p15-leitura', dados.leitura));
    fragmento.appendChild(rodape);

    return fragmento;
  }

  function abrirDialogo() {
    if (typeof el.dialogo.showModal === 'function') {
      el.dialogo.showModal();
    } else {
      el.dialogo.setAttribute('open', '');
    }
  }

  function fecharDialogo() {
    if (typeof el.dialogo.close === 'function') {
      el.dialogo.close();
    } else {
      el.dialogo.removeAttribute('open');
      devolverFoco();
    }
  }

  function devolverFoco() {
    if (estado.origemFoco && document.contains(estado.origemFoco)) {
      estado.origemFoco.focus();
    }
    estado.origemFoco = null;
  }

  function abrirDetalhe(idIecp, periodo) {
    estado.origemFoco = document.activeElement;
    el.dialogoTitulo.textContent = 'Lançamentos — ' + periodo.rotulo;
    el.dialogoCorpo.textContent = '';
    el.dialogoCorpo.appendChild(criar('p', 'p15-status', 'Carregando lançamentos…'));
    abrirDialogo();
    el.dialogoFechar.focus();

    requisitar('dadosLancamentos.php', { idIecp: idIecp, ano: estado.mensal.ano, mes: periodo.chave })
      .done(function (dados) {
        el.dialogoTitulo.textContent = dados.titulo;
        el.dialogoCorpo.textContent = '';
        el.dialogoCorpo.appendChild(montarDetalhe(dados));
      })
      .fail(function (mensagem) {
        el.dialogoCorpo.textContent = '';
        el.dialogoCorpo.appendChild(criar('p', 'p15-erro', mensagem || 'Não foi possível carregar os lançamentos.'));
      });
  }

  function abrirAno(ano) {
    el.ano.value = ano;
    estado.aba = 'ano';
    carregar();
    el.abaAno.focus();
  }

  // ---------- CSV e impressão ----------
  function campoCsv(texto) {
    return '"' + String(texto).replace(/"/g, '""') + '"';
  }

  function numeroCsv(valor) {
    return Number(valor).toFixed(2).replace('.', ',');
  }

  function exportarCsv() {
    var dados = dadosAtuais();
    var visao = visaoAtual();
    if (!dados) {
      return;
    }
    var linhas = [[
      'IECP', 'Período', 'Referência IECP', 'Registrado CONIECP', 'Declarado IECP',
      'Devido (15% da arrecadação)', 'Diferença (registrado − declarado)', 'Diferença (registrado − devido)', 'Situação'
    ]];
    linhasFiltradas(dados, visao).forEach(function (linha) {
      dados.periodos.forEach(function (periodo) {
        var celula = linha.celulas[periodo.chave];
        linhas.push([
          linha.nome, periodo.rotulo, periodo.referencia.replace(/^ref\. /, ''),
          numeroCsv(celula.registrado), numeroCsv(celula.declarado), numeroCsv(celula.devido),
          numeroCsv(valorDe(celula, 'diferenca')), numeroCsv(valorDe(celula, 'diferencaDevido')),
          SITUACOES[celula.situacao].texto
        ]);
      });
    });
    if (divergente(dados.naoIdentificado.total)) {
      dados.periodos.forEach(function (periodo) {
        var valor = dados.naoIdentificado.celulas[periodo.chave];
        if (divergente(valor)) {
          linhas.push(['Registrado sem IECP identificada', periodo.rotulo, '', numeroCsv(valor), '', '', '', '', '']);
        }
      });
    }

    var conteudo = '﻿' + linhas.map(function (linha) { return linha.map(campoCsv).join(';'); }).join('\r\n');
    var link = document.createElement('a');
    link.href = URL.createObjectURL(new Blob([conteudo], { type: 'text/csv;charset=utf-8' }));
    link.download = ['pagamento15', estado.aba, visao.id,
      normalizar(textoSelecionado(el.iecp)).replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''),
      estado.aba === 'ano' ? dados.ano : dados.anoIni + '-' + dados.anoFim].join('_') + '.csv';
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(function () { URL.revokeObjectURL(link.href); }, 0);
  }

  function prepararImpressao() {
    var dados = dadosAtuais();
    el.impressao.textContent = '';
    if (!dados) {
      return;
    }
    el.impressao.appendChild(criar('p', null,
      'Filtros: IECP ' + textoSelecionado(el.iecp) + ' · '
      + (estado.aba === 'ano' ? 'Ano ' + dados.ano : 'Histórico ' + dados.anoIni + '–' + dados.anoFim)
      + ' · Gerado em ' + new Date().toLocaleString('pt-BR')
      + ' por ' + (raiz.getAttribute('data-usuario') || 'usuário do sistema') + '.'));
    VISOES[estado.aba].forEach(function (visao) {
      el.impressao.appendChild(montarTabela(dados, visao, linhasFiltradas(dados, visao)));
    });
  }

  // ---------- eventos ----------
  function trocarAba(aba) {
    if (estado.aba === aba) {
      return;
    }
    estado.aba = aba;
    renderizar();
  }

  el.iecp.addEventListener('change', carregar);
  el.ano.addEventListener('change', carregar);
  el.limpar.addEventListener('click', function () {
    el.iecp.selectedIndex = 0;
    el.ano.value = raiz.getAttribute('data-ano-corrente');
    el.busca.value = '';
    el.divergencias.checked = false;
    el.ordem.value = 'diferenca';
    estado.aba = 'ano';
    estado.visao = { ano: 'comparacao', historico: 'declarado' };
    carregar();
  });

  el.abaAno.addEventListener('click', function () { trocarAba('ano'); });
  el.abaHistorico.addEventListener('click', function () { trocarAba('historico'); });
  [el.abaAno, el.abaHistorico].forEach(function (aba) {
    aba.addEventListener('keydown', function (evento) {
      if (evento.key !== 'ArrowLeft' && evento.key !== 'ArrowRight') {
        return;
      }
      evento.preventDefault();
      var destino = aba === el.abaAno ? el.abaHistorico : el.abaAno;
      trocarAba(destino === el.abaAno ? 'ano' : 'historico');
      destino.focus();
    });
  });

  var temporizadorBusca = null;
  el.busca.addEventListener('input', function () {
    clearTimeout(temporizadorBusca);
    temporizadorBusca = setTimeout(function () {
      if (dadosAtuais()) {
        renderizarTabela();
      }
    }, 200);
  });
  [el.divergencias, el.ordem].forEach(function (controle) {
    controle.addEventListener('change', function () {
      if (dadosAtuais()) {
        renderizarTabela();
      }
    });
  });

  el.csv.addEventListener('click', exportarCsv);
  el.imprimir.addEventListener('click', function () {
    prepararImpressao();
    window.print();
  });
  window.addEventListener('beforeprint', prepararImpressao);
  window.addEventListener('afterprint', function () { el.impressao.textContent = ''; });

  el.alternarGraficos.addEventListener('click', function () {
    var mostrar = el.graficos.hidden;
    el.graficos.hidden = !mostrar;
    el.alternarGraficos.setAttribute('aria-expanded', mostrar ? 'true' : 'false');
    el.alternarGraficos.textContent = mostrar ? 'Ocultar gráficos' : 'Mostrar gráficos';
    renderizarGraficos();
  });
  window.addEventListener('resize', function () {
    Object.keys(graficos).forEach(function (id) {
      if (graficos[id]) {
        graficos[id].resize();
      }
    });
  });

  el.dialogoFechar.addEventListener('click', fecharDialogo);
  el.dialogo.addEventListener('close', devolverFoco);
  el.dialogo.addEventListener('click', function (evento) {
    if (evento.target === el.dialogo) {
      fecharDialogo();
    }
  });

  el.ano.value = raiz.getAttribute('data-ano-corrente');
  carregar();
})(jQuery);
```

- [ ] **Step 4: Rota paralela**

`coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php`:

```php
<?php

declare(strict_types=1);

/*
 * Rota TEMPORÁRIA da conferência dos 15% para validação visual (plano, Task 7).
 * Removida na Task 8, quando a rota oficial passa a usar o partial.
 */
require('valida_sessao_all.php');
require('validar_usuario_coniecp.php');
require('header.php');

$pagamento15Modo = 'coniecp';
require __DIR__ . '/partials/pagamento15.php';

include('footer.php');
```

- [ ] **Step 5: Sintaxe**

Run: `php -l coniecp/tesouraria/reuniao_dados/partials/pagamento15.php && php -l coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php && node --check coniecp/tesouraria/reuniao_dados/js/pagamento15.js`
Expected: dois `No syntax errors detected` e nenhuma saída do `node --check`.

- [ ] **Step 6: Verificação no navegador (Playwright)**

1. Navegar para `http://localhost/sisconiecp2/painel.php?pagina=coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova`. **Se cair no login, pedir ao usuário para logar** e aguardar.
2. Conferir, com o console do navegador aberto (sem erros JS):
   - status "Atualizado: …"; resumo preenchido; avisos da CONIECP quando houver;
   - quatro visões na aba Ano e duas na aba Histórico; setas ←/→ trocam de aba;
   - clicar numa célula da Comparação abre o diálogo com as duas colunas, Esc fecha e o foco volta à célula;
   - "Ver recibo" abre em nova aba numa IECP com comprovante (ex.: IECP 7, 2025);
   - no Histórico: indicadores, notas, "Mostrar gráficos" desenha os dois gráficos; clicar num ano leva à aba Ano;
   - Buscar, Só divergências e Ordenar filtram sem nova requisição;
   - CSV baixa e abre com acentos corretos; Imprimir (visualização) mostra filtros, data, usuário e as tabelas da aba.
3. Fumaça de acesso com sessão (console do navegador):
   ```js
   $.post('coniecp/tesouraria/reuniao_dados/api/dadosMensal.php', {csrf_token: 'x', idIecp: 0, ano: 2025}).fail(x => console.log(x.status));   // 403
   $.post('coniecp/tesouraria/reuniao_dados/api/dadosMensal.php', {csrf_token: $('#csrf_token').val(), idIecp: 0, ano: 1999}).fail(x => console.log(x.status));   // 422
   $.get('coniecp/tesouraria/reuniao_dados/api/dadosMensal.php').fail(x => console.log(x.status));   // 405
   ```
4. Capturas de tela em 375, 768 e 1440px de largura (aba Ano e Histórico com gráficos); conferir que não há rolagem horizontal da página, só da tabela.

- [ ] **Step 7: Commit**

```bash
rtk git add coniecp/tesouraria/reuniao_dados/partials/pagamento15.php coniecp/tesouraria/reuniao_dados/css/pagamento15.css coniecp/tesouraria/reuniao_dados/js/pagamento15.js coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php
rtk git commit -m "feat(pagamento15): tela nova da conferência em rota paralela"
```

- [ ] **Step 8: PARAR — avaliação visual do usuário**

Enviar as capturas e o link da rota paralela; pedir ao usuário que compare com a página atual (`...reuniao_dados/tabela_pagamento_15`). Ajustes pedidos entram como passos adicionais desta task (editar, `php -l`/`node --check`, reverificar no navegador, commit) antes da Task 8.

---

### Task 8: Troca da rota oficial e remoção do código antigo (após aprovação)

**Files:**
- Modify (substituir conteúdo): `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15.php`
- Modify (substituir conteúdo): `iecp/tesouraria/reuniao_dados/tabela_pagamento_15.php`
- Delete: `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php`
- Delete: `coniecp/tesouraria/reuniao_dados/tabelas_pagamentos/` (4 endpoints + `validarAcessoPagamento15.php`)
- Delete: `coniecp/tesouraria/reuniao_dados/js/tabela_pagamento_15.js`, `js/tabela_pagamento_15 copy.js`, `css/tabela_pagamento_15.css`, `css/tabela_pagamento_15.scss`
- Delete: JS/CSS antigos da página IECP (`iecp/tesouraria/reuniao_dados/js/tabela_pagamento_15.js`, `iecp/tesouraria/reuniao_dados/css/tabela_pagamento_15.css` e outros arquivos dessas pastas que só a página antiga usava — confirmar por grep)
- Delete: `coniecp/tesouraria/reuniao_dados/lista_pagamento_15-backup.php`; `lista_pagamento_15.php` (CONIECP e IECP) **somente** se o grep do Step 1 não achar uso
- Modify: `classes/Iecp.class.php` (remover os métodos sem uso)

**Interfaces:**
- Consumes: partial da Task 7.

- [ ] **Step 1: Confirmar o que não tem mais uso**

Run:
```bash
cd /c/wamp64/www/sisconiecp2
for termo in tabelas_pagamentos lista_pagamento_15 "js/tabela_pagamento_15" "css/tabela_pagamento_15" buscaTodosValores15RegNaConiecp buscaValores15PorAno buscaValores15PorAnoPorIecp buscaValores15BaseArrecadacao buscaValores15BaseArrecadacaoIecpEspecifica; do
  echo "== $termo"; grep -rln --include=*.php --include=*.js --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=mapa_uso_arquivos --exclude-dir=backup "$termo" . ;
done
ls iecp/tesouraria/reuniao_dados/js iecp/tesouraria/reuniao_dados/css
```
Expected: cada termo aparece só nos próprios arquivos a remover (e, para os métodos, só em `classes/Iecp.class.php` e nos endpoints antigos). Qualquer outro uso: **não remover aquele item** e relatar ao usuário.

- [ ] **Step 2: Página CONIECP oficial**

Substituir todo o conteúdo de `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15.php` por:

```php
<?php

declare(strict_types=1);

/*
 * Conferência dos pagamentos de 15% — página CONIECP.
 * Spec: docs/superpowers/specs/2026-09-23-pagamento15-auditoria-design.md
 */
require('valida_sessao_all.php');
require('validar_usuario_coniecp.php');
require('header.php');

$pagamento15Modo = 'coniecp';
require __DIR__ . '/partials/pagamento15.php';

include('footer.php');
```

- [ ] **Step 3: Página IECP oficial**

Substituir todo o conteúdo de `iecp/tesouraria/reuniao_dados/tabela_pagamento_15.php` por:

```php
<?php

declare(strict_types=1);

/*
 * Conferência dos pagamentos de 15% — página IECP (mesmo conteúdo da CONIECP, travado na própria IECP).
 * Spec: docs/superpowers/specs/2026-09-23-pagamento15-auditoria-design.md
 */
require('valida_sessao_all.php');
require('validar_usuario_iecp.php');
require('header.php');

$pagamento15Modo = 'iecp';
require dirname(__DIR__, 3) . '/coniecp/tesouraria/reuniao_dados/partials/pagamento15.php';

include('footer.php');
```

- [ ] **Step 4: Remover métodos antigos de `classes/Iecp.class.php`**

Apagar integralmente as funções confirmadas sem uso no Step 1 (`buscaTodosValores15RegNaConiecp`, `buscaValores15PorAno`, `buscaValores15BaseArrecadacao`, `buscaValores15BaseArrecadacaoIecpEspecifica` e, se também sem uso, `buscaValores15PorAnoPorIecp`), cada uma do `function nome(` até a `}` que a fecha, sem tocar nas vizinhas.

Run: `php -l classes/Iecp.class.php`
Expected: `No syntax errors detected`

- [ ] **Step 5: Remover arquivos antigos**

```bash
rtk git rm -r coniecp/tesouraria/reuniao_dados/tabelas_pagamentos
rtk git rm coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova.php "coniecp/tesouraria/reuniao_dados/js/tabela_pagamento_15.js" "coniecp/tesouraria/reuniao_dados/js/tabela_pagamento_15 copy.js" coniecp/tesouraria/reuniao_dados/css/tabela_pagamento_15.css coniecp/tesouraria/reuniao_dados/css/tabela_pagamento_15.scss coniecp/tesouraria/reuniao_dados/lista_pagamento_15-backup.php
rtk git rm iecp/tesouraria/reuniao_dados/js/tabela_pagamento_15.js iecp/tesouraria/reuniao_dados/css/tabela_pagamento_15.css
```
Mais os `lista_pagamento_15.php` e demais arquivos das pastas `iecp/tesouraria/reuniao_dados/{js,css}` **somente** se o Step 1 confirmou que não têm uso. Se algum arquivo não estiver rastreado pelo git, usar `rm` e registrar no relatório.

- [ ] **Step 6: Verificação final**

Run:
```bash
php -l coniecp/tesouraria/reuniao_dados/tabela_pagamento_15.php && php -l iecp/tesouraria/reuniao_dados/tabela_pagamento_15.php && php -l classes/Iecp.class.php
php tests/pagamento15/pagamento15_regras_test.php && php tests/pagamento15/pagamento15_relatorio_test.php && php tests/pagamento15/pagamento15_conferencia.php
```
e o teste de consultas com as variáveis da Task 0.
Expected: sintaxe ok e as quatro suítes `OK`.

No navegador: abrir as duas rotas oficiais pelo menu — CONIECP (`painel.php?pagina=coniecp/tesouraria/reuniao_dados/tabela_pagamento_15`) e IECP (`painel.php?pagina=iecp/tesouraria/reuniao_dados/tabela_pagamento_15`, com um usuário IECP; pedir ao usuário para logar com esse perfil). Na IECP: seletor travado na própria IECP; detalhamento só com lançamentos dela; números iguais aos da CONIECP filtrada na mesma IECP.

- [ ] **Step 7: Commit**

```bash
rtk git add coniecp/tesouraria/reuniao_dados/tabela_pagamento_15.php iecp/tesouraria/reuniao_dados/tabela_pagamento_15.php classes/Iecp.class.php
rtk git commit -m "feat(pagamento15): páginas CONIECP e IECP usam a conferência nova; remove código antigo"
```

- [ ] **Step 8: Relatório final ao usuário**

Informar: o que mudou, onde está, resultado da conferência e dos testes, itens que não foram removidos por ainda terem uso, e as pendências fora do escopo (tela de recibos da CONIECP; desativar `updateItensBalConiecp.php`; aplicar a migração em produção).
