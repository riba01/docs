# Correção de segurança — auditoria de 2026-10-07

**Status:** aprovado para execução por fases · **Autor:** auditoria assistida (Claude) · **Data:** 2026-10-07

> Documento interno e sensível. Descreve falhas exploráveis em produção. Não colar trechos em canais públicos, chamados de suporte ou IA de terceiros. Nenhuma senha real é reproduzida aqui.

## 1. Contexto

Auditoria só-leitura em cinco frentes (autenticação/sessão, SQL injection, upload/arquivos/RCE, controle de acesso/IDOR, XSS/CSRF/exposição). Os achados críticos foram conferidos no código e, quando possível, em produção (`https://swga.coniecp.com.br/`, raiz do domínio) com requisições `HEAD`/`GET` de leitura — nenhum upload ou escrita foi feito.

### 1.1 Evidência em produção (2026-10-07)

| Requisição sem cookie | Resposta | Conclusão |
|---|---|---|
| `GET /painel.php?pagina=index` | 200, tela de login completa | `painel.php` inclui qualquer `.php` sem exigir sessão |
| `HEAD /iecp/membro/ficha-Membro/documentos/110/` | 403 | pasta de documentos existe no servidor |
| `HEAD /iecp/membro/ficha-Membro/documentos/110/CPF%20MIRIAM.pdf` | 200 `application/pdf` | documento pessoal público (LGPD) |
| `HEAD /iecp/membro/ficha-Membro/insereAnexo.php` | 500 | direto quebra; via `painel.php?pagina=` funciona |
| `HEAD /tests/`, `/config/database.local.php` | 403 | bloqueios do `.htaccess` funcionam para acesso direto |

### 1.2 Causa-raiz

`painel.php` (linhas 63–130) valida só o formato do caminho e faz `require` de qualquer `.php` dentro de `BASE_PATH`. Não exige sessão. Consequências:

- ~184 arquivos que abrem o banco e não chamam validador viram endpoints anônimos;
- os bloqueios do `.htaccess` por URI (`/backup/`, `_old.php`, `classes/`) são contornados, porque a URI vista é só `/painel.php`;
- os `require "./classes/..."` relativos dos `*Acao.php` passam a funcionar (o diretório de trabalho é a raiz).

Somam-se: validadores sem `exit` após `header()`, `Connect.php` permitindo múltiplas instruções por consulta, e senhas reais versionadas.

## 2. Objetivos e não-objetivos

**Objetivos**
1. Eliminar acesso anônimo a qualquer endpoint que leia ou grave dados.
2. Eliminar execução de código via upload.
3. Tirar credenciais do código e do repositório; trocar as expostas.
4. Fechar SQL injection, IDOR e escalada entre perfis conhecidos.
5. Cobrir cada correção com teste no portão pré-deploy (`tests/gate.php`).

**Não-objetivos (nesta spec)**
- Remover `'unsafe-inline'` da CSP (segue o plano próprio, ver memória CSP).
- Reescrever módulos legados inteiros; legado sem uso é **apagado**, não corrigido.
- CSRF universal em todos os 90 handlers — entra como fase posterior (o cookie `SameSite=Strict` reduz o risco cross-site; ver Fase 8).

## 3. Fases

Ordem obrigatória: **Fase 0 antes de qualquer código.** Fases 1–2 no mesmo deploy. As demais podem ir em deploys separados, nesta ordem.

---

### Fase 0 — Contenção no servidor (manual, cPanel, hoje)

Executada pelo usuário no Gerenciador de Arquivos / cPanel. Não depende de código novo.

