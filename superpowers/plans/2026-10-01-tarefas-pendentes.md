# Tarefas pendentes — 2026-10-01

Ordem sugerida: 1 → 2 → 3 → 5 → 6 (4 quando der). O item 1 vem primeiro porque protege produção agora.

## 1. Corrigir falhas de produção (código do sistema)

**1.1 `meus-dados/salvarDadosAcao.php`**
- Exigir login (`valida_sessao_all.php` + `validar_usuario_usuario.php` no topo).
- Usar o `rm` da sessão (`$_SESSION['rm']`), nunca o do POST.
- Pronto quando: sem login a página recusa; logado, só altera os próprios dados.

**1.2 `iecp/membro/ficha-Membro/listarPunicao.php`**
- Exigir login de IECP (`valida_sessao_all.php` + `validar_usuario_iecp.php`) e validar token CSRF.
- Trocar o SQL concatenado por prepared statement.
- Remover a credencial do MySQL escrita no arquivo; usar `Classes\Connect`.
- Trocar a senha do usuário `conie847_ribamar` no MySQL (ficou exposta no código).

**1.3 `iecp/notificacao/pdf/gerarPdf.php`**
- Incluir as guardas de sessão e de área no topo.

**1.4 `painel.php`**
- Ele inclui arquivos que o `.htaccess` bloqueia (`backup/`, `_old`, `_copia`). Escolher:
  - recusar esses caminhos no próprio `painel.php`; ou
  - apagar do servidor e do repositório os `_old`, `_copia` e `backup/` que restam.

## 2. Limpar o disco antes do próximo upload

Apagar do disco do projeto (não estão no git, mas sobem no upload manual):
- `script/DataTables-1.9.0/examples/examples_support/editable_ajax.php`
- `script/DataTables-1.9.0/examples/server_side/scripts/post.php`
- `script/multifile-master/test/test.php`

Conferir se existem no HostGator e apagar lá também.

## 3. Corrigir o catálogo do portão (`tests/Support/Http/Catalogo.php`)

Local: worktree `C:\wamp64\www\sisconiecp2-portao2a`, branch `testes/portao-2a-http` (commits `2638298`, `0d534ca`; ledger em `.superpowers/sdd/2026-10-01-portao-2a-http/progress.md`). Para cada item, escrever antes um teste que falhe.

1. Considerar `$_REQUEST` como recebimento de dados.
2. Guarda de sessão só conta se for: include `valida_sessao*`/`validar_usuario*`; `http_response_code(401)`; ou `if` que testa sessão **ausente** (`empty($_SESSION…)` / `!isset($_SESSION…)`) e responde 403/redirect. O 403 de falha de CSRF não conta.
3. Ampliar os métodos que gravam (`encerrar`, `devolver`, `ativar`, `enviar`…) ou gerar a lista a partir dos métodos de `classes/` com INSERT/UPDATE/DELETE.
4. Manter no catálogo os arquivos bloqueados pelo `.htaccess` mas alcançáveis pelo `painel.php`; tirar `classes/` das exclusões.
5. Remover comentários (`token_get_all`) antes de classificar.
6. Rotas públicas isentas só da guarda de sessão, não do CSRF; listar `csp-report.php` na lista de base.

Depois: gerar de novo `tests/Http/conhecidos.json`, rodar `php tests/gate.php --suite=unit`, commitar.
Pronto quando: unit verde e a lista contém ao menos `listarPunicao.php`, `salvarDadosAcao.php`, `notificacao/pdf/gerarPdf.php`, `ebd/professor/encerrarFuncao.php` (se ainda não corrigidos no item 1).

## 4. Ajustes menores no portão (opcional)

- `HttpClient`: restringir protocolo a http/https e ignorar proxy do ambiente.
- `CatalogoTest::tearDown`: checar se a pasta existe antes de apagar.
- `phpunit.xml`: avaliar `failOnDeprecation` e `failOnNotice`.

## 5. Escrever as Tasks 3–8 do Plano 2a

Arquivo: `docs/superpowers/plans/2026-10-01-portao-2a-http.md`, seção "Pendente".
- Task 3: contas e entidades `TESTE_GATE` + limpeza.
- Task 4: etapa `http` no portão (fazer `mysqldump` antes da 1ª execução).
- Tasks 5–7: autenticação, autorização/IDOR, CSRF dinâmico (só lista curada).
- Task 8: rodar o portão, registrar falhas conhecidas, README.

## 6. Fechar o branch

- Depois dos itens 3 e 5: merge de `testes/portao-2a-http` na `main` e remover o worktree.
- Decidir a mudança pendente em `coniecp/tesouraria/balanceteMensal/pdf/balanceteMensalPDF.php` no tree principal (frente `fix/anexos-oficio`): commitar ou descartar.
