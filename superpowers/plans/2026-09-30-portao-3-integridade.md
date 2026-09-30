# Portão pré-deploy — Plano 3/4: Integridade dos dados

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Acrescentar ao portão as etapas `integrity-read` (44 checagens SQL só-leitura no banco local, mais CPF, comparadas com uma linha de base) e `integrity-write` (regras de gravação reais exercidas em tabelas `TEMPORARY` do `sisconiecp_test`), mais testes unitários do `ReciboArquivo` e do catálogo.

**Architecture:** Um catálogo único de consultas (`Tests\Support\Integridade\Checagens`) devolve, para cada checagem, os ids que violam a regra. A suíte `integrity-read` abre o banco local por uma conexão que recusa usuário com permissão de escrita e liga `READ ONLY` na sessão; reprova só quando a contagem passa da linha de base (`tests/Integrity/baseline.json`). A suíte `integrity-write` clona a estrutura real das tabelas para tabelas `TEMPORARY` no `sisconiecp_test` e troca, só durante o teste, a conexão do singleton `Classes\Connect`, para exercitar as classes de produção sem tocar no banco local.

**Tech Stack:** PHP 8.4 CLI, PHPUnit 13.2, MySQL 5.7.44 (WAMP), PDO.

**Spec:** `docs/superpowers/specs/2026-09-30-testes-seguranca-integridade-design.md` (seção 6)

**Planos da série:** 1 (feito) → 2 contas de teste + HTTP (pendente) → **3 (este)** → 4 Playwright.

**Branch:** criar `testes/portao-3-integridade` a partir de `main` antes da Task 1.

## Global Constraints