| # | Ação | Efeito colateral |
|---|---|---|
| 0.1 | Renomear `iecp/membro/ficha-Membro/insereAnexo.php` → `insereAnexo.php.off` | envio de documento para nas 3 telas até a Fase 2 |
| 0.2 | Criar `iecp/membro/ficha-Membro/documentos/.htaccess` com `Require all denied` | links "ver documento" param até o `serve.php` da Fase 2 |
| 0.3 | Renomear/apagar `coniecp/usuario/cadastrarUsuarioAcao.php` (legado; troca senha de qualquer conta sem login) | nenhum — JS atual usa `meus-dados/cadastrarUsuarioAcao.php` |
| 0.4 | Apagar `iecp/membro/ficha-Membro/listarPunicao.php`, `listarSit.php`, `listarCargo.php`, `listarDisc.php`, `listarFuncao.php` (mysqli com senha fixa, SQLi, `DELETE` por GET) | conferir se a ficha de membro usa; se usar, desativar só a aba |
| 0.5 | Apagar `coniecp/credencial/pasta morta/`, pastas `Backup/`/`bkp/` dentro de módulos, e `config.php` da raiz **se existir** | nenhum (código morto) |
| 0.6 | Trocar senha do usuário de banco `conie847_ribamar` (cPanel → MySQL) e atualizar `config/database.local.php` **no servidor** | sistema fora do ar segundos entre a troca e o upload |
| 0.7 | Trocar senha da conta SMTP `swga@coniecp.com.br` e atualizar `config/smtp.php` no servidor | e-mails de redefinição falham até a Fase 4 ler do config (hoje a senha está fixa em 4 arquivos) — **fazer 0.7 junto com o deploy da Fase 4** ou atualizar os 4 arquivos |
| 0.8 | Se a senha do cPanel/e-mail principal for igual ou derivada das vazadas, trocar também | — |

**0.9 — Verificação de intrusão (checklist)**
- [ ] Em `iecp/membro/ficha-Membro/documentos/**`: listar arquivos que não sejam `.pdf` nem `index.php`.
- [ ] Na raiz e em `iecp/`, `coniecp/`, `congregacao/`, `ebd/`: `.php` com data de modificação desconhecida (ordenar por data no Gerenciador de Arquivos).
- [ ] cPanel → Métricas → Acesso Bruto: buscar `pagina=iecp/membro/ficha-Membro/insereAnexo`, `cadastrarUsuarioAcao`, `salvarDadosAcao`, `verificaSenha`, `atualizaFoto`, `listarPunicao`, `oper=del`.
- [ ] Tabela `login`: e-mails ou `acesso` alterados recentemente sem explicação (comparar com backup).
- [ ] Se houver indício de acesso indevido a dados pessoais: reunir evidências e informar o usuário, que comunica a CONIECP (§6.4).

---

### Fase 1 — Portões centrais

**1.1 `painel.php` exige sessão**
- Após o bloco de termo LGPD (linha ~29) e antes de resolver `?pagina=`: se não houver `$_SESSION['rm']` válido (inteiro ≥ 1) e `$_SESSION['email']`, responder redirect para `index.php` e `exit`.
- Lista de páginas públicas via painel: **vazia** (verificado: nenhuma página pública referencia `painel.php?pagina=`).
- Recusar `pagina` cujo caminho normalizado comece com `classes/`, `config/`, `vendor/`, `tests/`, `scripts/`, `sql/`, `docs/`, `node_modules/` ou contenha segmento `backup`, `bkp`, `pasta morta`, ou termine em `_old`, `-orig`, `_copia`, `_OLD` (case-insensitive) — mesma política do `.htaccess`, agora aplicada no include.
- Aceite: `GET /painel.php?pagina=index` sem cookie → 302 para `index.php`; com sessão → comportamento atual.

**1.2 Validadores param a execução**
- `validar_usuario_coniecp.php:99-104`, `validar_usuario_congregacao.php:78-93` e conferir os demais `validar_usuario_*.php`, `valida_sessao*.php`: todo `header('Location: …')` seguido de `exit;`.
- Aceite (teste estático): nenhum `header('Location` nesses arquivos sem `exit`/`die` na mesma instrução ou na linha seguinte.

**1.3 `classes/Connect.php`**
- Adicionar às opções: `PDO::ATTR_EMULATE_PREPARES => false`, `PDO::MYSQL_ATTR_MULTI_STATEMENTS => false`.
- Risco: consultas que reutilizam o mesmo placeholder nomeado duas vezes passam a falhar com prepares nativos. Antes do deploy, rodar o portão completo e varrer `prepare(` com placeholder repetido.
- Aceite: teste unitário confirma os dois atributos; `integrity-read` e `unit` verdes.

---

### Fase 2 — Upload e documentos pessoais

