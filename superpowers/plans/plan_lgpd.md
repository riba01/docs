# Plano LGPD — SISCONIECP/SWGA

Atualizado em 15/07/2026. Branch `lgpd` (mergeada em `main`, push feito).
**Fases 0-5 concluídas em dev.** Débitos do responsável: (1) nome/contato do
DPO (placeholders em encarregado.php/politica-privacidade.php/docs);
(2) deploy produção (ordem abaixo em Pendências gerais).

## Fase 0 — Pré-requisitos de segurança ✅ CONCLUÍDA

1. ✅ Credenciais fora do código — `Connect.php` lê `.env` via `classes/Env.php`
   (produção: `../.env.sisconiecp` acima do webroot). Interface
   `Connect::getInstance()` preservada. (commit e6c73350)
2. ✅ MD5 eliminado do login — só Argon2id (`password_verify`). Conta com hash
   legado é redirecionada para `esqueci-senha.php?motivo=senha_expirada`
   (reset forçado). ~35 contas md5 migram no próximo login. (80355871)
3. ✅ Senha/hash fora de `$_SESSION` — substituído por `senha_fp` (SHA-256 do
   hash armazenado), validado com `hash_equals` a cada request. (80355871)
4. ✅ Webroot protegido — `.htaccess` raiz (nega `.env`, `.sql`, `.log`, `.key`,
   `error_log` + força HTTPS fora de localhost); deny total em `sql/`,
   `backup/`, `log/`, `logs/`, `classes/`; `Fotos/` (nomes = CPF) e
   `documentos/` de membros servidos só via `serve.php` com sessão;
   338 PDFs pessoais removidos do versionamento. (54627dab, 433c93b5)
5. ✅ HTTPS + cookies — `StartSecureSession` (secure/httponly/samesite Strict)
   em todos os entry points, incl. `painel.php`. (79aafe51)

Extras da fase: 8 endpoints legados mortos com md5/SQLi/vazamento de hash
deletados; `classes/scripts/mudarRegistrosCadastroMinitro.php` (cifraria a
tabela in-place via GET sem auth) removido; chave antiga `chave_secreta.key`
fora do git.

## Fase 1 — Inventário de dados ✅ CONCLUÍDA

`docs/lgpd/inventario-dados.md` — registro de tratamento (art. 37): titulares,
classificação por coluna, bases legais, decisões da Fase 3, pendências.

## Fase 2 — Criptografia em repouso ✅ CONCLUÍDA (dev)

- ✅ Keyring `component_keyring_file` ativo (MySQL 8.4 WAMP; manifest
  `mysqld.my` + cnf apontando `C:/wamp64/keyring/`).
- ✅ 103/103 tabelas cifradas (`scripts/lgpd/ativar_criptografia_tabelas.php`).
  Aprendizados incorporados ao script: 51 tabelas MyISAM → InnoDB;
  `ROW_FORMAT=DYNAMIC` para legadas FIXED; `sql_mode=''` na sessão por causa
  de datas `0000-00-00`.
- ✅ Backup cifrado (`mysqldump | openssl aes-256-cbc -pbkdf2`) —
  `scripts/lgpd/backup_cifrado.sh|.ps1`; executado (D:\backups_swga); chave em
  `C:\wamp64\keyring\swga_backup.key` (cópia offline obrigatória).
- Guia: `docs/lgpd/criptografia-em-repouso.md`.
- ✅ (15/07/2026) `default_table_encryption=ON` + `innodb_redo_log_encrypt=ON`
  + `innodb_undo_log_encrypt=ON` ativados via SET GLOBAL e persistidos no
  my.ini (binlog desativado — log_bin=OFF, encryption não se aplica).
- ✅ Backup agendado (Task Scheduler diário 02:00) + purgas semanais.
- ⬜ Produção compartilhada não permite keyring — pedir declaração de
  storage cifrado ao provedor.

## Fase 3 — Criptografia de campo (CPF/RG) ✅ CONCLUÍDA (dev)

- ✅ (fundação) `classes/Crypto.php` — libsodium secretbox, ciphertext
  versionado `v1:` (rotação futura), `blindIndex()` HMAC-SHA256 normalizado
  (com/sem máscara ⇒ mesmo índice). Chaves `APP_ENC_KEY`/`APP_BIDX_KEY` no
  `.env`. (e103c72e)
- ✅ (a) colunas `cpf_enc`, `cpf_bidx`, `identidade_enc`, `identidade_bidx` +
  índices em `cadastroministro`. (4864da92)
- ✅ (b) dual-write em `Ministro.class` (único ponto de escrita ativo).
- ✅ (c) backfill 3174 linhas, 0 divergências na verificação.
- ✅ (d) leituras migradas via `Crypto::preencherCampos()` — Ministro.class,
  6 validar_usuario\*, fichas, meus-dados, credencial/ficha/certificado/
  batismo/listas/9 tesourarias PDFs. Buscas por CPF via `cpf_bidx`
  (`verificaCpf`, `buscaMembrosAcao`, `cadastrarMembroAcao`) — LIKE parcial
  de CPF deixou de existir (decisão de projeto); de quebra 2 SQLi eliminados.
  (ee95d2db, e77a1b6a)
- ✅ (e) validado pelo usuário em dev (telas + PDFs).
- ✅ (f) colunas em claro `cpf`/`identidade` DROPADAS + `OPTIMIZE TABLE`;
  UNIQUE preservado sobre `cpf_bidx`. Roundtrip pós-drop validado. (87253dfe)

Não cifrado campo a campo (decisão mantida): nomes, datas de filtro, chaves
de junção, endereço/telefone — protegidos pela Fase 2 + controle de acesso.