- Todas as convenções do Plano 1 continuam: `declare(strict_types=1)` em todo PHP novo; nada em `composer.json`/`vendor`; **código de produção não é alterado** — teste que reprova por defeito real vira entrada em `tests/allowlist.php` com motivo e data, e é relatado.
- Banco local (`GATE_LOCAL_DSN`, hoje `conie847_sisconiecp`): **somente leitura**. Nenhum teste deste plano grava nele.
- Escrita só em tabelas `TEMPORARY` do banco `sisconiecp_test`, pela conexão `SISCONIECP_TEST_*` (mesma convenção de `tests/portaria/README.md`).
- Usuário de leitura atual: `sisconiecp_test@localhost` com `SELECT` em `conie847_sisconiecp` (decisão do humano em 2026-09-30).
- A linha de base só reprova quando a contagem **aumenta** (spec §6a). Reduzir a linha de base é ação manual após limpeza.
- Suítes de integridade **falham** (não pulam) quando `tests/.env.local` falta: pulado seria aprovação silenciosa.
- Git: commits com `git commit -F <arquivo-de-mensagem>` (o `rtk git commit` quebra mensagem multilinha); PHP com barra invertida escrito com a ferramenta Write, não heredoc do Bash.
- Commits terminam com `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Fatos verificados em 2026-09-30 (usados pelas tasks)

- `tipoContabil`: `1` = receita, `2` = despesa (totais de congregação e CONIECP batem 100% com essa leitura).
- `saldo` do balancete é acumulado do mês anterior: só `totalReceitas`/`totalDespesas` são comparados com os itens.
- Balancete de IECP: o total gravado é o dos itens próprios **ou** o consolidado (itens próprios + `totalReceitas`/`totalDespesas` dos balancetes de congregação da mesma IECP no mesmo mês). Verificado em 2012–2026, todos os status: só o balancete #1 (06/2012, IECP 2, sem congregações) foge das duas regras — gravado menor que os itens (receita −513,00; despesa −186,30). Rascunhos (`Em Elaboracao`) ainda não têm total recalculado e ficam de fora.
- Nenhum balancete de IECP chega a `Finalizado` desde 2022 (últimos: 139 em 2021); por isso as checagens contábeis olham todo status exceto rascunho, não só `Finalizado`.
- `autenticador_doc.doc_pdf` guarda o PDF no banco; `SHA2(doc_pdf, 256)` bate com `pdf_sha256` nos 389 documentos.
- `statusministro` tem chave `idStatusMembro`.
- Não há coluna cifrada (`*_enc`) no schema local: a checagem "campo cifrado sem texto puro" do spec não se aplica a este banco (ver Task 4).
- `CREATE TEMPORARY TABLE x LIKE conie847_sisconiecp.x` funciona com o usuário de teste; `Recibo_congregacao::excluirPorItem()` usa a conexão trocada por `ReflectionProperty(Classes\Connect::class, 'instance')`.
- Colunas `ascii` (`notificacao_destinatario.versaoDocumento`, `notificacao_evento.ip`, `notificacao_evento.versaoDocumento`) são intencionais e ficam fora da checagem de charset.

## Review Focus

1. Usuário de leitura com permissão de escrita (ex.: alguém devolve `ALL PRIVILEGES`) → a suíte recusa abrir a conexão, com mensagem que nomeia a permissão. Teste em Task 1 (`ConexaoLeituraTest`).
2. Consulta do catálogo que escreve, tem `;` ou `INTO OUTFILE` → reprovada no `unit`, antes de tocar o banco. Teste em Task 1 (`CatalogoTest::testSoLeitura`).
3. `SISCONIECP_TEST_DSN` apontando para o banco real por engano → testes de escrita recusam rodar. Teste em Task 4 (`BancoTesteTest::testRecusaBancoQueNaoEhDeTeste`).
4. `tests/.env.local` ausente durante `integrity-*` → erro explícito, nunca "pulado". Teste em Task 1 (`AmbienteTest`).
5. Troca da conexão do `Connect` vazando para outros testes → restaurada no `tearDown`, verificada. Teste em Task 4 (`BancoTesteTest::testTrocaERestauraConexaoDoSistema`).

---

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `tests/Support/Integridade/Checagens.php` | catálogo: id → descrição + SQL que devolve os ids violadores |
| `tests/Support/Integridade/LinhaBase.php` | lê `tests/Integrity/baseline.json` |
| `tests/Support/Integridade/Ambiente.php` | carrega `tests/.env.local` ou falha |
| `tests/Support/Integridade/ConexaoLeitura.php` | PDO do banco local que recusa usuário com escrita e liga READ ONLY |
| `tests/Support/Integridade/BancoTeste.php` | PDO do `sisconiecp_test`, clonagem para `TEMPORARY`, troca do singleton `Connect` |
| `tests/Integrity/baseline.json` | contagens aceitas por checagem |
| `tests/Integrity/Read/ConsistenciaTest.php` | roda o catálogo + CPF |
| `tests/Integrity/Write/ReciboExclusaoTest.php` | exclusão em cascata dos 3 tipos de recibo |
| `tests/Integrity/Write/TextoUtf8Test.php` | texto com acento/emoji gravado e relido idêntico |
| `tests/Unit/Integridade/*Test.php` | testes sem banco dos itens acima + `ReciboArquivo` |
| `phpunit.xml`, `tests/gate.php`, `tests/README.md` | registrar as suítes |

---

### Task 1: Catálogo, linha de base, ambiente e conexão só-leitura

**Files:**
- Create: `tests/Support/Integridade/Checagens.php`
- Create: `tests/Support/Integridade/LinhaBase.php`
- Create: `tests/Support/Integridade/Ambiente.php`
- Create: `tests/Support/Integridade/ConexaoLeitura.php`
- Create: `tests/Integrity/baseline.json` (vazio: `{}`)
- Test: `tests/Unit/Integridade/CatalogoTest.php`
- Test: `tests/Unit/Integridade/ConexaoLeituraTest.php`
- Test: `tests/Unit/Integridade/AmbienteTest.php`

**Interfaces:**
- Consumes: `Tests\Support\Env` (Plano 1): `carregar(string): Env`, `exigir(string): string`, `get(string): ?string`.
- Produces:
  - `Checagens::todas(): array<string, array{descricao: string, sql: string}>`
  - `Checagens::IDS_PHP` (const `list<string>`): checagens feitas em PHP, fora do SQL — hoje `['ministro_cpf_invalido']`.
  - `LinhaBase::carregar(string $arquivo): LinhaBase` (lança `RuntimeException` se JSON inválido ou valor não inteiro ≥ 0); `LinhaBase::deArray(array): LinhaBase`; `->aceito(string $id): int` (0 se ausente); `->ids(): list<string>`.
  - `Ambiente::env(?string $arquivo = null): Env` (padrão `SISCONIECP_RAIZ . '/tests/.env.local'`; lança `RuntimeException` se ausente).
  - `ConexaoLeitura::abrir(Env $env): PDO` (FETCH_ASSOC; lança `RuntimeException` se o usuário tem escrita no banco); `ConexaoLeitura::permissoesDeEscrita(list<string> $grants, string $banco): list<string>`.

- [ ] **Step 1: Criar o branch**

```bash
git switch -c testes/portao-3-integridade
```

- [ ] **Step 2: Escrever os testes (RED)**

`tests/Unit/Integridade/CatalogoTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Integridade;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Integridade\Checagens;
use Tests\Support\Integridade\LinhaBase;

final class CatalogoTest extends TestCase
{
    public static function checagens(): array
    {
        $casos = [];
        foreach (Checagens::todas() as $id => $checagem) {
            $casos[$id] = [$id, $checagem['descricao'], $checagem['sql']];
        }

        return $casos;
    }

    #[DataProvider('checagens')]
    public function testSoLeitura(string $id, string $descricao, string $sql): void
    {
        $this->assertMatchesRegularExpression('/^\s*SELECT\s/i', $sql, "{$id} precisa começar com SELECT");
        $this->assertStringNotContainsString(';', $sql, "{$id}: uma instrução só");
        $this->assertDoesNotMatchRegularExpression(
            '/\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE|GRANT|LOAD|HANDLER|CALL|LOCK)\b|INTO\s+(OUT|DUMP)FILE|\bSLEEP\s*\(|\bBENCHMARK\s*\(/i',
            $sql,
            "{$id} tem comando proibido"
        );
    }

    #[DataProvider('checagens')]
    public function testIdEDescricao(string $id, string $descricao, string $sql): void
    {
        $this->assertMatchesRegularExpression('/^[a-z0-9]+(_[a-z0-9]+)*$/', $id);
        $this->assertNotSame('', trim($descricao));
    }

    public function testLinhaBaseSoTemChecagensConhecidas(): void
    {
        $base = LinhaBase::carregar(SISCONIECP_RAIZ . '/tests/Integrity/baseline.json');
        $conhecidas = [...array_keys(Checagens::todas()), ...Checagens::IDS_PHP];

        foreach ($base->ids() as $id) {
            $this->assertContains($id, $conhecidas, "baseline.json tem checagem inexistente: {$id}");
        }
    }

    public function testLinhaBaseRecusaValorInvalido(): void
    {
        foreach ([['x' => -1], ['x' => '3'], ['x' => 1.5]] as $dados) {
            try {
                LinhaBase::deArray($dados);
                $this->fail('Deveria recusar ' . json_encode($dados));
            } catch (RuntimeException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function testLinhaBaseAusenteEhZero(): void
    {
        $this->assertSame(0, LinhaBase::deArray(['a' => 2])->aceito('b'));
        $this->assertSame(2, LinhaBase::deArray(['a' => 2])->aceito('a'));
    }
}
```

`tests/Unit/Integridade/ConexaoLeituraTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Integridade;

use PHPUnit\Framework\TestCase;
use Tests\Support\Integridade\ConexaoLeitura;

final class ConexaoLeituraTest extends TestCase
{
    public function testGrantsAtuaisSaoSoLeitura(): void
    {
        // Saída real de SHOW GRANTS em 2026-09-30, depois da redução de permissões.
        $grants = [
            "GRANT SELECT, CREATE, RELOAD, REFERENCES, SHOW DATABASES, CREATE TEMPORARY TABLES, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, CREATE USER, EVENT, TRIGGER ON *.* TO 'sisconiecp_test'@'localhost'",
            "GRANT SELECT, CREATE, CREATE TEMPORARY TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, TRIGGER ON `conie847\\_sisconiecp`.* TO 'sisconiecp_test'@'localhost'",
            "GRANT SELECT, SHOW VIEW ON `conie847_sisconiecp`.* TO 'sisconiecp_test'@'localhost'",
        ];

        $this->assertSame([], ConexaoLeitura::permissoesDeEscrita($grants, 'conie847_sisconiecp'));
    }

    public function testDetectaEscritaNoBancoComCuringaEscapado(): void
    {
        $grants = ["GRANT SELECT, INSERT, DELETE ON `conie847\\_sisconiecp`.* TO 'u'@'localhost'"];

        $escrita = ConexaoLeitura::permissoesDeEscrita($grants, 'conie847_sisconiecp');

        $this->assertSame(['INSERT', 'DELETE'], array_map(fn ($p) => explode(' ON ', $p)[0], $escrita));
    }

    public function testDetectaAllPrivilegesGlobal(): void
    {
        $grants = ["GRANT ALL PRIVILEGES ON *.* TO 'u'@'localhost' WITH GRANT OPTION"];

        $this->assertNotSame([], ConexaoLeitura::permissoesDeEscrita($grants, 'conie847_sisconiecp'));
    }

    public function testIgnoraOutroBanco(): void
    {
        $grants = ["GRANT ALL PRIVILEGES ON `sisconiecp\\_test`.* TO 'u'@'localhost'"];

        $this->assertSame([], ConexaoLeitura::permissoesDeEscrita($grants, 'conie847_sisconiecp'));
    }

    public function testDetectaTabelaEspecificaEFileSuper(): void
    {
        $grants = [
            "GRANT UPDATE ON `conie847_sisconiecp`.`login` TO 'u'@'localhost'",
            "GRANT FILE, SUPER ON *.* TO 'u'@'localhost'",
        ];

        $this->assertCount(3, ConexaoLeitura::permissoesDeEscrita($grants, 'conie847_sisconiecp'));
    }
}
```

`tests/Unit/Integridade/AmbienteTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Integridade;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\Integridade\Ambiente;

final class AmbienteTest extends TestCase
{
    public function testArquivoAusenteFalhaComOrientacao(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('tests/.env.local');

        Ambiente::env(sys_get_temp_dir() . '/sem-env-' . bin2hex(random_bytes(4)));
    }

    public function testArquivoPresenteCarrega(): void
    {
        $arquivo = tempnam(sys_get_temp_dir(), 'env');
        file_put_contents($arquivo, "GATE_LOCAL_DSN=mysql:dbname=x\n");
        try {
            $this->assertSame('mysql:dbname=x', Ambiente::env($arquivo)->get('GATE_LOCAL_DSN'));
        } finally {
            unlink($arquivo);
        }
    }
}
```

- [ ] **Step 3: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter "CatalogoTest|ConexaoLeituraTest|AmbienteTest" --colors=never`
Expected: erros `Class "Tests\Support\Integridade\..." not found`.

- [ ] **Step 4: Implementar `tests/Support/Integridade/Checagens.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Integridade;

/**
 * Catálogo de checagens de integridade (spec §6a). Cada SQL devolve, na
 * primeira coluna, os ids que violam a regra; zero linhas = íntegro.
 * Só SELECT: CatalogoTest reprova qualquer comando de escrita.
 */
final class Checagens
{
    /** Checagens feitas em PHP (não cabem em SQL), aceitas no baseline.json. */
    public const IDS_PHP = ['ministro_cpf_invalido'];