**2.1 `iecp/membro/ficha-Membro/insereAnexo.php` (reescrita)**
- Sessão válida + CSRF (`Classes\Csrf`).
- `rm_membro` via `FILTER_VALIDATE_INT` (≥1).
- Autorização: o próprio usuário (`rm` da sessão), secretaria/admin da IECP do membro (`cadastroministro.idIecp` = IECP da sessão), congregação do membro (`cadastroministro.idCongregacao` = congregação da sessão) ou CONIECP (nível 1). Centralizar numa classe (`Classes\DocumentoMembroAcesso::pode(int $rmOperador, int $rmMembro): bool`) usada por upload, download e remoção.
- Arquivo: `is_uploaded_file`, tamanho máximo 5 MB, `finfo` = `application/pdf` **e** bytes iniciais `%PDF-`, extensão gravada sempre `.pdf`.
- Nome em disco: `bin2hex(random_bytes(16)) . '.pdf'`; nome original só no banco (`nome_doc`) e escapado na saída.
- `move_uploaded_file`; diretório criado com `0750`.
- `Ministro::inserir_anexo` já usa placeholders (alteração local de 2026-10-07 — confirmar que não houve troca de fim de linha no arquivo inteiro antes do commit).
- Resposta em JSON; HTML montado no JS com `textContent`.

**2.2 `serve.php` para documentos**
- A pasta `documentos/` fica `Require all denied` (sem `serve.php` dentro dela). Criar `iecp/membro/documento.php` (rota via painel) que recebe `idDoc_membros`, carrega o registro, aplica a mesma autorização de 2.1 e entrega com `Content-Type: application/pdf`, `Content-Disposition: inline`, `X-Content-Type-Options: nosniff`, `readfile` de caminho resolvido com `realpath` dentro da pasta base.
- Seguir o padrão de `iecp/membro/anexos/serve.php` (regex numérica, recusa `..`).
- Atualizar links: `coniecp/cadastrar-ministro/ministro/fichaMinistro.php:497`, `iecp/ministro/ficha-Ministro/fichaMinistro.php:548`, `congregacao/membro/ficha-Ministro/fichaMinistro.php:546`, `meus-dados/meusDados.php:492`, e o HTML devolvido pelo upload.
- `removerAnexo.php`: mesma autorização + CSRF; apagar arquivo por caminho do banco validado com `realpath`.

**2.3 Migração dos arquivos existentes**
- Script CLI (guarda `PHP_SAPI`) que renomeia cada arquivo existente para nome aleatório e atualiza `doc_membros.caminho_doc`. Rodar com backup (`mysqldump` da tabela + cópia da pasta).
- Mover `documentos/` para fora do webroot **se** o HostGator permitir (pasta irmã de `public_html`); senão manter com `.htaccess` deny.

**2.4 `coniecp/cadastrar-ministro/ministro/atualizaFoto.php`**
- Replicar checagens de `iecp/ministro/ficha-Ministro/atualizaFoto.php` (sessão, nível CONIECP, CSRF, validação do data-URI).

**2.5 Fallback do `Fotos/.htaccess`**
- Negar `.php`/`.phtml`/`.phar` mesmo sem `mod_rewrite`.

---

### Fase 3 — Tomada de conta e senhas

| Arquivo | Correção |
|---|---|
| `meus-dados/salvarDadosAcao.php:72` | exigir `validar_usuario_usuario.php`; `rm = $_SESSION['rm']`, ignorar `rm` do POST |
| `meus-dados/verificaSenha.php` | exigir sessão; `rm` da sessão; limite de tentativas; **não** zerar `senha_antiga` (linha 10) |
| `admin/mudarSenhaAcao.php`, `meus-dados/mudarSenhaAcao.php` | exigir `senhaAtual` com `password_verify` no servidor; CSRF; não enviar a senha nova por e-mail (só aviso de alteração) |
| `login.php` | limite de tentativas por IP e por e-mail (reusar mecanismo de `esqueci-senha.php`); no login MD5 bem-sucedido, regravar com `password_hash(PASSWORD_ARGON2ID)` e marcar `password_updated=1`; remover e-mail pessoal fixo da linha 53 |
| `classes/PasswordResetActivation.php:73-78` | redefinição não altera `acesso` (bloqueado continua bloqueado) |
| `meus-dados/cadastrarUsuarioAcao.php:123,157` | operador sem nível 1 (CONIECP) não redefine senha nem altera acesso de usuário que tenha nível 1 — responder 403 (decisão §6.2) |
| `iecp/usuario/gerarSenha.php` | apagar (quebrado, `mt_rand`) |
| `$_SESSION['senha']` | avaliar trocar por hash do hash (ou versão de senha) para não manter o hash da senha no arquivo de sessão |

