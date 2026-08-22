# Plano de Ação — Assinatura Eletrônica de Portarias Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tornar o fluxo de Portaria da CONIECP seguro no servidor, consistente em banco, imutável após a assinatura e auditável, preservando os documentos, URLs e contratos legados já existentes.

**Architecture:** a Portaria continuará usando `portaria` como fonte administrativa e `autenticador_doc` como documento público canônico. A ativação passará a ser uma operação de backend única: autentica o ator, confirma a senha, valida o assinador, gera o PDF a partir do snapshot aprovado, grava a assinatura e finaliza o PDF em transação. A consulta pública continuará servindo somente o PDF canônico cuja integridade SHA-256 foi verificada.

**Tech Stack:** PHP 8.4, PDO/MySQL, mPDF, chillerlan QRCode, jQuery/TinyMCE, WAMP e PowerShell.

## Global Constraints

- Preservar `tipo_doc = 'portaria'`, `id_tipo_doc = 1`, `emissor = 0` e a identidade lógica `(tipo_doc, emissor, id_doc)`.
- Não renomear rotas legadas nem campos HTML existentes sem manter compatibilidade.
- Usar `America/Sao_Paulo` para todas as datas e horários de ativação/finalização.
- Nunca salvar PDF enviado pelo verificador público; a comparação deve continuar usando apenas arquivo temporário.
- Usar prepared statements para toda entrada dinâmica de SQL.
- Não permitir alteração de conteúdo, número, data ou assinador de Portaria após `finalized_at` do documento correspondente.
- Não expor credenciais, códigos completos de documentos ou conteúdo de Portarias em logs públicos.
- Executar migrações em modo dry-run antes de qualquer alteração de dados legados.
- Toda confirmação que efetive uma assinatura eletrônica deve usar o padrão visual, responsivo e acessível definido na Task 7. Não criar modais alternativos por módulo nem reutilizar o chrome do jQuery UI para essa confirmação.

---

## Estrutura de arquivos e responsabilidades

| Arquivo | Responsabilidade após o plano |
| --- | --- |
| `classes/Portaria.class.php` | Repositório de Portaria com SQL parametrizado e métodos de leitura/escrita explícitos. |
| `classes/PortariaAssinaturaService.php` | Serviço de ativação: autorização, reautenticação, transação, auditoria e finalização. |
| `classes/PortariaPdfRenderer.php` | Gera bytes do PDF a partir de um snapshot imutável, sem escrever no banco. |
| `classes/AutenticadorDoc.class.php` | Mantém código público, identidade lógica e persistência do PDF canônico. |
| `classes/AssinaturaAuditoria.php` | Registra eventos de rascunho, ativação, rejeição, arquivamento e falha. |
| `coniecp/portaria/cadastrarPortariaAcao.php` | Controller POST autenticado; delega a regra ao serviço. |
| `coniecp/portaria/pdf/gerarPdfPortaria.php` | Controller administrativo de leitura/impressão; não finaliza mais documentos. |
| `coniecp/portaria/js/cadastrarPortaria.js` | Interface de rascunho/ativação com CSRF, senha e feedback claro. |
| `coniecp/portaria/js/consultarPortaria.js` | Interface de consulta/arquivamento sem depender de regras apenas visuais. |
| `sql/migrate_portaria_assinatura_20260808.php` | Cria auditoria, constraints e proteção de conteúdo finalizado. |
| `sql/verificar_portarias_legadas.php` | Diagnostica e regulariza, somente por comando explícito, Portarias ativas sem autenticador. |
| `tests/portaria/portaria_assinatura_test.php` | Verificação automatizada do serviço contra banco de testes transacional. |

## Contratos de serviço

```php
final class PortariaAssinaturaService
{
    /**
     * @param array{
     *   idPortaria?: int,
     *   embasamento: string,
     *   conteudo: string,
     *   dataPortaria: string,
     *   assinadoPor: int,
     *   acao: 'inserir'|'alterar',
     *   operacao: 'rascunho'|'ativar'|'arquivar',
     *   csrf: string,
     *   senhaConfirmacao?: string
     * } $entrada
     * @return array{idPortaria:int,status:string,numeroPortaria:string,codigoVerificacao?:string,finalizedAt?:string}
     */
    public function executar(array $entrada, int $rmAtor, string $nomeAtor): array;
}
```

Regras fixas do contrato:

- `rascunho` permite criar ou alterar apenas Portaria em `Em Elaboracao`.
- `ativar` exige senha válida do ator, CSRF válido, ator igual ao assinador e assinador pertencente à diretoria CONIECP ativa.
- `ativar` cria ou atualiza a identidade do autenticador somente se o PDF canônico ainda não existir; após finalizado, alterações são rejeitadas.
- `arquivar` não altera conteúdo ou assinatura; só é permitido quando a regra existente de sindicância autorizar.
- toda resposta de erro é JSON com `ok: false`, `codigo` estável e mensagem segura para a interface.

## Task 1: Estabelecer a base de testes e o diagnóstico reproduzível

**Files:**

- Create: `tests/portaria/portaria_assinatura_test.php`
- Create: `tests/portaria/README.md`
- Modify: `docs/superpowers/plans/2026-08-08-inventario-assinatura-eletronica.md`

**Interfaces:**