    /** @return array<string, array{descricao: string, sql: string}> */
    public static function todas(): array
    {
        return [
            // Órfãos
            'recibo_iecp_sem_item' => self::c(
                'Recibo de IECP apontando para item de balancete inexistente',
                'SELECT r.idRecibo_arm FROM recibo_armazenado_iecp r LEFT JOIN itembalancete i ON i.idItem = r.idItem_balancete WHERE i.idItem IS NULL'
            ),
            'recibo_congregacao_sem_item' => self::c(
                'Recibo de congregação apontando para item inexistente',
                'SELECT r.idRecibo_arm FROM recibo_armazenado_congregacao r LEFT JOIN itembalancete_congregacao i ON i.idItem = r.idItem_balancete WHERE i.idItem IS NULL'
            ),
            'recibo_coniecp_sem_item' => self::c(
                'Recibo da CONIECP apontando para item inexistente',
                'SELECT r.idRecibo_arm FROM recibo_armazenado_coniecp r LEFT JOIN itembalancete_coniecp i ON i.idItem = r.idItem_balancete WHERE i.idItem IS NULL'
            ),
            'item_iecp_sem_balancete' => self::c(
                'Item de balancete de IECP sem balancete',
                'SELECT i.idItem FROM itembalancete i LEFT JOIN balancete b ON b.idBalancete = i.idBalancete WHERE b.idBalancete IS NULL'
            ),
            'item_congregacao_sem_balancete' => self::c(
                'Item de balancete de congregação sem balancete',
                'SELECT i.idItem FROM itembalancete_congregacao i LEFT JOIN balancete_congregacao b ON b.idBalancete_Congregacao = i.idBalancete_Congregacao WHERE b.idBalancete_Congregacao IS NULL'
            ),
            'item_coniecp_sem_balancete' => self::c(
                'Item de balancete da CONIECP sem balancete',
                'SELECT i.idItem FROM itembalancete_coniecp i LEFT JOIN balancete_coniecp b ON b.idBalanceteConiecp = i.idBalanceteConiecp WHERE b.idBalanceteConiecp IS NULL'
            ),
            'anexo_oficio_sem_oficio' => self::c(
                'Anexo de ofício da CONIECP sem ofício',
                'SELECT a.id FROM anexo_oficio a LEFT JOIN oficio o ON o.idOficio = a.idOficio WHERE o.idOficio IS NULL'
            ),
            'anexo_oficio_iecp_sem_oficio' => self::c(
                'Anexo de ofício de IECP sem ofício',
                'SELECT a.id FROM anexo_oficio_iecp a LEFT JOIN oficioiecp o ON o.idOficioIecp = a.idOficioIecp WHERE o.idOficioIecp IS NULL'
            ),
            'historicocargo_sem_ministro' => self::c(
                'Histórico de cargo de ministro inexistente',
                'SELECT h.id FROM historicocargo h LEFT JOIN cadastroministro c ON c.rm = h.rm WHERE c.rm IS NULL'
            ),
            'historicofuncao_sem_ministro' => self::c(
                'Histórico de função de ministro inexistente',
                'SELECT h.id FROM historicofuncao h LEFT JOIN cadastroministro c ON c.rm = h.rm WHERE c.rm IS NULL'
            ),
            'historicopunicao_sem_ministro' => self::c(
                'Histórico de punição de ministro inexistente',
                'SELECT h.id FROM historicopunicao h LEFT JOIN cadastroministro c ON c.rm = h.rm WHERE c.rm IS NULL'
            ),
            'login_sem_ministro' => self::c(
                'Login sem cadastro de ministro',
                'SELECT l.id FROM login l LEFT JOIN cadastroministro c ON c.rm = l.rm WHERE c.rm IS NULL'
            ),
            'matricula_turma_sem_turma' => self::c(
                'Matrícula em turma EBD inexistente',
                'SELECT m.idMatriculaTurma FROM matricula_turmaebd m LEFT JOIN turmaebd t ON t.idTurmaEBD = m.idTurmaEBD WHERE t.idTurmaEBD IS NULL'
            ),
            'matricula_turma_sem_matricula' => self::c(
                'Vínculo de turma EBD apontando para matrícula inexistente',
                'SELECT m.idMatriculaTurma FROM matricula_turmaebd m LEFT JOIN matriculaebd e ON e.idMatriculaEBD = m.idMatriculaEBD WHERE e.idMatriculaEBD IS NULL'
            ),
            'certificado_2via_sem_certificado' => self::c(
                'Segunda via de certificado sem certificado',
                'SELECT v.id FROM certificado_2via v LEFT JOIN certificado_consagracao c ON c.id = v.certificado_id WHERE c.id IS NULL'
            ),

            // Referências
            'ministro_congregacao_inexistente' => self::c(
                'Ministro ligado a congregação inexistente',
                'SELECT c.rm FROM cadastroministro c LEFT JOIN congregacao g ON g.idCongregacao = c.idCongregacao WHERE c.idCongregacao IS NOT NULL AND c.idCongregacao <> 0 AND g.idCongregacao IS NULL'
            ),
            'ministro_iecp_inexistente' => self::c(
                'Ministro ligado a IECP inexistente',
                'SELECT c.rm FROM cadastroministro c LEFT JOIN iecp i ON i.idIecp = c.idIecp WHERE c.idIecp <> 0 AND i.idIecp IS NULL'
            ),
            'ministro_status_inexistente' => self::c(
                'Ministro com status fora da tabela statusministro',
                'SELECT c.rm FROM cadastroministro c LEFT JOIN statusministro s ON s.idStatusMembro = c.idStatusMinistro WHERE c.idStatusMinistro IS NOT NULL AND s.idStatusMembro IS NULL'
            ),
            'congregacao_iecp_inexistente' => self::c(
                'Congregação ligada a IECP inexistente',
                'SELECT g.idCongregacao FROM congregacao g LEFT JOIN iecp i ON i.idIecp = g.idIecp WHERE i.idIecp IS NULL'
            ),

            // Contábil (tipoContabil 1 = receita, 2 = despesa; saldo é acumulado e fica de fora).
            // Rascunho ('Em Elaboracao') fica de fora: o total só é recalculado ao enviar.
            // IECP: o total gravado é o dos itens próprios OU o consolidado com os balancetes
            // das congregações da IECP no mesmo mês (análise de 2026-09-30, 2012–2026).
            'totais_iecp' => self::c(
                'Balancete de IECP com total diferente dos itens e do consolidado com as congregações do mês',
                "SELECT b.idBalancete FROM balancete b LEFT JOIN ("
                . 'SELECT idBalancete AS id, SUM(CASE WHEN tipoContabil = 1 THEN valor ELSE 0 END) AS r, '
                . 'SUM(CASE WHEN tipoContabil = 2 THEN valor ELSE 0 END) AS d FROM itembalancete GROUP BY idBalancete'
                . ') s ON s.id = b.idBalancete LEFT JOIN ('
                . 'SELECT idIecp, mes, ano, SUM(totalReceitas) AS r, SUM(totalDespesas) AS d FROM balancete_congregacao GROUP BY idIecp, mes, ano'
                . ') c ON c.idIecp = b.idIecp AND c.mes = b.mes AND c.ano = b.ano '
                . "WHERE b.statusBalancete <> 'Em Elaboracao' "
                . 'AND NOT (ABS(b.totalReceitas - IFNULL(s.r, 0)) <= 0.01 AND ABS(b.totalDespesas - IFNULL(s.d, 0)) <= 0.01) '
                . 'AND NOT (ABS(b.totalReceitas - IFNULL(s.r, 0) - IFNULL(c.r, 0)) <= 0.01 AND ABS(b.totalDespesas - IFNULL(s.d, 0) - IFNULL(c.d, 0)) <= 0.01)'
            ),
            'totais_congregacao' => self::c(
                'Balancete de congregação (não rascunho) com total diferente da soma dos itens',
                self::totais('balancete_congregacao', 'idBalancete_Congregacao', 'itembalancete_congregacao', 'idBalancete_Congregacao')
            ),
            'totais_coniecp' => self::c(
                'Balancete da CONIECP (não rascunho) com total diferente da soma dos itens',
                self::totais('balancete_coniecp', 'idBalanceteConiecp', 'itembalancete_coniecp', 'idBalanceteConiecp')
            ),
            'balancete_iecp_finalizado_sem_itens' => self::c(
                'Balancete de IECP finalizado sem nenhum item',
                "SELECT b.idBalancete FROM balancete b LEFT JOIN itembalancete i ON i.idBalancete = b.idBalancete WHERE b.statusBalancete = 'Finalizado' AND i.idItem IS NULL"
            ),
            'balancete_congregacao_finalizado_sem_itens' => self::c(
                'Balancete de congregação finalizado sem nenhum item',
                "SELECT b.idBalancete_Congregacao FROM balancete_congregacao b LEFT JOIN itembalancete_congregacao i ON i.idBalancete_Congregacao = b.idBalancete_Congregacao WHERE b.statusBalancete = 'Finalizado' AND i.idItem IS NULL"
            ),
            'balancete_coniecp_finalizado_sem_itens' => self::c(
                'Balancete da CONIECP finalizado sem nenhum item',
                "SELECT b.idBalanceteConiecp FROM balancete_coniecp b LEFT JOIN itembalancete_coniecp i ON i.idBalanceteConiecp = b.idBalanceteConiecp WHERE b.statusBalancete = 'Finalizado' AND i.idItem IS NULL"
            ),
            'balancete_iecp_mes_duplicado' => self::c(
                'Mais de um balancete de IECP no mesmo mês',
                self::duplicados('balancete', 'idBalancete', ['idIecp', 'mes', 'ano'])
            ),
            'balancete_congregacao_mes_duplicado' => self::c(
                'Mais de um balancete de congregação no mesmo mês',
                self::duplicados('balancete_congregacao', 'idBalancete_Congregacao', ['idCongregacao', 'mes', 'ano'])
            ),
            'balancete_coniecp_mes_duplicado' => self::c(
                'Mais de um balancete da CONIECP no mesmo mês',
                self::duplicados('balancete_coniecp', 'idBalanceteConiecp', ['mes', 'ano'])
            ),
            'item_valor_nao_positivo' => self::c(
                'Item de balancete com valor zero ou negativo',
                'SELECT idItem FROM itembalancete WHERE valor <= 0 UNION ALL SELECT idItem FROM itembalancete_congregacao WHERE valor <= 0 UNION ALL SELECT idItem FROM itembalancete_coniecp WHERE valor <= 0'
            ),

            // Unicidade
            'login_email_duplicado' => self::c('E-mail de login repetido', self::duplicados('login', 'id', ['email'])),
            'ministro_cpf_duplicado' => self::c(
                'CPF repetido entre ministros (ignorando pontuação)',
                "SELECT MIN(rm) FROM cadastroministro WHERE cpf <> '' GROUP BY REPLACE(REPLACE(REPLACE(cpf, '.', ''), '-', ''), ' ', '') HAVING COUNT(*) > 1"
            ),
            'portaria_numero_duplicado' => self::c('Número de portaria repetido no ano', self::duplicados('portaria', 'idPortaria', ['numeroPortaria', 'anoPortaria'])),
            'circular_numero_duplicado' => self::c('Número de circular repetido no ano', self::duplicados('circular', 'idCircular', ['numeroCircular', 'anoCircular'])),
            'edital_numero_duplicado' => self::c('Número de edital repetido no ano', self::duplicados('edital', 'idEdital', ['numeroEdital', 'anoEdital'])),
            'notificacao_numero_duplicado' => self::c('Número de notificação repetido no ano', self::duplicados('notificacao', 'idNotificacao', ['numeroNotificacao', 'anoNotificacao'])),
            'oficio_numero_duplicado' => self::c(
                'Número de ofício da CONIECP repetido no ano',
                "SELECT MIN(idOficio) FROM oficio WHERE numeroOficio IS NOT NULL AND numeroOficio <> '' GROUP BY numeroOficio, YEAR(data) HAVING COUNT(*) > 1"
            ),
            'oficio_iecp_numero_duplicado' => self::c(
                'Número de ofício de IECP repetido no ano',
                "SELECT MIN(idOficioIecp) FROM oficioiecp WHERE numeroOficioIecp IS NOT NULL AND numeroOficioIecp <> '' GROUP BY idIecp, numeroOficioIecp, YEAR(data) HAVING COUNT(*) > 1"
            ),
            'autenticador_numero_duplicado' => self::c('Código do autenticador repetido', self::duplicados('autenticador_doc', 'id', ['numero_doc'])),

            // Formato
            'ministro_data_nasc_invalida' => self::c(
                'Data de nascimento antes de 1900 ou no futuro',
                'SELECT rm FROM cadastroministro WHERE YEAR(dataNasc) < 1900 OR dataNasc > CURDATE()'
            ),
            'ministro_data_ingresso_invalida' => self::c(
                'Data de ingresso antes de 1900 ou mais de um ano no futuro',
                'SELECT rm FROM cadastroministro WHERE YEAR(dataIngresso) < 1900 OR dataIngresso > DATE_ADD(CURDATE(), INTERVAL 1 YEAR)'
            ),
            'login_email_invalido' => self::c(
                'E-mail de login em formato inválido',
                "SELECT id FROM login WHERE email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$'"
            ),
            'coluna_texto_sem_utf8mb4' => self::c(
                'Coluna de texto fora de utf8mb4 (emoji e texto do Word podem se perder)',
                "SELECT CONCAT(TABLE_NAME, '.', COLUMN_NAME) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND CHARACTER_SET_NAME IS NOT NULL AND CHARACTER_SET_NAME NOT IN ('utf8mb4', 'ascii', 'binary')"
            ),

            // Autenticador
            'autenticador_finalizado_sem_pdf' => self::c(
                'Documento finalizado no autenticador sem PDF',
                'SELECT id FROM autenticador_doc WHERE finalized_at IS NOT NULL AND doc_pdf IS NULL'
            ),
            'autenticador_sha256_divergente' => self::c(
                'Documento finalizado cujo SHA-256 não bate com o PDF gravado',
                'SELECT id FROM autenticador_doc WHERE finalized_at IS NOT NULL AND doc_pdf IS NOT NULL AND (pdf_sha256 IS NULL OR LOWER(pdf_sha256) <> SHA2(doc_pdf, 256))'
            ),
        ];
    }