---

### Fase 4 — Segredos fora do código

1. Criar leitura única de configuração SMTP (`config/smtp.php`, já existe e é ignorado) e usá-la em `esqueci-senha.php:386`, `meus-dados/mudarSenhaAcao.php:204`, `admin/mudarSenhaAcao.php:198`. Ideal: classe `Classes\Mailer` única.
2. Senha de proteção dos PDFs (`SetProtection`, ~40 arquivos): mover para `config/pdf.local.php` (ou constante em config ignorado) e, preferencialmente, centralizar em `PdfComponentes`. Nova senha.
3. Apagar `classes/Conecta.class.php`, `classes/database/Connect.php` e todo arquivo com `new mysqli(`/`mysql_connect(` e credencial fixa (lista na Fase 9). Teste estático: nenhum arquivo versionado contém `conie847_` fora de `config/*.example.php`.
4. `git rm --cached .claude/settings.local.json` (contém a senha do banco) e conferir que `.gitignore` cobre.
5. **Histórico do git**: as senhas antigas continuam no histórico (`config.php`, commit `339d5b5a^`, e os arquivos acima). Remover com `git filter-repo --replace-text` conforme §6.3, depois das trocas de senha e desta fase.

---

### Fase 5 — SQL injection (25 pontos confirmados)

Padrão de correção: `prepare()` + placeholders; ids com `(int)`/`FILTER_VALIDATE_INT`; listas `IN` com `array_map('intval')` e `?` gerados (modelo: `coniecp/listaChamada/pdf/gerarPdfListaPresentesAssembleia.php`); `ORDER BY`/colunas só por allowlist; nunca `echo $e->getMessage()`.

| Arquivo:linha | Parâmetro |
|---|---|
| `coniecp/credencial/registrarEntrega.php:30,34` | `lista_rm[]`, datas, `cadastradoPor` — **arquivo órfão: apagar** |
| `coniecp/tesouraria/atualizaCadastro.php:15` | `tipo`, `status`, `idGrupoConiecp` |
| `coniecp/cadastrar-ministro/ministro/transferencia/listarTransferencia.php:14,20` | `rm` |
| `congregacao/membro/ficha-Ministro/formCargo.php`, `formDisc.php`, `formFuncao.php` | `id`, `rm`, `cargo_cg`, `iecp_ed`, `funcao_ed`, datas, `motivo` |
| `iecp/ministro/ficha-Ministro/formCargo.php`, `formDisc.php`, `formFuncao.php` | idem |
| `coniecp/listaChamada/pdf/gerarPdfListaIecp.php:42,74,125` | `lista` (+ remove `echo getMessage`) |
| `iecp/certificado/pdf/gerarPdfCertificado.php:163` | `lista` |
| `coniecp/credencial/bkp/gerarPdfCredencialMembro.php:111` | `lista` — **apagar pasta `bkp/`** |
| `meus-dados/listarSit.php:9`; `iecp/sindicancia/responder/listaSindicanciaMenu.php:13` | `rm` |
| `iecp/membro/pdf/gerarListaMembros.php:164`, `gerarListaObreiros.php:169`, `gerarListaExMembros.php:222` | `finalidade`, `rm_operador` |
| `iecp/tesouraria/balanceteMensal/incluirBalancete.php:10-21` → `classes/Balancete.class.php:56` | `mes`, `ano` |
| `coniecp/tesouraria/balanceteMensal/consultarBalancete/dadosBalanceteMensal.php:10` → `Balancete.class.php:163` | `idBalancete` |
| `coniecp/tesouraria/balanceteAnual/pdf/balanceteAnualPDF.php:64,76,106,137,193` | `ano`, `idIecp` |
| `coniecp/tesouraria/balanceteMensalConiecp/pdf/balanceteMensalPDF.php:47,84` | `idBalancete` |
| `coniecp/tesouraria/balanceteTrimestralConiecp/*` (`graficoDespesas.php:66`, `listarDespesas…:87`, `listarReceitas…:82`, `dadosBalanceteTrimestral.php:29-52` → `BalanceteConiecp.class.php:62,90`) | `ano` |
| `coniecp/usuario/dadosEditarUsuario.php:18`; `iecp/usuario/dadosEditarUsuario.php:4,20,29` | `rm` |
| `coniecp/notificacao/pdf/gerarPdfNotificacao.php:23` | `idNotificacao` (mysqli fixo — reescrever com `Connect`) |