- Consumes: `SISCONIECP_TEST_DSN`, `SISCONIECP_TEST_DB_USER` e `SISCONIECP_TEST_DB_PASSWORD` definidos apenas no ambiente local de teste.
- Produces: script que termina com código `0` quando todos os cenários passam e não grava dados persistentes.

- [ ] **Step 1: Criar o bootstrap de banco de testes separado do banco operacional**

```php
$dsn = getenv('SISCONIECP_TEST_DSN');
if (!is_string($dsn) || $dsn === '') {
    fwrite(STDERR, "SISCONIECP_TEST_DSN não configurado.\n");
    exit(2);
}

$pdo = new PDO($dsn, (string) getenv('SISCONIECP_TEST_DB_USER'), (string) getenv('SISCONIECP_TEST_DB_PASSWORD'), [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);
$pdo->beginTransaction();
register_shutdown_function(static function () use ($pdo): void {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
});
```

- [ ] **Step 2: Escrever os cenários de aceitação antes da implementação**

```php
assertSame('rascunho', $service->executar($rascunhoValido, 101, 'Secretário')['status']);
assertThrows('ASSINADOR_DIVERGENTE', fn () => $service->executar($ativacaoComOutroRm, 101, 'Secretário'));
assertThrows('SENHA_INVALIDA', fn () => $service->executar($ativacaoSemSenhaValida, 200, 'Presidente'));
assertSame('Ativo', $service->executar($ativacaoValida, 200, 'Presidente')['status']);
assertThrows('PORTARIA_FINALIZADA', fn () => $service->executar($alteracaoAposAtivacao, 200, 'Presidente'));
```

- [ ] **Step 3: Executar o teste e registrar a falha inicial esperada**

Run: `php tests/portaria/portaria_assinatura_test.php`

Expected: falha porque `PortariaAssinaturaService` ainda não existe.

- [ ] **Step 4: Documentar como configurar o banco de teste e como executar cada cenário**

O `README.md` deve conter somente estes comandos, sem credenciais:

```powershell
$env:SISCONIECP_TEST_DSN = 'mysql:host=localhost;dbname=sisconiecp_test;charset=utf8mb4'
$env:SISCONIECP_TEST_DB_USER = 'usuario_local_de_teste'
$env:SISCONIECP_TEST_DB_PASSWORD = 'senha_local_de_teste'
php tests/portaria/portaria_assinatura_test.php
```

- [ ] **Step 5: Commit**

```powershell
git add tests/portaria docs/superpowers/plans/2026-08-08-inventario-assinatura-eletronica.md
git commit -m "test: add portaria signature acceptance harness"
```

### Task 2: Criar migração de integridade, auditoria e imutabilidade

**Files:**

- Create: `sql/migrate_portaria_assinatura_20260808.php`
- Create: `sql/verificar_portarias_legadas.php`
- Modify: `sql/migrate_autenticador_documentos_20260808.php`
- Test: `tests/portaria/portaria_assinatura_test.php`

**Interfaces:**

- Consumes: tabelas `portaria`, `autenticador_doc` e `sindicancia` existentes.
- Produces: tabela `portaria_assinatura_evento`, índice único de numeração e trigger de bloqueio de conteúdo finalizado.

- [ ] **Step 1: Criar a tabela de auditoria com dados mínimos e não sensíveis**