    /** @return array{descricao: string, sql: string} */
    private static function c(string $descricao, string $sql): array
    {
        return ['descricao' => $descricao, 'sql' => $sql];
    }

    private static function totais(string $balancete, string $pk, string $itens, string $fk): string
    {
        return "SELECT b.{$pk} FROM {$balancete} b LEFT JOIN ("
            . "SELECT {$fk} AS id, SUM(CASE WHEN tipoContabil = 1 THEN valor ELSE 0 END) AS r, "
            . "SUM(CASE WHEN tipoContabil = 2 THEN valor ELSE 0 END) AS d FROM {$itens} GROUP BY {$fk}"
            . ") s ON s.id = b.{$pk} WHERE b.statusBalancete <> 'Em Elaboracao' "
            . 'AND (ABS(b.totalReceitas - IFNULL(s.r, 0)) > 0.01 OR ABS(b.totalDespesas - IFNULL(s.d, 0)) > 0.01)';
    }

    /** @param list<string> $colunas */
    private static function duplicados(string $tabela, string $pk, array $colunas): string
    {
        $preenchidas = implode(' AND ', array_map(static fn (string $c) => "{$c} IS NOT NULL AND {$c} <> ''", $colunas));

        return "SELECT MIN({$pk}) FROM {$tabela} WHERE {$preenchidas} GROUP BY " . implode(', ', $colunas) . ' HAVING COUNT(*) > 1';
    }
}
```

Nota: os três "finalizado sem itens" usam `LEFT JOIN ... IS NULL` em vez de `NOT EXISTS`; na sondagem, `NOT EXISTS` levou 2–3 s por tabela.

- [ ] **Step 5: Implementar `LinhaBase`, `Ambiente` e `ConexaoLeitura`**

`tests/Support/Integridade/LinhaBase.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Integridade;

use RuntimeException;

/**
 * Contagens aceitas por checagem (spec §6a): sujeira antiga não trava o
 * deploy, mas qualquer aumento reprova. Reduzir é ação manual após limpeza.
 */
final class LinhaBase
{
    /** @param array<string, int> $aceitos */
    private function __construct(private readonly array $aceitos)
    {
    }

    public static function carregar(string $arquivo): self
    {
        $dados = json_decode((string) @file_get_contents($arquivo), true);
        if (!is_array($dados)) {
            throw new RuntimeException('Linha de base ilegível ou ausente: ' . $arquivo);
        }

        return self::deArray($dados);
    }

    public static function deArray(array $dados): self
    {
        foreach ($dados as $id => $valor) {
            if (!is_int($valor) || $valor < 0) {
                throw new RuntimeException("Linha de base: '{$id}' precisa ser inteiro >= 0.");
            }
        }

        return new self($dados);
    }

    public function aceito(string $id): int
    {
        return $this->aceitos[$id] ?? 0;
    }

    /** @return list<string> */
    public function ids(): array
    {
        return array_map('strval', array_keys($this->aceitos));
    }
}
```

`tests/Support/Integridade/Ambiente.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Integridade;

use RuntimeException;
use Tests\Support\Env;

final class Ambiente
{
    /** Suítes de integridade falham (não pulam) sem ambiente: pular seria aprovar em silêncio. */
    public static function env(?string $arquivo = null): Env
    {
        $arquivo ??= SISCONIECP_RAIZ . '/tests/.env.local';
        if (!is_file($arquivo)) {
            throw new RuntimeException('tests/.env.local ausente: as suítes de integridade exigem o banco configurado (ver tests/README.md).');
        }

        return Env::carregar($arquivo);
    }
}
```

`tests/Support/Integridade/ConexaoLeitura.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Integridade;

use PDO;
use RuntimeException;
use Tests\Support\Env;

/**
 * Conexão do banco local para as checagens. Recusa usuário que possa alterar
 * dados e ainda liga READ ONLY na sessão (defesa em profundidade).
 */