Cada arquivo também recebe `valida_sessao_all.php` + `validar_usuario_<perfil>.php` no topo (defesa em profundidade além da Fase 1).

---

### Fase 6 — Controle de acesso e IDOR

| Arquivo | Problema | Correção |
|---|---|---|
| `coniecp/tesouraria/balanceteMensal/modificaStatusBalancete.php:16-18` e `balanceteMensalConiecp/modificaStatusBalancete.php` | qualquer logado finaliza/devolve balancete | `validar_usuario_coniecp.php` + nível 1 + CSRF |
| `congregacao/tesouraria/balanceteMensal/modificaStatusBalancete.php:9-25` | qualquer logado altera status de qualquer congregação | `AND idCongregacao = <sessão>` + validador congregação |
| `iecp/tesouraria/balanceteMensal/congregacao/devolverBalancete.php:22-69` e `…/congregacao/modificaStatusBalancete.php` | UPDATE só por `idBalancete` | conferir que a congregação pertence à IECP da sessão |
| `iecp/tesouraria/balanceteMensal/cadastraReciboAcao2.php`, `congregacao/…/cadastraReciboAcao-orig.php`, `iecp/oficio/insereAnexo_old.php` | legado sem dono/status; `unlink` arbitrário | **apagar** |
| `iecp/ministro/ficha-Ministro/dadosMinistro/dados.php:4-27` | ficha de ministro de qualquer IECP | `AND c.idIecp = :idIecpSessao` (CONIECP isento) |
| `iecp/secretaria/pdf/geraPdf_listaSecretaria.php:647` | PDF com dados pessoais de qualquer IECP, sem login | sessão + `idIecp` da sessão |
| `iecp/ministro/pdf/gerarPdfFicha.php:32`, `coniecp/cadastrar-ministro/pdf/gerarPdfFicha.php:32`, `coniecp/credencial/pdf/gerarPdfCredencialMembro.php:78-99`, `iecp/membro/pdf/gerarListaMembros.php:31` | PDFs com dados pessoais sem login/escopo | validador do perfil + escopo por IECP |
| `iecp/ministro/ficha-Ministro/formSit.php:42-71` e `formSit/formCargo/formDisc/formFuncao` em `coniecp/` e `congregacao/` | alteram situação/cargo de qualquer ministro | validador + escopo + CSRF |
| `coniecp/cadastrar-iecp/cadastrarIecpAcao.php`, `coniecp/qdm/cadastrarQdmAcao.php`, `modificaStatusQdm.php` | escrita sem validador | `validar_usuario_coniecp.php` + CSRF |
| `ebd/professor/lancarNotaAcao.php`, `ebd/aluno/atualizaChamadaAcao.php`, `ebd/aluno/atualizaLicaoMinistrada.php`, `ebd/aluno/deletaMatricula.php` | escrita sem validador | `validar_usuario_ebd.php` + escopo + CSRF |
| `coniecp/tesouraria/balanceteMensalConiecp/incluirDespesa.php`, `incluirReceita.php`, `incluirBalancete.php` | financeiro sem validador; `incluidoPor` do POST | validador CONIECP; `incluidoPor` da sessão |
| `iecp/oficio/anexos/serve.php:24`, `coniecp/oficio/anexos/serve.php:24` | anexo de outra IECP por caminho | conferir no banco o dono do ofício |
| `coniecp/cadastrar-ministro/verificaCpf.php`, `verificaEmail.php` | enumeração de CPF por qualquer logado | restringir a perfis que cadastram |

**Inventário completo:** gerar (script CLI) a lista dos endpoints sem validador que tocam o banco (~184) e tratar cada um: corrigir, ou apagar se órfão. A lista vira `tests/Http/conhecidos.json` (Plano 2a) e só pode diminuir.

---

### Fase 7 — XSS armazenado