```sql
CREATE TABLE IF NOT EXISTS portaria_assinatura_evento (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_portaria INT NOT NULL,
    evento ENUM('RASCUNHO_CRIADO','RASCUNHO_ALTERADO','ATIVADA','ARQUIVADA','REJEITADA') NOT NULL,
    rm_ator INT NOT NULL,
    ip_hash CHAR(64) NULL,
    detalhe VARCHAR(255) NOT NULL,
    criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_portaria_evento (id_portaria, criado_em)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 2: Verificar duplicidades de numeração antes de criar o índice único**

```sql
SELECT numeroPortaria, COUNT(*) AS total
FROM portaria
GROUP BY numeroPortaria
HAVING COUNT(*) > 1;
```

Se a consulta retornar linhas, a migração deve encerrar com código `1` sem criar índice. Se retornar zero linhas, criar:

```sql
ALTER TABLE portaria
ADD UNIQUE KEY uq_portaria_numero (numeroPortaria);
```

- [ ] **Step 3: Criar trigger que bloqueia mudança de conteúdo quando o PDF canônico foi finalizado**

```sql
CREATE TRIGGER trg_portaria_bu_bloquear_conteudo_finalizado
BEFORE UPDATE ON portaria
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM autenticador_doc a
        WHERE a.tipo_doc = 'portaria'
          AND a.emissor = 0
          AND a.id_doc = OLD.idPortaria
          AND a.finalized_at IS NOT NULL
    ) AND (
        NOT (NEW.numeroPortaria <=> OLD.numeroPortaria)
        OR NOT (NEW.dataPortaria <=> OLD.dataPortaria)
        OR NOT (NEW.embasamento <=> OLD.embasamento)
        OR NOT (NEW.conteudo <=> OLD.conteudo)
        OR NOT (NEW.assinador <=> OLD.assinador)
        OR NOT (NEW.cargo_assinador <=> OLD.cargo_assinador)
        OR NOT (NEW.funcao_assinador <=> OLD.funcao_assinador)
        OR NOT (NEW.rm_assinador <=> OLD.rm_assinador)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Portaria finalizada não pode ter conteúdo ou assinatura alterados';
    END IF;
END;
```

- [ ] **Step 4: Implementar script de diagnóstico de legado em modo leitura por padrão**

```php
$sql = "SELECT p.idPortaria, p.numeroPortaria, p.statusPortaria
        FROM portaria p
        LEFT JOIN autenticador_doc a
          ON a.tipo_doc = 'portaria' AND a.emissor = 0 AND a.id_doc = p.idPortaria
        WHERE p.statusPortaria = 'Ativo' AND a.id IS NULL
        ORDER BY p.idPortaria";
```

O script deve aceitar apenas `--dry-run` e `--apply=<idPortaria>`. O modo `--apply` deve exigir `--confirmar=REGULARIZAR-PORTARIA-<id>` e criar um evento `REJEITADA` caso não exista conteúdo válido para a geração do PDF canônico.

- [ ] **Step 5: Executar a migração em dry-run e validar o bloqueio**

Run:

```powershell
php sql/migrate_portaria_assinatura_20260808.php --dry-run
php sql/verificar_portarias_legadas.php --dry-run
php tests/portaria/portaria_assinatura_test.php
```

Expected: nenhuma alteração em dados; uma tentativa de alterar conteúdo de Portaria finalizada falha com SQLSTATE `45000`.

- [ ] **Step 6: Commit**

```powershell
git add sql tests/portaria
git commit -m "feat: protect finalized portaria records"
```

### Task 3: Parametrizar persistência e validar dados de Portaria

**Files:**

- Modify: `classes/Portaria.class.php`
- Create: `classes/PortariaInputValidator.php`
- Test: `tests/portaria/portaria_assinatura_test.php`

**Interfaces:**

- Consumes: `PDO`, conteúdo HTML permitido e dados de Portaria recebidos por POST.
- Produces: `PortariaInputValidator::validar(array $entrada): array` e métodos de repositório que nunca concatenam entrada em SQL.

- [ ] **Step 1: Escrever os testes de rejeição para data, operação, RM e HTML inválidos**

```php
assertThrows('DATA_INVALIDA', fn () => $validator->validar(['dataPortaria' => '31/02/2026']));
assertThrows('ASSINADOR_INVALIDO', fn () => $validator->validar(['assinadoPor' => 0]));
assertThrows('CONTEUDO_VAZIO', fn () => $validator->validar(['conteudo' => '<p> </p>']));
assertSame('2026-08-08', $validator->validar($entradaValida)['dataPortaria']);
```

- [ ] **Step 2: Implementar a validação de entrada e a lista de HTML permitido**

```php
final class PortariaInputValidator
{
    public function validar(array $entrada): array
    {
        $data = DateTimeImmutable::createFromFormat('!Y-m-d', (string) ($entrada['dataPortaria'] ?? ''), new DateTimeZone('America/Sao_Paulo'));
        if (!$data || $data->format('Y-m-d') !== ($entrada['dataPortaria'] ?? '')) {
            throw new DomainException('DATA_INVALIDA');
        }

        $conteudo = trim((string) ($entrada['conteudo'] ?? ''));
        if (trim(strip_tags($conteudo)) === '') {
            throw new DomainException('CONTEUDO_VAZIO');
        }

        return [
            'dataPortaria' => $data->format('Y-m-d'),
            'embasamento' => $this->sanitizarHtml((string) ($entrada['embasamento'] ?? '')),
            'conteudo' => $this->sanitizarHtml($conteudo),
            'assinadoPor' => filter_var($entrada['assinadoPor'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]),
        ];
    }
}
```

Configurar HTMLPurifier para permitir somente `p`, `br`, `strong`, `em`, `u`, `ul`, `ol`, `li`, `span[style]`, `table`, `thead`, `tbody`, `tr`, `td` e `th`; negar URLs, imagens, scripts, eventos HTML e estilos com `url()`.

- [ ] **Step 3: Substituir SQL concatenado por statements preparados**

```php
$stmt = $pdo->prepare(
    'UPDATE portaria
     SET embasamento = :embasamento,
         conteudo = :conteudo,
         dataPortaria = :data_portaria,
         atualizadoPor = :atualizado_por,
         atualizadoEm = NOW()
     WHERE idPortaria = :id_portaria
       AND statusPortaria = :status_esperado'
);
$stmt->execute([
    ':embasamento' => $dados['embasamento'],
    ':conteudo' => $dados['conteudo'],
    ':data_portaria' => $dados['dataPortaria'],
    ':atualizado_por' => $nomeAtor,
    ':id_portaria' => $idPortaria,
    ':status_esperado' => 'Em Elaboracao',
]);
```

- [ ] **Step 4: Validar a ausência de concatenação de entrada em SQL**

Run:

```powershell
rg -n "\$_POST|\$this->.*SELECT|\$this->.*INSERT|\$this->.*UPDATE" classes/Portaria.class.php coniecp/portaria
php tests/portaria/portaria_assinatura_test.php
```

Expected: nenhuma variável de requisição ou propriedade interpolada em SQL; todos os testes passam.

- [ ] **Step 5: Commit**

```powershell
git add classes/Portaria.class.php classes/PortariaInputValidator.php tests/portaria
git commit -m "refactor: validate and parameterize portaria persistence"
```

### Task 4: Implementar autorização, CSRF e reautenticação no servidor

**Files:**

- Create: `classes/PortariaAssinaturaService.php`
- Create: `classes/AssinaturaAuditoria.php`
- Modify: `coniecp/portaria/cadastrarPortariaAcao.php`
- Modify: `checaSenha.php`
- Modify: `coniecp/portaria/cadastrarPortaria.php`
- Modify: `coniecp/portaria/consultarPortaria.php`
- Modify: `coniecp/portaria/js/cadastrarPortaria.js`
- Modify: `coniecp/portaria/js/consultarPortaria.js`
- Test: `tests/portaria/portaria_assinatura_test.php`

**Interfaces:**

- Consumes: sessão atual, token CSRF, senha do usuário atual, RM do assinador e diretoria CONIECP ativa.
- Produces: respostas JSON seguras e eventos de auditoria com `rm_ator`, tipo de evento e hash de IP.

- [ ] **Step 1: Incluir autenticação e autorização diretamente no controller de ação**

No início de `cadastrarPortariaAcao.php`:

```php
declare(strict_types=1);

require_once '../../valida_sessao_all.php';
require_once '../../validar_usuario_coniecp.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    http_response_code(405);
    responderJson(['ok' => false, 'codigo' => 'METODO_NAO_PERMITIDO']);
}
```

- [ ] **Step 2: Criar e validar token CSRF por sessão**

```php
if (empty($_SESSION['portaria_csrf'])) {
    $_SESSION['portaria_csrf'] = bin2hex(random_bytes(32));
}