final class ConexaoLeitura
{
    private const ESCRITA = ['ALL', 'ALL PRIVILEGES', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'FILE', 'SUPER'];

    public static function abrir(Env $env): PDO
    {
        $pdo = new PDO(
            $env->exigir('GATE_LOCAL_DSN'),
            $env->exigir('GATE_LOCAL_READ_USER'),
            (string) $env->get('GATE_LOCAL_READ_PASSWORD'),
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
        );
        $banco = (string) $pdo->query('SELECT DATABASE()')->fetchColumn();
        $grants = $pdo->query('SHOW GRANTS FOR CURRENT_USER()')->fetchAll(PDO::FETCH_COLUMN);
        $escrita = self::permissoesDeEscrita($grants, $banco);
        if ($escrita !== []) {
            throw new RuntimeException(
                "GATE_LOCAL_READ_USER pode alterar {$banco} (" . implode('; ', $escrita)
                . '). As checagens exigem usuário só com SELECT (ver tests/README.md).'
            );
        }
        $pdo->exec('SET SESSION TRANSACTION READ ONLY');

        return $pdo;
    }

    /**
     * @param list<string> $grants linhas de SHOW GRANTS
     * @return list<string> permissões de escrita que alcançam $banco
     */
    public static function permissoesDeEscrita(array $grants, string $banco): array
    {
        $escrita = [];
        foreach ($grants as $grant) {
            if (!preg_match('/^GRANT\s+(.+?)\s+ON\s+(\S+)\s+TO\s/i', $grant, $m)) {
                continue;
            }
            $alvo = str_replace(['`', '\\'], '', $m[2]);
            $bancoDoGrant = explode('.', $alvo, 2)[0];
            if ($bancoDoGrant !== '*' && strcasecmp($bancoDoGrant, $banco) !== 0) {
                continue;
            }
            foreach (array_map('trim', explode(',', strtoupper($m[1]))) as $permissao) {
                if (in_array($permissao, self::ESCRITA, true)) {
                    $escrita[] = $permissao . ' ON ' . $alvo;
                }
            }
        }

        return array_values(array_unique($escrita));
    }
}
```

Criar `tests/Integrity/baseline.json` com o conteúdo `{}` (preenchido na Task 3).

- [ ] **Step 6: Rodar e confirmar que passa**

Run: `php vendor/bin/phpunit --testsuite unit --filter "CatalogoTest|ConexaoLeituraTest|AmbienteTest" --colors=never`
Expected: `OK` (44 checagens × 2 + 3 + 5 + 2 = 98 testes).

- [ ] **Step 7: Commit**

```bash
git add tests/Support/Integridade/ tests/Integrity/baseline.json tests/Unit/Integridade/
git commit -F <mensagem: "test: catálogo de integridade, linha de base e conexão só-leitura">
```

---

### Task 2: `ReciboArquivo` não apaga fora da pasta de recibos

**Files:**
- Test: `tests/Unit/Integridade/ReciboArquivoTest.php`

**Interfaces:**
- Consumes: `ReciboArquivo::remover(?string $local): bool` (classe global em `classes/ReciboArquivo.php`): `$local` é relativo a `iecp/tesouraria/balanceteMensal/`, precisa começar com `recibos/`, extensão `jpg|jpeg|png|webp`; devolve `true` só se apagou.
- Produces: nada.

Teste de caracterização (a classe já existe): deve passar de primeira. Cria e remove arquivos temporários dentro de `iecp/tesouraria/balanceteMensal/`, sempre limpos no `tearDown`.

- [ ] **Step 1: Escrever `tests/Unit/Integridade/ReciboArquivoTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Integridade;

use PHPUnit\Framework\TestCase;
use ReciboArquivo;

final class ReciboArquivoTest extends TestCase
{
    private string $base;
    private string $pasta;
    /** @var list<string> */
    private array $criados = [];

    public static function setUpBeforeClass(): void
    {
        require_once SISCONIECP_RAIZ . '/classes/ReciboArquivo.php';
    }

    protected function setUp(): void
    {
        $this->base = SISCONIECP_RAIZ . '/iecp/tesouraria/balanceteMensal';
        $this->pasta = 'recibos/gate-teste-' . bin2hex(random_bytes(4));
        mkdir($this->base . '/' . $this->pasta, 0777, true);
    }

    protected function tearDown(): void
    {
        foreach ($this->criados as $arquivo) {
            @unlink($arquivo);
        }
        @rmdir($this->base . '/' . $this->pasta);
    }

    private function criar(string $relativo): string
    {
        $absoluto = $this->base . '/' . $relativo;
        file_put_contents($absoluto, 'x');
        $this->criados[] = $absoluto;

        return $absoluto;
    }

    public function testRemoveArquivoDentroDeRecibos(): void
    {
        $arquivo = $this->criar($this->pasta . '/a.webp');

        $this->assertTrue(ReciboArquivo::remover($this->pasta . '/a.webp'));
        $this->assertFileDoesNotExist($arquivo);
    }

    public function testAceitaBarraInvertida(): void
    {
        $arquivo = $this->criar($this->pasta . '/b.jpg');

        $this->assertTrue(ReciboArquivo::remover(str_replace('/', '\\', $this->pasta . '/b.jpg')));
        $this->assertFileDoesNotExist($arquivo);
    }

    public function testRecusaTraversalParaForaDeRecibos(): void
    {
        $isca = $this->criar('gate-isca-' . bin2hex(random_bytes(4)) . '.webp');

        $this->assertFalse(ReciboArquivo::remover('recibos/../' . basename($isca)));
        $this->assertFileExists($isca);
    }

    public function testRecusaExtensaoNaoPermitida(): void
    {
        $arquivo = $this->criar($this->pasta . '/c.php');

        $this->assertFalse(ReciboArquivo::remover($this->pasta . '/c.php'));
        $this->assertFileExists($arquivo);
    }

    public function testRecusaVazioNuloEAbsoluto(): void
    {
        $arquivo = $this->criar($this->pasta . '/d.png');

        $this->assertFalse(ReciboArquivo::remover(null));
        $this->assertFalse(ReciboArquivo::remover(''));
        $this->assertFalse(ReciboArquivo::remover($arquivo));
        $this->assertFileExists($arquivo);
    }

    public function testArquivoInexistente(): void
    {
        $this->assertFalse(ReciboArquivo::remover($this->pasta . '/nao-existe.webp'));
    }
}
```

- [ ] **Step 2: Rodar**

Run: `php vendor/bin/phpunit --testsuite unit --filter ReciboArquivoTest --colors=never`
Expected: `OK (6 tests, ...)`. Falha: não altere `classes/`; registre na allowlist e relate. Confira que nenhum `gate-teste-*` ou `gate-isca-*` sobrou: `ls iecp/tesouraria/balanceteMensal iecp/tesouraria/balanceteMensal/recibos | grep gate-` deve sair vazio.

- [ ] **Step 3: Commit**

```bash
git add tests/Unit/Integridade/ReciboArquivoTest.php
git commit -F <mensagem: "test: ReciboArquivo só apaga dentro da pasta de recibos">
```

---

### Task 3: Suíte `integrity-read` e linha de base

**Files:**
- Modify: `phpunit.xml` (nova testsuite)
- Modify: `tests/gate.php` (nova etapa e prefixo)
- Modify: `tests/Integrity/baseline.json`
- Test: `tests/Integrity/Read/ConsistenciaTest.php`

**Interfaces:**
- Consumes: `Checagens::todas()`, `Checagens::IDS_PHP`, `LinhaBase::carregar()/aceito()`, `Ambiente::env()`, `ConexaoLeitura::abrir()` (Task 1); `ValidarCpf->validar($cpf)` devolve `0` válido / `1` inválido (Plano 1); `EtapaPhpUnit(string $raiz, string $suite, Allowlist $allowlist)` (Plano 1).
- Produces: suíte PHPUnit `integrity-read`; etapa `integrity-read` no `gate.php`, prefixo `Tests\Integrity\Read\`.

- [ ] **Step 1: Registrar a suíte no `phpunit.xml`**

Dentro de `<testsuites>`, depois da suíte `unit`:

```xml
        <testsuite name="integrity-read">
            <directory>tests/Integrity/Read</directory>
        </testsuite>
```

- [ ] **Step 2: Escrever `tests/Integrity/Read/ConsistenciaTest.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Integrity\Read;