| Arquivo | Correção |
|---|---|
| `coniecp/cadastrar-ministro/ministro/fichaMinistro.php:435`, `iecp/ministro/ficha-Ministro/fichaMinistro.php:484`, `congregacao/…/fichaMinistro.php:482` (`motivo`) | `htmlspecialchars` |
| `coniecp/cadastrar-iecp/visualizarIecp.php:493-511`, `iecp/dados_iecp/visualizarIecp.php:402-411` (`profissao`, `rua`, `bairro`, `estadoCivil`, `nome`) | escapar na saída |
| `iecp/secretaria/certificados.php:42,72`; `coniecp/tesouraria/…/listar*BalanceteTrimestral.php:77,81` (`grupo`) | escapar |
| `consultarOficioIecp.php:122,184`, `iecp/oficio/consultarOficioConiecp.php:130,190` (`<textarea>`) | escapar |
| `coniecp/oficio/cadastrarOficioAcao.php:202` | trocar `addslashes` por `Sanitizer` |
| `iecp/membro/cadastrarMembroAcao.php:24-28`, `iecp/ministro/transferencia/transferirMinistroAcao.php:27-36` | manter gravação crua (dado), escapar sempre na saída |

Regra: escapar na **saída**, não na entrada. Teste estático: nenhum `<?= $res[` / `echo $row[` sem helper de escape nos arquivos tocados.

---

### Fase 8 — Exposição, cabeçalhos, CSRF

**8.1 `backup/.htaccess` (produção) — replicar no `.htaccess` local**
- Negar diretórios iniciados por ponto em qualquer profundidade, exceto `.well-known`: `.claude/`, `.playwright-mcp/`, `.remember/`, `.superpowers/`, `.codex/`, `.agents/`, `.vscode/`.
- Negar na raiz: `*.json`, `*.csv`, `*.xml`, `*.txt`, `*.phar`, `*.yml` (exceto `robots.txt`, `sitemap.xml.gz`, manifestos usados).
- Corrigir regex de pastas internas se o sistema algum dia rodar em subpasta (hoje raiz — ok).
- Mover HSTS, `X-Content-Type-Options: nosniff` e `X-Frame-Options` de `header_security.php` para `Header always set` no `.htaccess` (cobre AJAX e estáticos).

**8.2 Erros**
- Remover os ~309 `echo $e->getMessage()` / `getFile` / `getLine` das respostas; `error_log` + mensagem genérica. Confirmar `display_errors=Off` em produção (`.user.ini`/cPanel).

**8.3 CSRF**
- Validação central: no `painel.php`, todo `POST` exige `csrf_token` válido (campo ou cabeçalho `X-CSRF-Token`), com lista de exceções explícita. Ajustar o `$.ajaxSetup` global para enviar o cabeçalho.
- Token CSRF não deve ser útil sem sessão autenticada (hoje `index.php` emite token a anônimo — ok para o form de login, mas handlers autenticados devem exigir sessão antes do token).

**8.4 Bibliotecas**
- `bootstrap@5.3.0-alpha3` → 5.3.x estável. `script/jquery.form.min.js` 3.51 → avaliar remoção (usar `fetch`/`FormData`). Não subir `tinymce/` 4.7.6 se não for usado.

---

### Fase 9 — Limpeza de legado

Apagar do repositório **e do servidor** (lista final gerada por script; conferir chamadores antes):
- arquivos com `mysql_*`, `new mysqli(` + credencial fixa, `require` de `config.php`, `fpdf/`, `jpgraph434/`, `MPDF5x`;
- `iecp/membro/ficha-Membro/form*.php` legados, `usuario/mensagem/*`, `*/usuario/nivelacesso.php`, `iecp/usuario/deletarUsuario.php`, `coniecp/visualizaMembros.php`, `gerarPdfAnual.php`, `grafico*.php` de tesouraria quebrados, `testa*.php`;
- pastas `backup/`, `Backup/`, `bkp/`, `pasta morta/` dentro de módulos; arquivos `*_old.php`, `*-orig.php`, `*_copia.php`, `* copy.php`, `*_cópia.php`;
- `iecp/membro/backup/` (contém cópia de `insereAnexo.php`).

Deploy: como o upload é manual, manter `docs/…/apagar-no-servidor.txt` com a lista para o usuário remover no cPanel.

## 4. Testes (portão pré-deploy)

Adicionar a `tests/Unit/Estatico/` (rodam no `gate.php --fast`):
1. `painel.php` contém checagem de sessão antes do `require $caminho_real`.
2. Nenhum `validar_usuario_*.php`/`valida_sessao*.php` com `header('Location` sem `exit`.
3. `Connect.php` define `ATTR_EMULATE_PREPARES=false` e `MYSQL_ATTR_MULTI_STATEMENTS=false`.
4. Nenhum arquivo versionado (fora `vendor/`, `*.example.php`) contém `conie847_`, `new mysqli(`, `mysql_connect(`, `->Password = '` literal.
5. Todo arquivo com `$_FILES` está numa allowlist revisada e usa `finfo` + `move_uploaded_file`.
6. `iecp/membro/ficha-Membro/documentos/.htaccess` existe com `Require all denied`.