## Fase 4 — Direitos do titular ✅ CONCLUÍDA (dev; DPO pendente)

- ✅ Prazos definidos (15/07/2026): desligados 5 anos; mensagens 2 anos;
  logs 6 meses. Textos atualizados.
- ✅ Registro de aceite: `classes/TermoConsentimento.php` + tabela
  `aceite_termo` (rm, versão, IP, UA; UNIQUE rm+versão; cifrada), tela
  `aceite-termo.php`, gate em `painel.php` (bump em VERSAO força novo
  aceite). Validado em runtime.
- ✅ Páginas públicas: `politica-privacidade.php` e `encarregado.php` (DPO).
- ✅ Exportação (art. 18 V): `meus-dados/exportarDados.php` — JSON com
  cadastro decifrado + históricos + registros de acesso; botão em Meus
  Dados; acesso auditado. Correção já existia (meus-dados edita).
- ✅ Anonimização EXECUTADA (15/07/2026): 1296/1296 desligados/excluídos há
  5+ anos anonimizados. Decisão: `cpf_bidx` PRESERVADO (pseudonimização —
  HMAC não recupera CPF, mas verificaCpf detecta retorno e permite
  reaproveitar rm/histórico no recadastro). Contas login removidas;
  e-mail vira `anonimizado.<rm>@invalido.local` (UNIQUE). Agendado mensal
  (Task Scheduler dia 1, 04:00 — `anonimizacao_mensal.cmd`). 6 desligados
  sem data em situacao_membro ignorados — revisar manualmente.
- ⬜ ÚNICO PENDENTE: nome/contato do DPO — substituir [DPO_NOME]/
  [DPO_CONTATO] em encarregado.php, politica-privacidade.php e docs/lgpd/*.
  Revisão jurídica dos textos recomendada.

## Fase 5 — Auditoria e incidentes 🔶 EM ANDAMENTO

- ✅ `classes/Auditoria.class.php` + tabela `auditoria_acesso` (auto-criada,
  ENCRYPTION='Y' com fallback; fail-open com error_log). Instrumentados:
  fichaMembro, dados (ficha ministro), dadosEditarUsuario, 2× gerarPdfFicha,
  2× gerarPdfCredencialMembro (1 registro por titular), verificaCpf,
  buscaMembrosAcao (busca CPF), 3 PDFs de lista (lote).
- ✅ Gate de sessão (`valida_sessao_all.php`) adicionado aos 4 PDFs de
  ficha/credencial — antes eram acessíveis sem login (continham CPF/RG).
- ✅ Purga: `scripts/lgpd/purgar_auditoria.php` (padrão 6 meses) — agendar.
- ✅ Revisão de retenção de logs: `docs/lgpd/retencao-logs.md` (inventário
  arquivo+banco, política proposta de 6 meses, pendências).
- ✅ Purga de logs de acesso: `scripts/lgpd/purgar_logs_acesso.php`
  (user_sessions, registro_atividade, registrovisita, user_login + arquivos)
  — executado 15/07/2026: 95.606 registros antigos removidos.
- ✅ Procedimento ANPD: `docs/lgpd/procedimento-incidentes-anpd.md`
  (Res. CD/ANPD 15/2024, prazo 3 dias úteis, passo a passo, contatos).
- ✅ Validado em runtime (auditoria_acesso e aceite_termo criadas cifradas;
  insert/select OK).
- ✅ Agendado (Task Scheduler): backup cifrado diário 02:00
  (`backup_diario.cmd`; openssl resolvido; chave canônica
  `C:\wamp64\keyring\swga_backup.key`; restauração testada) e purgas
  semanais dom 03:00 (`purgas_semanais.cmd`).

## Pendências gerais

- ⬜ Deploy produção: subir `.env.sisconiecp` + chaves acima do webroot;
  rodar na ordem: `fase3_migrar_colunas` → `fase3_backfill` → deploy código →
  validar → `fase3_drop_colunas_claras --confirmo` (com backup antes).
- ✅ Histórico git purgado (15/07/2026, `git filter-repo`): todos os PDFs
  (1143 no histórico) + `ficha-Membro/documentos/` + imagens de anexos.
  Repo 1,65 → 1,29 GiB. Backup espelho pré-rewrite:
  `D:\backups_swga\sisconiecp_pre_filter_repo.git`.
  ⚠️ Hashes mudaram: `git push --force` para origin e re-clone por
  quaisquer outras cópias.
- ✅ DESCOBERTA/CORREÇÃO (15/07/2026): 826 documentos pessoais em
  `iecp/oficio/anexos`, `coniecp/oficio/anexos` e `iecp/membro/anexos`
  (certidões, RG/CPF, sindicâncias) estavam versionados E acessíveis por
  URL sem login. Gate serve.php + .htaccess aplicado (padrão Fotos/),
  untracked + .gitignore, histórico purgado. Validado: acesso direto → 403.
- ✅ Fotos renomeadas (15/07/2026): 2182 referenciadas → `img_<uniqid>.<ext>`
  + coluna atualizada; 331 órfãs → `orfao_<uniqid>`; 0 nomes com CPF/dados
  restantes (`scripts/lgpd/renomear_fotos.php`). rm=573 tinha referência a
  arquivo inexistente — foto zerada.
- ✅ Coluna `cadastroministro.senha` zerada e DROPADA + OPTIMIZE (15/07/2026).
- ✅ Removidos `Ministro_nova.class.php` e `classes/app/` (15/07/2026).
- ✅ Merge `lgpd` → `main` (15/07/2026, fast-forward pós filter-repo).
  Pendente: `git push --force origin main lgpd` (hashes reescritos).