use PDO;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Support\Integridade\Ambiente;
use Tests\Support\Integridade\Checagens;
use Tests\Support\Integridade\ConexaoLeitura;
use Tests\Support\Integridade\LinhaBase;
use ValidarCpf;

final class ConsistenciaTest extends TestCase
{
    private static ?PDO $pdo = null;
    private static LinhaBase $base;

    public static function setUpBeforeClass(): void
    {
        self::$pdo = ConexaoLeitura::abrir(Ambiente::env());
        self::$base = LinhaBase::carregar(SISCONIECP_RAIZ . '/tests/Integrity/baseline.json');
    }

    public static function tearDownAfterClass(): void
    {
        self::$pdo = null;
    }

    public static function checagens(): array
    {
        $casos = [];
        foreach (Checagens::todas() as $id => $checagem) {
            $casos[$id] = [$id, $checagem['descricao'], $checagem['sql']];
        }

        return $casos;
    }

    #[DataProvider('checagens')]
    public function testNaoPiorouEmRelacaoALinhaDeBase(string $id, string $descricao, string $sql): void
    {
        $violacoes = self::$pdo->query($sql)->fetchAll(PDO::FETCH_COLUMN);

        $this->assertViolacoes($id, $descricao, $violacoes);
    }

    public function testCpfsCadastradosValidos(): void
    {
        require_once SISCONIECP_RAIZ . '/classes/ValidarCpf.class.php';
        $validador = new ValidarCpf();
        $invalidos = [];
        foreach (self::$pdo->query('SELECT rm, cpf FROM cadastroministro') as $linha) {
            if ($validador->validar((string) $linha['cpf']) !== 0) {
                $invalidos[] = $linha['rm'];
            }
        }

        $this->assertViolacoes('ministro_cpf_invalido', 'CPF de ministro com dígito verificador inválido', $invalidos);
    }

    /** @param list<mixed> $violacoes */
    private function assertViolacoes(string $id, string $descricao, array $violacoes): void
    {
        $aceito = self::$base->aceito($id);

        $this->assertLessThanOrEqual($aceito, count($violacoes), sprintf(
            "%s [%s]: %d ocorrência(s), linha de base %d. Primeiros ids: %s",
            $descricao,
            $id,
            count($violacoes),
            $aceito,
            implode(', ', array_slice($violacoes, 0, 20))
        ));
    }
}
```

- [ ] **Step 3: Rodar com a linha de base vazia (RED)**

Run: `php vendor/bin/phpunit --testsuite integrity-read --colors=never 2>&1 | grep -E "\[[a-z0-9_]+\]: [0-9]+ ocorr" | sed -E 's/.*\[([a-z0-9_]+)\]: ([0-9]+) ocorr.*/\1 \2/'`
Expected (contagens de 2026-09-30; se diferirem, o banco mudou — use as atuais e anote a diferença no relatório final):

```
recibo_iecp_sem_item 1
item_congregacao_sem_balancete 7
anexo_oficio_iecp_sem_oficio 10
historicocargo_sem_ministro 7
historicofuncao_sem_ministro 17
historicopunicao_sem_ministro 3
login_sem_ministro 1
matricula_turma_sem_matricula 1046
ministro_status_inexistente 1
totais_iecp 1
balancete_iecp_finalizado_sem_itens 6
balancete_congregacao_finalizado_sem_itens 43
oficio_iecp_numero_duplicado 1
ministro_cpf_invalido 7
```

As demais 31 checagens SQL passam com zero. Se `setUpBeforeClass` falhar com "GATE_LOCAL_READ_USER pode alterar", pare e relate ao humano: as permissões mudaram.

- [ ] **Step 4: Gravar a linha de base**

`tests/Integrity/baseline.json` com exatamente as contagens do Step 3, em ordem alfabética:

```json
{
    "anexo_oficio_iecp_sem_oficio": 10,
    "balancete_congregacao_finalizado_sem_itens": 43,
    "balancete_iecp_finalizado_sem_itens": 6,
    "historicocargo_sem_ministro": 7,
    "historicofuncao_sem_ministro": 17,
    "historicopunicao_sem_ministro": 3,
    "item_congregacao_sem_balancete": 7,
    "login_sem_ministro": 1,
    "matricula_turma_sem_matricula": 1046,
    "ministro_cpf_invalido": 7,
    "ministro_status_inexistente": 1,
    "oficio_iecp_numero_duplicado": 1,
    "recibo_iecp_sem_item": 1,
    "totais_iecp": 1
}
```

- [ ] **Step 5: Rodar (GREEN)**

Run: `php vendor/bin/phpunit --testsuite integrity-read --colors=never`
Expected: `OK (45 tests, 45 assertions)`.

Run: `php vendor/bin/phpunit --testsuite unit --filter CatalogoTest --colors=never`
Expected: `OK` (a linha de base só contém checagens conhecidas).

- [ ] **Step 6: Registrar a etapa no `gate.php`**

No array `$etapas`, depois de `'legado' => ...`:

```php
    'integrity-read' => new EtapaPhpUnit($raiz, 'integrity-read', $allowlist),
```

E no array `$prefixos`:

```php
$prefixos = [
    'lint' => 'lint::',
    'unit' => 'Tests\\Unit\\',
    'legado' => 'legado::',
    'integrity-read' => 'Tests\\Integrity\\Read\\',
];
```

Atualizar o comentário acima de `$semServidor` para: `// Ordem de execução. Planos 2 e 4 acrescentam: contas, http, e2e.`

- [ ] **Step 7: Rodar a etapa pelo portão**

Run: `php tests/gate.php --suite=integrity-read; echo "exit=$?"`
Expected: `PASSOU preflight — Apache e MySQL respondendo (...)`, `PASSOU integrity-read — 45 teste(s): 45 passaram, 0 pulados`, `APROVADO`, `exit=0`. (Com WAMP desligado: `ABORTOU preflight` e `exit=2`.)

- [ ] **Step 8: Commit**

```bash
git add phpunit.xml tests/gate.php tests/Integrity/baseline.json tests/Integrity/Read/ConsistenciaTest.php
git commit -F <mensagem: "test: suíte integrity-read com 44 checagens e linha de base">
```

---

### Task 4: Suíte `integrity-write` (recibos em cascata e texto UTF-8)

**Files:**
- Create: `tests/Support/Integridade/BancoTeste.php`
- Modify: `phpunit.xml` (nova testsuite)
- Modify: `tests/gate.php` (nova etapa e prefixo)
- Test: `tests/Unit/Integridade/BancoTesteTest.php`
- Test: `tests/Integrity/Write/ReciboExclusaoTest.php`
- Test: `tests/Integrity/Write/TextoUtf8Test.php`

**Interfaces:**
- Consumes: `Ambiente::env()` (Task 1); `Classes\Connect` (propriedade privada estática `$instance`, `PDO|null`); `Recibo_iecp`, `Recibo_congregacao`, `Recibo_coniecp` → `excluirPorItem(int $idItem_balancete): bool` (apagam a linha do recibo e chamam `ReciboArquivo::remover($local)`).
- Produces:
  - `BancoTeste::abrir(Env $env): PDO` (FETCH_OBJ, como `Connect`; lança se o banco não for `sisconiecp_test`)
  - `BancoTeste::garantirBancoDeTeste(string $banco): void`
  - `BancoTeste::bancoDeOrigem(Env $env): string` (dbname de `GATE_LOCAL_DSN`)
  - `BancoTeste::clonar(PDO $pdo, string $origem, list<string> $tabelas): void` (`CREATE TEMPORARY TABLE t LIKE origem.t`)
  - `BancoTeste::linhaMinima(PDO $pdo, string $tabela, array<string, scalar> $valores): void` (preenche colunas NOT NULL sem default)
  - `BancoTeste::usarComoConexaoDoSistema(?PDO $pdo): ?PDO` (devolve a anterior)

Ruling do spec §6b: "valor negativo recusado", "dupla submissão" e "rollback multi-tabela" vivem em handlers procedurais (`incluirReceita.php`, `incluirDespesa.php`) sem classe que receba conexão; pelo próprio spec ("Onde a regra vive em handler procedural sem classe injetável, o teste correspondente vai para o grupo HTTP"), ficam para o Plano 2. "Campo cifrado sem texto puro" não se aplica: o schema local não tem colunas `*_enc` (a cifra em si é coberta por `CryptoTest`). Valores não positivos já gravados são vigiados por `item_valor_nao_positivo` (Task 1).

- [ ] **Step 1: Escrever os testes (RED)**