Checagem HTTP pós-deploy (manual ou Plano 2a), todas **sem cookie**:

| Requisição | Esperado |
|---|---|
| `GET /painel.php?pagina=index` | 302 → `index.php` |
| `HEAD /iecp/membro/ficha-Membro/documentos/110/<qualquer>.pdf` | 403 |
| `POST /painel.php?pagina=meus-dados/salvarDadosAcao` | 302 (sem sessão) |
| `GET /painel.php?pagina=coniecp/portaria/backup/gerarPdfPortaria` | 404/302 |
| `HEAD /.claude/settings.local.json`, `/composer.phar`, `/DESIGN.json` | 403/404 |

Com sessão de teste IECP (contas `TESTE_GATE` do Plano 2a): abrir tela CONIECP → 302 **sem corpo**; `modificaStatusBalancete` → 403; ficha de ministro de outra IECP → 403/404.

## 5. Riscos

- **Prepares nativos (1.3)** podem quebrar consultas com placeholder nomeado repetido ou `LIMIT ?` com string. Mitigação: varredura + portão completo antes.
- **Portão do painel (1.1)** pode expor fluxos que hoje dependem de acesso anônimo sem que saibamos. Verificado: nenhuma página pública usa `painel.php?pagina=`. Monitorar `logs/security.log` após deploy.
- **Links de documento** quebram entre a Fase 0 e a Fase 2. Comunicar secretarias.
- **Troca de senha do banco (0.6)** exige upload imediato do `database.local.php` novo.

## 6. Decisões (usuário, 2026-10-07)

1. **Congregação envia e vê documento de membro: sim.** Escopo: `cadastroministro.idCongregacao` = congregação da sessão (e `idIecp` correspondente). (Fase 2.1/2.2)
2. **Admin de IECP NÃO redefine senha de diretor CONIECP.** Regra: o operador só redefine senha de quem não tem nível de acesso CONIECP (nível 1); CONIECP pode redefinir qualquer um. (Fase 3)
3. **Remover as senhas do histórico do git.** Repositório privado, só backup. Fazer **depois** da troca das senhas (Fase 0) e da Fase 4, com `git filter-repo` (substituição de texto, `--replace-text`) num clone espelho; antes, backup do `.git` (`git bundle --all`). Exige `push --force` em todos os branches e tags do `upstream` — confirmar com o usuário no momento da execução. Worktrees locais (`sisconiecp2-portao2a` etc.) precisam ser recriados depois.
4. **Incidente LGPD:** se a verificação 0.9 indicar acesso indevido a dados pessoais, **informar o usuário** com as evidências (arquivos, datas, IPs, registros afetados). O usuário informa a CONIECP, que decide e faz a comunicação. Nenhuma comunicação externa parte daqui.
5. **Tamanho máximo do PDF de documento: 5 MB.** Validar no servidor (`$_FILES['size']` e `filesize` do temporário) e avisar no cliente antes do envio.

## 7. Já correto (não mexer)

- **Exceção mantida (decisão do usuário, 2026-10-09):** `login.php:53` — o e-mail do administrador do sistema, fixo no código, entra também com `idStatusMinistro = 2`. Não remover.

Argon2id em senhas novas; `session_regenerate_id` no login; cookie `__Host-` Secure/HttpOnly/SameSite=Strict; expiração 3 h; sessão invalidada na troca de senha; perfil/nível vindos do banco; redefinição de senha (token 32 bytes, SHA-256, 45 min, uso único, rate limit); páginas públicas sem XSS; HTMLPurifier no TinyMCE; uploads novos (ofício, recibo, foto, capa EBD, `autenticador/comparar.php`); `serve.php` de anexos com regex numérica; HMAC de link de anexo com `hash_equals`; `config/.htaccess` deny; scanners com guarda CLI.

## 8. Andamento (atualizado 2026-10-09, 11:50)