function validarCsrf(string $token): void
{
    if (!hash_equals((string) ($_SESSION['portaria_csrf'] ?? ''), $token)) {
        throw new DomainException('CSRF_INVALIDO');
    }
}
```

As duas telas PHP devem incluir:

```php
<input type="hidden" id="portaria_csrf" value="<?= htmlspecialchars($_SESSION['portaria_csrf'], ENT_QUOTES, 'UTF-8') ?>" />
```

E os dois JavaScripts devem enviar `csrf: $('#portaria_csrf').val()`.

- [ ] **Step 3: Mover a verificação da senha para o mesmo POST de ativação**

```php
private function confirmarSenhaAtual(PDO $pdo, int $rmAtor, string $senha): void
{
    $stmt = $pdo->prepare('SELECT senha FROM login WHERE rm = :rm LIMIT 1');
    $stmt->execute([':rm' => $rmAtor]);
    $hash = $stmt->fetchColumn();

    if (!is_string($hash) || $senha === '' || !password_verify($senha, $hash)) {
        throw new DomainException('SENHA_INVALIDA');
    }
}
```

`checaSenha.php` pode permanecer apenas para feedback visual, mas a segurança será definida exclusivamente pela confirmação no serviço de ativação.

- [ ] **Step 4: Confirmar ator, assinador e diretoria no servidor**

```php
private function validarAssinadorAtivo(PDO $pdo, int $rmAtor, int $rmAssinador): array
{
    if ($rmAtor !== $rmAssinador) {
        throw new DomainException('ASSINADOR_DIVERGENTE');
    }

    $stmt = $pdo->prepare(
        'SELECT c.nome, cg.cargo, f.funcao
         FROM cadastroministro c
         JOIN cargo cg ON cg.idCargo = c.idCargo
         JOIN componente_diretoria_coniecp cdc ON cdc.rm = c.rm AND cdc.statusComp = 1
         JOIN funcao f ON f.idFuncao = cdc.idFuncao
         WHERE c.rm = :rm
         LIMIT 1'
    );
    $stmt->execute([':rm' => $rmAtor]);
    $assinador = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$assinador) {
        throw new DomainException('ASSINADOR_SEM_FUNCAO_ATIVA');
    }
    return $assinador;
}
```

- [ ] **Step 5: Testar bypass de navegador e CSRF**

Run:

```powershell
php tests/portaria/portaria_assinatura_test.php
```

Expected: POST sem sessão, sem CSRF, com RM diferente ou senha inválida retorna erro e não cria nem altera `portaria` ou `autenticador_doc`.

- [ ] **Step 6: Commit**

```powershell
git add classes/PortariaAssinaturaService.php classes/AssinaturaAuditoria.php checaSenha.php coniecp/portaria tests/portaria
git commit -m "feat: enforce server-side portaria signing authorization"
```

### Task 5: Finalizar o PDF durante a ativação e usar snapshot canônico

**Files:**

- Create: `classes/PortariaPdfRenderer.php`
- Modify: `classes/PortariaAssinaturaService.php`
- Modify: `coniecp/portaria/pdf/gerarPdfPortaria.php`
- Modify: `classes/AutenticadorDoc.class.php`
- Test: `tests/portaria/portaria_assinatura_test.php`

**Interfaces:**

- Consumes: snapshot validado de Portaria, dados institucionais e dados do assinador.
- Produces: `PortariaPdfRenderer::renderizar(array $portaria, array $coniecp, array $assinatura): array{nome:string,conteudo:string,sha256:string,tamanho:int}`.

- [ ] **Step 1: Escrever teste que exige PDF, SHA-256 e `finalized_at` após ativação**

```php
$resultado = $service->executar($ativacaoValida, 200, 'Presidente');
$doc = buscarAutenticador($pdo, $resultado['idPortaria']);
assertTrue(is_string($doc['doc_pdf']) && $doc['doc_pdf'] !== '');
assertSame(hash('sha256', $doc['doc_pdf']), $doc['pdf_sha256']);
assertTrue($doc['finalized_at'] !== null);
```

- [ ] **Step 2: Extrair o HTML do PDF do controller para um renderer sem acesso a `$_POST`**

```php
final class PortariaPdfRenderer
{
    public function renderizar(array $portaria, array $coniecp, array $assinatura): array
    {
        $codigo = $assinatura['numero_doc'];
        $url = rtrim((string) getenv('AUTENTICADOR_PUBLIC_URL'), '/') . '?hash=' . rawurlencode($codigo);
        $pdf = new Mpdf(['format' => 'A4', 'margin_left' => 20, 'margin_right' => 15, 'margin_top' => 50, 'margin_bottom' => 25]);
        // O HTML deve usar somente valores já sanitizados ou escapados pelo renderer.
        $conteudo = $pdf->Output('', 'S');

        return [
            'nome' => 'Portaria_n_' . str_replace('/', '_', $portaria['numeroPortaria']) . '.pdf',
            'conteudo' => $conteudo,
            'sha256' => hash('sha256', $conteudo),
            'tamanho' => strlen($conteudo),
        ];
    }
}
```

- [ ] **Step 3: Executar criação, assinatura e finalização em uma transação de domínio**

```php
$this->pdo->beginTransaction();
try {
    $portaria = $this->portarias->criarOuAtualizarRascunho($dados, $nomeAtor);
    $assinatura = $this->autenticador->obterOuPreparar('portaria', 0, $portaria['idPortaria'], $assinador);
    $pdf = $this->renderer->renderizar($portaria, $this->dadosConiecp(), $assinatura);
    $this->autenticador->finalizarPdf($assinatura['id'], $pdf);
    $this->portarias->marcarAtiva($portaria['idPortaria'], $assinador, $nomeAtor);
    $this->auditoria->registrar($portaria['idPortaria'], 'ATIVADA', $rmAtor, 'PDF finalizado');
    $this->pdo->commit();
} catch (Throwable $e) {
    if ($this->pdo->inTransaction()) {
        $this->pdo->rollBack();
    }
    throw $e;
}
```

- [ ] **Step 4: Tornar o endpoint de PDF administrativo somente de leitura**

`gerarPdfPortaria.php` deve exigir sessão/nível CONIECP, validar `idPortaria` com `FILTER_VALIDATE_INT`, buscar exclusivamente `doc_pdf` finalizado e retornar `404` quando o PDF não existir. Ele não deve gerar ou gravar um novo PDF.

- [ ] **Step 5: Testar atomicidade e imutabilidade**

Run:

```powershell
php tests/portaria/portaria_assinatura_test.php
```

Expected: falha simulada na finalização não deixa Portaria ativa; ativação válida cria um único registro autenticador com PDF, SHA-256, tamanho e data de finalização.

- [ ] **Step 6: Commit**

```powershell
git add classes/PortariaPdfRenderer.php classes/PortariaAssinaturaService.php classes/AutenticadorDoc.class.php coniecp/portaria/pdf tests/portaria
git commit -m "feat: finalize canonical portaria PDF on activation"
```

### Task 6: Proteger a consulta pública, o PDF e os dados exibidos

**Files:**

- Modify: `coniecp/portaria/pdf/gerarPdfPortaria.php`
- Modify: `coniecp/portaria/consultarPortaria.php`
- Modify: `coniecp/portaria/listarPortariaAcao.php`
- Modify: `coniecp/portaria/dadosPortaria.php`
- Modify: `autenticador/aut.php`
- Modify: `autenticador/rate_limit.php`
- Modify: `classes/Connect.php`
- Test: `tests/portaria/portaria_assinatura_test.php`

**Interfaces:**

- Consumes: PDF canônico finalizado e código público de 12 caracteres.
- Produces: resposta pública com PDF íntegro, respostas administrativas sem XSS e configurações sem segredo no código.

- [ ] **Step 1: Escapar saída HTML administrativa por contexto**

```php
function e(string $valor): string
{
    return htmlspecialchars($valor, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

// Para mostrar conteúdo de TinyMCE aprovado, use o HTML já sanitizado.
// Para atributos, números, nomes e rótulos, use e($valor).
```

Em campos `textarea`, usar `e($conteudo)`. Na listagem, renderizar o HTML sanitizado em contêiner controlado, nunca conteúdo bruto vindo diretamente do banco.

- [ ] **Step 2: Remover SQL concatenado restante do PDF e validar ID antes da consulta**

```php
$idPortaria = filter_input(INPUT_POST, 'idPortaria', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
if (!$idPortaria) {
    http_response_code(400);
    exit('Portaria inválida.');
}

$stmt = $pdo->prepare(
    'SELECT doc_pdf, nome_doc
     FROM autenticador_doc
     WHERE tipo_doc = :tipo_doc AND emissor = 0 AND id_doc = :id_doc
       AND finalized_at IS NOT NULL
     LIMIT 1'
);
$stmt->execute([':tipo_doc' => 'portaria', ':id_doc' => $idPortaria]);
```

- [ ] **Step 3: Configurar segredo de rate limiting e conexão fora do código-fonte**

Substituir constantes de credenciais em `Connect` por variáveis de ambiente exigidas:

```php
$host = getenv('SISCONIECP_DB_HOST');
$database = getenv('SISCONIECP_DB_NAME');
$user = getenv('SISCONIECP_DB_USER');
$password = getenv('SISCONIECP_DB_PASSWORD');
if (!is_string($host) || !is_string($database) || !is_string($user) || !is_string($password)) {
    throw new RuntimeException('Configuração de banco indisponível.');
}
```

`AUTENTICADOR_RATE_SECRET` e `AUTENTICADOR_PUBLIC_URL` devem ser obrigatórios em produção; a aplicação deve recusar inicialização pública se estiverem ausentes.

- [ ] **Step 4: Testar integridade, headers e exposição direta**

Run:

```powershell
php tests/portaria/portaria_assinatura_test.php
curl.exe -i -X POST --data-urlencode "hash=CODIGO_VALIDO_DE_TESTE" http://localhost/sisconiecp2/autenticador/aut.php
```

Expected: `Content-Type: application/pdf`, `X-Content-Type-Options: nosniff`, hash válido e nenhuma URL administrativa sem sessão entrega PDF ou permite alteração.

- [ ] **Step 5: Commit**

```powershell
git add classes/Connect.php autenticador coniecp/portaria tests/portaria
git commit -m "security: harden portaria output and configuration"
```

### Task 7: Corrigir UX e acessibilidade do fluxo de assinatura

**Files:**

- Modify: `coniecp/portaria/cadastrarPortaria.php`
- Modify: `coniecp/portaria/consultarPortaria.php`
- Create: `coniecp/portaria/css/portaria-layout.css`
- Modify: `coniecp/portaria/js/cadastrarPortaria.js`
- Modify: `coniecp/portaria/js/consultarPortaria.js`
- Modify: `coniecp/portaria/css/cadastrarPortaria.css`
- Modify: `coniecp/portaria/css/consultarPortaria.css`
- Create: `docs/portaria-padrao-visual.md`
- Test: `tests/portaria/portaria_layout_test.php` e manual no WAMP em 375 px, 768 px, 1024 px e 1440 px.

**Interfaces:**

- Consumes: respostas JSON do controller e estados `Em Elaboracao`, `Ativo` e `Arquivado`.
- Produces: confirmação de assinatura clara, mensagens acionáveis e interface responsiva sem depender de JavaScript para segurança.

#### Padrão global obrigatório de confirmação de assinatura

O modal implementado em Portaria passa a ser o padrão de confirmação de assinatura eletrônica para **todos os pontos da aplicação em que uma assinatura for confirmada**, incluindo Portaria, Edital, Ofício, Notificação, Circular e novos tipos documentais adicionados ao serviço.

Regras obrigatórias de adoção:

- usar um overlay e um contêiner controlados pela aplicação, sem barra de título, botões ou dimensões gerados pelo jQuery UI;
- preservar a mesma hierarquia visual aprovada: ícone de segurança, título, subtítulo, texto explicativo, senha com alternância de visibilidade, informação de ambiente seguro e rodapé com `Cancelar` e `Autorizar assinatura`;
- reutilizar o mesmo markup, CSS e controlador JavaScript compartilhados; diferenças entre módulos devem ficar somente no adaptador que chama a ação de assinatura existente;
- manter `role="dialog"`, `aria-modal="true"`, título e descrição associados, foco inicial no campo, foco cíclico, retorno do foco ao acionador e fechamento por `Esc` somente quando não houver processamento;
- bloquear senha, alternância de visibilidade, fechar, cancelar e autorizar durante o envio; impedir submissões duplicadas e conservar os mesmos estados vazio, foco, carregamento, erro e sucesso;
- não incluir seleção de signatário no modal e não alterar autenticação, autorização, CSRF, endpoint, payload, regras de negócio ou identificação do ator já existentes em cada fluxo;
- qualquer tela com confirmação de assinatura que ainda use `dialog()` do jQuery UI ou outro modal visual deve ser migrada para este padrão antes de ser considerada aderente ao plano.

Contrato responsivo do componente:

- de 320 px a 479 px: margens externas mínimas, título e textos com quebra natural, ações em uma coluna e nenhuma rolagem horizontal;
- de 480 px a 767.98 px: modal fluido, ações empilhadas e áreas clicáveis mínimas de 44 px;
- a partir de 768 px: modal centralizado com largura de 720 px e ações distribuídas nas extremidades do rodapé;
- em telas com pouca altura, inclusive celular em paisagem: altura limitada pelo viewport dinâmico, rolagem interna e ações sempre alcançáveis;
- em telas grandes e ultrawide: manter a largura máxima de 720 px para preservar legibilidade e hierarquia;
- com zoom de até 200%, texto ampliado e preferência por movimento reduzido: nenhum conteúdo, mensagem ou ação pode ser cortado ou ficar inacessível.

- [ ] **Step 1: Corrigir validações e callbacks JavaScript**

```js
if (conteudoPortaria.trim() === '' || conteudoPortaria.length < 10) {
  mostrarErro('Informe o texto da Portaria com pelo menos 10 caracteres.');
  return;
}

$.ajax({
  url: 'coniecp/portaria/cadastrarPortariaAcao.php',
  method: 'POST',
  dataType: 'json',
  data: payload,
  beforeSend() { bloquearFormulario(true); },
  complete() { bloquearFormulario(false); },
});
```

- [ ] **Step 2: Enviar a senha somente no POST de ativação e limpar imediatamente o campo**

```js
payload.senhaConfirmacao = $('#senha').val();
try {
  await enviarAtivacao(payload);
} finally {
  $('#senha').val('');
  delete payload.senhaConfirmacao;
}
```

- [ ] **Step 3: Tornar o estado visível e compreensível**

Exibir uma faixa com uma destas mensagens:

```text
Rascunho: pode ser alterado antes da ativação.
Ativa e finalizada: o PDF canônico foi assinado e não pode ser alterado.
Arquivada: permanece consultável, mas não aceita conteúdo novo.
```

Após ativação, mostrar número da Portaria, data/hora de finalização e botão para abrir o PDF canônico. Não exibir o código completo em logs ou mensagens que possam ser compartilhadas inadvertidamente.

- [ ] **Step 4: Validar responsividade e teclado**

Checklist manual:

- foco visível em campos, botões e diálogo;
- `label for` associado a cada campo;
- nenhuma largura fixa excede viewport de 320 px;
- diálogo de senha pode ser fechado com `Esc`;
- mensagens usam `role="alert"`;
- modal permanece utilizável em orientação paisagem e viewport com 568 px de altura;
- conteúdo e ações continuam alcançáveis com zoom de 200%;
- PDF abre em nova aba sem perder o rascunho.

#### Registro de layout responsivo — 09/08/2026

Implementado o padrão compartilhado em `cadastrarPortaria` e `consultarPortaria`:

- menu `col-12 col-md-1 p-0 menu_sistema` e conteúdo `col-12 col-sm-11 col-md-10`;
- cards com 16 px de intervalo, campos em uma coluna no conteúdo e assinatura/auditoria em grade;
- ações alinhadas à borda direita dos cards em desktop; em até `767.98px`, ações, assinatura, metadados e auditoria passam para uma coluna;
- o botão de PDF dinâmico continua usando a classe legada `.div_button`.

Evidência local concluída:

```powershell
php -l coniecp/portaria/cadastrarPortaria.php
php -l coniecp/portaria/consultarPortaria.php
php tests/portaria/portaria_layout_test.php
node --check coniecp/portaria/js/cadastrarPortaria.js
node --check coniecp/portaria/js/consultarPortaria.js
git diff --check
```

| Largura | Resultado exigido | Situação em 09/08/2026 |
| --- | --- | --- |
| 320 px | modal sem rolagem horizontal; título quebra naturalmente; ações ocupam toda a largura útil | Pendente de inspeção autenticada no WAMP |
| 375 px | menu e conteúdo empilhados; cards e botões sem rolagem horizontal | Pendente de inspeção autenticada no WAMP |
| 768 px | grade institucional de menu/conteúdo; assinatura em duas colunas | Pendente de inspeção autenticada no WAMP |
| 1024 px | cards com largura útil e ações na borda direita | Pendente de inspeção autenticada no WAMP |
| 1440 px | largura máxima de 1200 px; cards, auditoria e ações alinhados | Pendente de inspeção autenticada no WAMP |
| altura 568 px | modal com rolagem interna e rodapé alcançável sem corte | Pendente de inspeção autenticada no WAMP |

A automação local via `npx --package @playwright/cli playwright-cli --help` excedeu 15 segundos antes de iniciar. Não há sessão administrativa autorizada disponível para substituir essa inspeção por captura autenticada. Portanto, a responsividade foi verificada por regras CSS e contrato estrutural; a confirmação visual em navegador permanece pendente.

- [ ] **Step 5: Commit**

```powershell
git add coniecp/portaria
git commit -m "fix: improve portaria signing UX and accessibility"
```

### Task 8: Regularizar Portarias ativas legadas de forma controlada

**Files:**

- Modify: `sql/verificar_portarias_legadas.php`
- Create: `docs/operacao/regularizacao-portarias-legadas.md`
- Test: banco de teste e execução dry-run local.

**Interfaces:**

- Consumes: Portarias `Ativo` sem registro em `autenticador_doc`.
- Produces: relatório antes/depois, PDF canônico somente quando a Portaria for confirmada por operador autorizado.

- [ ] **Step 1: Gerar relatório de candidatos sem gravar dados**

Run:

```powershell
php sql/verificar_portarias_legadas.php --dry-run
```

O relatório deve mostrar apenas ID, número, data, status, existência de autenticador e existência de PDF. Não mostrar conteúdo da Portaria ou dados pessoais do assinador.

- [ ] **Step 2: Exigir confirmação individual e informar a origem do assinador**

Para cada Portaria, a documentação deve exigir:

```text
1. Conferir o texto administrativo contra o documento institucional aprovado.
2. Definir o assinador histórico ou declarar que a assinatura eletrônica será emitida na data de regularização.
3. Gerar o PDF canônico.
4. Conferir manualmente QR Code, número e digest.
5. Executar --apply=<id> com --confirmar=REGULARIZAR-PORTARIA-<id>.
```

- [ ] **Step 3: Executar primeiro no banco de teste e validar o resultado**

Run:

```powershell
php sql/verificar_portarias_legadas.php --apply=18 --confirmar=REGULARIZAR-PORTARIA-18
php tests/portaria/portaria_assinatura_test.php
```

Expected: uma única identidade `portaria/0/18`, PDF finalizado, SHA-256 correspondente e evento `ATIVADA` ou `REJEITADA` explicando o resultado.

- [ ] **Step 4: Executar em produção somente após backup e autorização explícita**

Antes do comando real, registrar backup do banco e a lista de IDs aprovados. Não executar regularização em lote.

- [ ] **Step 5: Commit**

```powershell
git add sql/verificar_portarias_legadas.php docs/operacao/regularizacao-portarias-legadas.md
git commit -m "docs: add safe legacy portaria regularization flow"
```

### Task 9: Validar o fluxo completo e preparar expansão para os demais documentos

**Files:**

- Modify: `docs/superpowers/plans/2026-08-08-inventario-assinatura-eletronica.md`
- Create: `docs/operacao/checklist-validacao-portaria.md`
- Test: `tests/portaria/portaria_assinatura_test.php`

**Interfaces:**

- Consumes: fluxo final de Portaria e endpoints públicos do autenticador.
- Produces: checklist de regressão reutilizável por Edital, Ofício, Notificação e Circular.

- [ ] **Step 1: Executar a suíte e as verificações estáticas**

Run:

```powershell
php tests/portaria/portaria_assinatura_test.php
php -l classes/Portaria.class.php
php -l classes/PortariaAssinaturaService.php
php -l classes/PortariaPdfRenderer.php
php -l coniecp/portaria/cadastrarPortariaAcao.php
php -l coniecp/portaria/pdf/gerarPdfPortaria.php
node --check coniecp/portaria/js/cadastrarPortaria.js
node --check coniecp/portaria/js/consultarPortaria.js
git diff --check
```

- [ ] **Step 2: Executar o roteiro manual completo no WAMP**

```text
1. Criar rascunho e confirmar que não há autenticador nem PDF canônico.
2. Tentar ativar com outro RM, senha incorreta e CSRF inválido; todas as tentativas devem falhar sem alterar dados.
3. Ativar com o assinador autorizado e senha correta.
4. Abrir o PDF administrativo e confirmar QR Code, assinador, data e código.
5. Consultar o QR Code na página pública e confirmar abertura do mesmo PDF.
6. Comparar o PDF original e confirmar “idêntico”.
7. Alterar um byte do PDF e confirmar “diferente”.
8. Tentar editar conteúdo da Portaria finalizada e confirmar rejeição.
9. Arquivar a Portaria e confirmar que o PDF público continua íntegro.
```

- [ ] **Step 3: Atualizar o inventário e o checklist de expansão**

O inventário deve marcar Portaria como referência endurecida somente depois de todas as verificações anteriores. O checklist deve exigir que cada novo tipo documental reutilize `PortariaAssinaturaService` ou extraia uma abstração equivalente sem duplicar a lógica de autorização, finalização e auditoria. Toda expansão também deve reutilizar integralmente o padrão global de modal definido na Task 7; uma implementação com confirmação visual própria, `dialog()` do jQuery UI ou comportamento responsivo divergente não atende ao plano.

- [ ] **Step 4: Commit**

```powershell
git add docs/superpowers/plans docs/operacao tests/portaria
git commit -m "docs: record validated portaria signing baseline"
```

## Ações operacionais obrigatórias fora do código

1. Criar usuário de banco exclusivo para a aplicação, com privilégios mínimos e sem permissões administrativas globais.
2. Mover `SISCONIECP_DB_*`, `AUTENTICADOR_RATE_SECRET` e `AUTENTICADOR_PUBLIC_URL` para configuração fora do repositório e fora da raiz pública.
3. Rotacionar as credenciais atualmente presentes no histórico/local de `classes/Connect.php` antes da publicação desta mudança.
4. Configurar `upload_max_filesize`, `post_max_size`, `max_file_uploads`, timeout, memória e limite de concorrência no WAMP/Apache coerentes com o limite de 5 MB do endpoint de comparação.
5. Confirmar o IP real atrás de proxy reverso antes de confiar em `REMOTE_ADDR`; se houver proxy, configurar a camada web para aceitar cabeçalho de encaminhamento somente do proxy confiável.
6. Definir, com responsável jurídico e administrativo, a política de assinatura eletrônica interna, arquivamento, cancelamento e regularização de documentos legados.

## Auto-revisão do plano

Cobertura da auditoria:

- autorização server-side, senha vinculada à ativação e CSRF: Task 4;
- SQL Injection e validação de entradas: Task 3 e Task 6;
- imutabilidade, PDF canônico, SHA-256 e transação: Task 2 e Task 5;
- numeração concorrente e auditoria: Task 2 e Task 4;
- XSS, exposição direta e configuração sensível: Task 6;
- UX, responsividade e acessibilidade: Task 7;
- Portaria ativa legada sem autenticador: Task 8;
- validação final e uso como base para outros documentos: Task 9;
- credenciais, infraestrutura e política institucional: ações operacionais obrigatórias.

Verificação de consistência: todas as tarefas usam os mesmos estados `Em Elaboracao`, `Ativo`, `Arquivado`, a mesma identidade `portaria/0/idPortaria` e o mesmo serviço `PortariaAssinaturaService::executar()`.