`tests/Unit/Integridade/BancoTesteTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Integridade;

use Classes\Connect;
use PDO;
use PHPUnit\Framework\TestCase;
use ReflectionProperty;
use RuntimeException;
use Tests\Support\Env;
use Tests\Support\Integridade\BancoTeste;

final class BancoTesteTest extends TestCase
{
    public function testRecusaBancoQueNaoEhDeTeste(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('conie847_sisconiecp');

        BancoTeste::garantirBancoDeTeste('conie847_sisconiecp');
    }

    public function testAceitaBancoDeTeste(): void
    {
        BancoTeste::garantirBancoDeTeste('sisconiecp_test');

        $this->addToAssertionCount(1);
    }

    public function testBancoDeOrigemVemDoDsnLocal(): void
    {
        $env = Env::deTexto('GATE_LOCAL_DSN=mysql:host=localhost;dbname=conie847_sisconiecp;charset=utf8mb4');

        $this->assertSame('conie847_sisconiecp', BancoTeste::bancoDeOrigem($env));
    }

    public function testClonarRecusaNomeSuspeito(): void
    {
        $this->expectException(RuntimeException::class);

        BancoTeste::clonar(new PDO('sqlite::memory:'), 'conie847_sisconiecp', ['login; DROP TABLE x']);
    }

    public function testTrocaERestauraConexaoDoSistema(): void
    {
        $propriedade = new ReflectionProperty(Connect::class, 'instance');
        $original = $propriedade->getValue();
        $falsa = new PDO('sqlite::memory:');

        $anterior = BancoTeste::usarComoConexaoDoSistema($falsa);
        $this->assertSame($falsa, $propriedade->getValue());

        BancoTeste::usarComoConexaoDoSistema($anterior);
        $this->assertSame($original, $propriedade->getValue());
    }
}
```

`tests/Integrity/Write/ReciboExclusaoTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Integrity\Write;

use PDO;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Support\Integridade\Ambiente;
use Tests\Support\Integridade\BancoTeste;

/**
 * Regressão de c061a5a1: excluir um item de balancete remove o recibo dele
 * (linha e arquivo), e só dele — nas três esferas.
 */
final class ReciboExclusaoTest extends TestCase
{
    private PDO $pdo;
    private ?PDO $conexaoAnterior = null;
    private string $pastaRecibos;
    /** @var list<string> */
    private array $arquivos = [];

    public static function setUpBeforeClass(): void
    {
        foreach (['Recibo_iecp', 'Recibo_congregacao', 'Recibo_coniecp'] as $classe) {
            require_once SISCONIECP_RAIZ . "/classes/{$classe}.class.php";
        }
    }

    public static function esferas(): array
    {
        return [
            'iecp' => ['Recibo_iecp', 'recibo_armazenado_iecp', ['idIecp' => 1]],
            'congregacao' => ['Recibo_congregacao', 'recibo_armazenado_congregacao', ['idIecp' => 1, 'idCongregacao' => 1]],
            'coniecp' => ['Recibo_coniecp', 'recibo_armazenado_coniecp', []],
        ];
    }

    protected function setUp(): void
    {
        $env = Ambiente::env();
        $this->pdo = BancoTeste::abrir($env);
        BancoTeste::clonar($this->pdo, BancoTeste::bancoDeOrigem($env), [
            'recibo_armazenado_iecp',
            'recibo_armazenado_congregacao',
            'recibo_armazenado_coniecp',
        ]);
        $this->conexaoAnterior = BancoTeste::usarComoConexaoDoSistema($this->pdo);
        $this->pastaRecibos = 'recibos/gate-teste-' . bin2hex(random_bytes(4));
        mkdir(SISCONIECP_RAIZ . '/iecp/tesouraria/balanceteMensal/' . $this->pastaRecibos, 0777, true);
    }

    protected function tearDown(): void
    {
        BancoTeste::usarComoConexaoDoSistema($this->conexaoAnterior);
        foreach ($this->arquivos as $arquivo) {
            @unlink($arquivo);
        }
        @rmdir(SISCONIECP_RAIZ . '/iecp/tesouraria/balanceteMensal/' . $this->pastaRecibos);
    }

    private function inserirRecibo(string $tabela, array $extra, int $idItem, bool $comArquivo): string
    {
        $local = $this->pastaRecibos . "/item-{$idItem}.webp";
        if ($comArquivo) {
            $absoluto = SISCONIECP_RAIZ . '/iecp/tesouraria/balanceteMensal/' . $local;
            file_put_contents($absoluto, 'x');
            $this->arquivos[] = $absoluto;
        }
        BancoTeste::linhaMinima($this->pdo, $tabela, $extra + [
            'idItem_balancete' => $idItem,
            'local' => $local,
            'data_recibo' => '2026-09-30',
            'cadastradoPor' => 1,
        ]);

        return SISCONIECP_RAIZ . '/iecp/tesouraria/balanceteMensal/' . $local;
    }

    /** @return list<int> */
    private function itensRestantes(string $tabela): array
    {
        return array_map('intval', $this->pdo->query("SELECT idItem_balancete FROM {$tabela} ORDER BY idItem_balancete")->fetchAll(PDO::FETCH_COLUMN));
    }

    #[DataProvider('esferas')]
    public function testExcluiSoOReciboDoItem(string $classe, string $tabela, array $extra): void
    {
        $arquivo901 = $this->inserirRecibo($tabela, $extra, 901, true);
        $this->inserirRecibo($tabela, $extra, 902, false);

        $this->assertTrue((new $classe())->excluirPorItem(901));

        $this->assertSame([902], $this->itensRestantes($tabela));
        $this->assertFileDoesNotExist($arquivo901);
    }

    #[DataProvider('esferas')]
    public function testItemSemReciboNaoMexeEmNada(string $classe, string $tabela, array $extra): void
    {
        $this->inserirRecibo($tabela, $extra, 901, false);

        $this->assertTrue((new $classe())->excluirPorItem(999));

        $this->assertSame([901], $this->itensRestantes($tabela));
    }
}
```

`tests/Integrity/Write/TextoUtf8Test.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Integrity\Write;

use PDO;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Tests\Support\Integridade\Ambiente;
use Tests\Support\Integridade\BancoTeste;

/** Texto colado do Word/TinyMCE precisa voltar do banco exatamente igual. */
final class TextoUtf8Test extends TestCase
{
    private const TEXTO = "<p>Ação “aspas” — travessão &ndash; 'simples' \"duplas\" 😀 中文 ç</p>";

    public static function colunas(): array
    {
        return [
            'oficio de IECP' => ['oficioiecp', 'texto', ['idIecp' => 1]],
            'portaria' => ['portaria', 'conteudo', []],
            'ministro' => ['cadastroministro', 'nome', []],
            'item de balancete' => ['itembalancete', 'descricao', ['valor' => 1]],
        ];
    }

    #[DataProvider('colunas')]
    public function testTextoVoltaIgual(string $tabela, string $coluna, array $extra): void
    {
        $env = Ambiente::env();
        $pdo = BancoTeste::abrir($env);
        $this->assertSame('utf8mb4', $pdo->query('SELECT @@character_set_connection')->fetchColumn(), 'SISCONIECP_TEST_DSN precisa de charset=utf8mb4');
        BancoTeste::clonar($pdo, BancoTeste::bancoDeOrigem($env), [$tabela]);

        BancoTeste::linhaMinima($pdo, $tabela, $extra + [$coluna => self::TEXTO]);

        $this->assertSame(self::TEXTO, $pdo->query("SELECT {$coluna} FROM {$tabela}")->fetchColumn());
    }
}
```

- [ ] **Step 2: Rodar e confirmar falha**

Run: `php vendor/bin/phpunit --testsuite unit --filter BancoTesteTest --colors=never`
Expected: erro `Class "Tests\Support\Integridade\BancoTeste" not found`.

- [ ] **Step 3: Implementar `tests/Support/Integridade/BancoTeste.php`**