**No ar e verificado em produção:** Fase 2.1/2.2 (upload e documentos de membro), Fase 1.1/1.2 (portão do painel, `exit` nos validadores), endpoints diretos com `GuardaEndpoint` (transferência, credencial), legados apagados, **portão global** (`classes/PortaoGlobal.php` + `config/portao_global.php`, ativado por `.user.ini` via MultiPHP INI Editor — `php_value` no `.htaccess` não funciona na HostGator). Senha do banco trocada.

**No ar em 2026-10-09 (verificado de fora, sem login → 302 para o login; falta conferir logado):** Fase 3 parte 1 (`ConferenciaSenha`, Meus Dados, troca de senha com senha atual); fotos de `Fotos/` só via `serve.php` com sessão (regra também no `.htaccess` da raiz); `classes/IdPost.php` nas consultas de balancete (congregação, IECP, CONIECP); `Balancete::listar` e `alterarSaldo` com consulta preparada.

Conferir logado (Fase 3 parte 1):

1. Meus Dados: alterar telefone ou endereço e salvar — precisa gravar normalmente.
2. Alterar senha (Meus Dados → senha): validar a senha atual, definir a nova, conferir que chega só um **aviso** por e-mail (sem a senha); sair e entrar com a senha nova.
3. Senha atual errada: precisa recusar; na 6ª tentativa seguida aparece "Muitas tentativas…".
4. Troca obrigatória: com usuário de teste com senha antiga (MD5), entrar e fazer a troca forçada.

### NO AR 2026-10-09 12:25 — Fase 3, parte 2 (login e administração de usuários)

Tabela `login_attempts` criada (local e produção). Verificado de fora: 5 erros com e-mail inexistente → 6ª vai para `erro.php?motivo=limite`; outro e-mail do mesmo IP segue normal. Falta conferir logado (lista abaixo).

Pronta local, 805 testes unitários OK; `login.php` e `cadastrarUsuarioAcao.php` executados de verdade com SQLite (`php -S`), banco MySQL local desligado.

1. **Antes:** rodar `sql/login_attempts.sql` no phpMyAdmin. Sem a tabela o login funciona, mas sem limite (erro no `error_log`).
2. Subir:

```
classes/LimiteLogin.php
classes/NivelAcessoUsuario.php
classes/PasswordResetActivation.php
login.php
erro.php
meus-dados/cadastrarUsuarioAcao.php
```

O que muda:

- Login: 5 erros por e-mail ou 20 por IP em 15 min → `erro.php?motivo=limite` ("Muitas tentativas…"), mesmo com a senha certa. Senha certa zera os erros daquele e-mail. E-mail inexistente custa o mesmo tempo de uma senha errada.
- Conta MD5 que entra com a senha certa tem o hash trocado por Argon2id da mesma senha; `password_updated` continua 0, então a troca obrigatória segue. Outras sessões abertas desse usuário caem uma vez (hash mudou).
- "Esqueci a senha" troca a senha mas não desbloqueia conta bloqueada pelo administrador.
- `meus-dados/cadastrarUsuarioAcao.php`: só administrador (IECP ou CONIECP); o endpoint aceitava, por pedido direto fora da tela, que o próprio usuário trocasse a senha **sem a senha atual** (a tela de Meus Dados sempre pediu a senha atual). Admin de IECP recebe 403 ao alterar usuário com nível 1 (CONIECP).

Conferir depois de subir:

1. Entrar normalmente. Errar a senha 5 vezes com um usuário de teste → 6ª tentativa (mesmo certa) mostra "Muitas tentativas"; após 15 min entra.
2. Usuário MD5 de teste: entra, é levado à troca obrigatória; no phpMyAdmin `login.senha` começa com `$argon2id$` antes mesmo da troca.
3. Admin IECP: editar senha de usuário da própria IECP funciona; de um diretor CONIECP aparece "Somente a CONIECP pode alterar este usuário."
4. Conta bloqueada de teste: "esqueci a senha" → redefine → login continua indo para "acesso bloqueado".

### Próximos

- Limpeza: órfãos `meus-dados/js/alterarSenha.js`, `meus-dados/js/mudarSenhaAntiga.js`, `meus-dados/verificaSenha.php`; fotos com CPF no nome (`scripts/lgpd/renomear_fotos.php`).
- SMTP: mover senha para `config/smtp.php` → trocar a senha no cPanel → limpar histórico do git (`git filter-repo`).
- Fases 5–9 conforme acima.
