# Plano LGPD — SISCONIECP/SWGA

Atualizado em 14/07/2026. Branch `lgpd`. Fases 0-3 concluídas e validadas em dev.

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
- ⬜ Pendente: `default_table_encryption=ON` + redo/undo/binlog no my.ini;
  agendar backup (Task Scheduler/cron); produção compartilhada não permite
  keyring — pedir declaração de storage cifrado ao provedor.

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
  6 validar_usuario*, fichas, meus-dados, credencial/ficha/certificado/
  batismo/listas/9 tesourarias PDFs. Buscas por CPF via `cpf_bidx`
  (`verificaCpf`, `buscaMembrosAcao`, `cadastrarMembroAcao`) — LIKE parcial
  de CPF deixou de existir (decisão de projeto); de quebra 2 SQLi eliminados.
  (ee95d2db, e77a1b6a)
- ✅ (e) validado pelo usuário em dev (telas + PDFs).
- ✅ (f) colunas em claro `cpf`/`identidade` DROPADAS + `OPTIMIZE TABLE`;
  UNIQUE preservado sobre `cpf_bidx`. Roundtrip pós-drop validado. (87253dfe)

Não cifrado campo a campo (decisão mantida): nomes, datas de filtro, chaves
de junção, endereço/telefone — protegidos pela Fase 2 + controle de acesso.

## Fase 4 — Direitos do titular ⬜ PENDENTE

Bloqueada por decisões do responsável:
1. Encarregado (DPO): nome/contato para publicar (art. 41).
2. Prazos de retenção: membro desligado, mensagens internas, logs
   (sugestão logs: 6 meses — Marco Civil art. 15).
3. Textos: política de privacidade + termo de consentimento (rascunho pode
   ser gerado para revisão).

Entregas: exportar dados em `meus-dados/` (art. 18 V), correção, rotina de
anonimização de desligados pós-retenção, registro de aceite (data/IP/versão
do termo), página do DPO.

## Fase 5 — Auditoria e incidentes ⬜ PENDENTE

- Tabela `auditoria_acesso` (quem viu ficha/CPF de quem, quando).
- Revisão de retenção de logs (`log/`, `logs/`, `error_log`).
- Procedimento de notificação à ANPD (art. 48).

## Pendências gerais

- ⬜ Deploy produção: subir `.env.sisconiecp` + chaves acima do webroot;
  rodar na ordem: `fase3_migrar_colunas` → `fase3_backfill` → deploy código →
  validar → `fase3_drop_colunas_claras --confirmo` (com backup antes).
- ⬜ Purgar 338 PDFs pessoais do histórico git (`git filter-repo`).
- ⬜ Renomear fotos para não usar CPF como nome de arquivo.
- ⬜ Coluna `cadastroministro.senha` (hash legado, sem uso no código): zerar/dropar.
- ⬜ Remover `Ministro_nova.class.php` e `classes/app/` (tentativa antiga, sem uso).
- ⬜ Merge da branch `lgpd` em `main`.