```php
<?php

declare(strict_types=1);

namespace Tests\Support\Integridade;

use Classes\Connect;
use PDO;
use ReflectionProperty;
use RuntimeException;
use Tests\Support\Env;

/**
 * Banco descartável dos testes de escrita: só sisconiecp_test, só tabelas
 * TEMPORARY (somem ao fechar a conexão) clonadas da estrutura real.
 */
final class BancoTeste
{
    public static function abrir(Env $env): PDO
    {
        $pdo = new PDO(
            $env->exigir('SISCONIECP_TEST_DSN'),
            $env->exigir('SISCONIECP_TEST_DB_USER'),
            (string) $env->get('SISCONIECP_TEST_DB_PASSWORD'),
            // Mesmas opções de Classes\Connect: as classes de produção leem objetos.
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_OBJ,
                PDO::ATTR_CASE => PDO::CASE_NATURAL,
            ]
        );
        self::garantirBancoDeTeste((string) $pdo->query('SELECT DATABASE()')->fetchColumn());

        return $pdo;
    }

    public static function garantirBancoDeTeste(string $banco): void
    {
        if ($banco !== 'sisconiecp_test') {
            throw new RuntimeException("SISCONIECP_TEST_DSN aponta para '{$banco}'; testes de escrita só rodam em sisconiecp_test.");
        }
    }

    public static function bancoDeOrigem(Env $env): string
    {
        if (!preg_match('/(?:^|;)dbname=([^;]+)/i', $env->exigir('GATE_LOCAL_DSN'), $m)) {
            throw new RuntimeException('GATE_LOCAL_DSN sem dbname.');
        }

        return trim($m[1]);
    }

    /** @param list<string> $tabelas */
    public static function clonar(PDO $pdo, string $origem, array $tabelas): void
    {
        foreach ([$origem, ...$tabelas] as $nome) {
            if (!preg_match('/^\w+$/', $nome)) {
                throw new RuntimeException("Nome de banco/tabela inválido: {$nome}");
            }
        }
        foreach ($tabelas as $tabela) {
            $pdo->exec("DROP TEMPORARY TABLE IF EXISTS `{$tabela}`");
            $pdo->exec("CREATE TEMPORARY TABLE `{$tabela}` LIKE `{$origem}`.`{$tabela}`");
        }
    }

    /**
     * Insere uma linha preenchendo com valor neutro toda coluna NOT NULL sem
     * default que $valores não trouxe (a tabela é TEMPORARY).
     *
     * @param array<string, scalar> $valores
     */
    public static function linhaMinima(PDO $pdo, string $tabela, array $valores): void
    {
        if (!preg_match('/^\w+$/', $tabela)) {
            throw new RuntimeException("Tabela inválida: {$tabela}");
        }
        foreach ($pdo->query("SHOW COLUMNS FROM `{$tabela}`")->fetchAll(PDO::FETCH_ASSOC) as $coluna) {
            $nome = $coluna['Field'];
            if (
                array_key_exists($nome, $valores)
                || $coluna['Null'] === 'YES'
                || $coluna['Default'] !== null
                || str_contains($coluna['Extra'], 'auto_increment')
            ) {
                continue;
            }
            $tipo = strtolower($coluna['Type']);
            $valores[$nome] = match (true) {
                str_contains($tipo, 'int'), str_contains($tipo, 'decimal'), str_contains($tipo, 'float'), str_contains($tipo, 'double') => 0,
                str_starts_with($tipo, 'datetime'), str_starts_with($tipo, 'timestamp') => '2026-09-30 00:00:00',
                str_starts_with($tipo, 'date') => '2026-09-30',
                str_starts_with($tipo, 'year') => 2026,
                default => 'x',
            };
        }
        $colunas = array_keys($valores);
        $sql = sprintf(
            'INSERT INTO `%s` (`%s`) VALUES (%s)',
            $tabela,
            implode('`, `', $colunas),
            implode(', ', array_fill(0, count($colunas), '?'))
        );
        $pdo->prepare($sql)->execute(array_values($valores));
    }

    /** Troca a conexão usada pelas classes de produção; devolve a anterior para restaurar. */
    public static function usarComoConexaoDoSistema(?PDO $pdo): ?PDO
    {
        $propriedade = new ReflectionProperty(Connect::class, 'instance');
        $anterior = $propriedade->getValue();
        $propriedade->setValue(null, $pdo);

        return $anterior;
    }
}
```

- [ ] **Step 4: Rodar os testes unitários (GREEN)**

Run: `php vendor/bin/phpunit --testsuite unit --filter BancoTesteTest --colors=never`
Expected: `OK (5 tests, ...)`.

- [ ] **Step 5: Registrar a suíte e rodar**

Em `phpunit.xml`, depois de `integrity-read`:

```xml
        <testsuite name="integrity-write">
            <directory>tests/Integrity/Write</directory>
        </testsuite>
```

Run: `php vendor/bin/phpunit --testsuite integrity-write --colors=never`
Expected: `OK (10 tests, ...)`: 3 esferas × 2 testes de recibo + 4 colunas de texto. Se `TextoUtf8Test` falhar com "Incorrect string value", a coluna real não é `utf8mb4`: registre na allowlist com o nome da coluna e relate. Confira que não sobrou `recibos/gate-teste-*`: `ls iecp/tesouraria/balanceteMensal/recibos | grep gate-` vazio.

- [ ] **Step 6: Registrar a etapa no `gate.php`**

No array `$etapas`, depois de `'integrity-read'`:

```php
    'integrity-write' => new EtapaPhpUnit($raiz, 'integrity-write', $allowlist),
```

No array `$prefixos`, acrescentar:

```php
    'integrity-write' => 'Tests\\Integrity\\Write\\',
```

Run: `php tests/gate.php; echo "exit=$?"`
Expected: 6 etapas (`preflight`, `lint`, `unit`, `legado`, `integrity-read`, `integrity-write`), todas `PASSOU`, `APROVADO`, `exit=0`.

- [ ] **Step 7: Commit**

```bash
git add tests/Support/Integridade/BancoTeste.php tests/Unit/Integridade/BancoTesteTest.php tests/Integrity/Write/ phpunit.xml tests/gate.php
git commit -F <mensagem: "test: suíte integrity-write com recibos em cascata e texto UTF-8">
```

---

### Task 5: Documentação e relatório dos achados

**Files:**
- Modify: `tests/README.md`

**Interfaces:**
- Consumes: tudo acima.
- Produces: documentação.

- [ ] **Step 1: Acrescentar ao `tests/README.md`, antes de "## Falhas conhecidas"**

````markdown
## Integridade dos dados

- `integrity-read`: 44 checagens só-leitura no banco local (`tests/Support/Integridade/Checagens.php`)
  mais CPF inválido. A conexão recusa usuário com INSERT/UPDATE/DELETE/DROP/ALTER/FILE/SUPER/ALL e liga
  `READ ONLY` na sessão.
- `integrity-write`: exercita classes reais em tabelas `TEMPORARY` do `sisconiecp_test`, clonadas da
  estrutura do banco local. Nada é gravado no banco local.

### Linha de base (`tests/Integrity/baseline.json`)

Sujeira antiga aceita por checagem. A etapa reprova só quando uma contagem **aumenta**.
Depois de limpar dados, reduza o número à mão — senão a folga esconde regressões futuras
até o valor antigo. Checagem nova entra com 0 (não precisa estar no arquivo).
````

- [ ] **Step 2: Rodar o portão completo**

Run: `php tests/gate.php; echo "exit=$?"`
Expected: `APROVADO`, `exit=0`.

- [ ] **Step 3: Commit**

```bash
git add tests/README.md
git commit -F <mensagem: "docs: integridade dos dados e linha de base no README do portão">
```

- [ ] **Step 4: Relatar ao humano os achados de dados**

Listar a tabela da linha de base (Task 3, Step 4) com uma frase por item, destacando: o balancete de IECP #1 (06/2012) com total menor que os itens, nenhum balancete de IECP finalizado desde 2022, e as 1.046 matrículas de turma EBD órfãs. Nenhuma correção de dados neste plano.

---

## Cobertura do spec neste plano

| Spec §6 | Onde |
|---|---|
| 6a leitura, usuário só SELECT, zero linhas = íntegro, até 20 ids | Tasks 1, 3 |
| 6a órfãos, referências, contábil, unicidade, formato, autenticador | Task 1 (catálogo) |
| 6a linha de base, reprova só se aumentar | Tasks 1, 3 |
| 6b recibo excluído junto com o item (c061a5a1) | Task 4 |
| 6b texto com acento/emoji relido idêntico | Task 4 (+ checagem de charset na Task 1) |
| 6b valor negativo, dupla submissão, rollback | Plano 2 (HTTP), por regra do próprio spec — ruling na Task 4 |
| 6b campo cifrado sem texto puro | não aplicável ao schema local — ruling na Task 4 |
| §9 etapas no relatório do `gate.php` | Tasks 3, 4 |
