# LGPD Fase 2 — Criptografia em repouso (InnoDB) e backups cifrados

## O que protege

Arquivos físicos `.ibd`, redo/undo logs e binlogs cifrados no disco. Cobre
roubo de disco/HD, cópia dos arquivos do datadir e backups de filesystem.
**Não** protege contra acesso SQL (DBA, SQL injection) — isso é a Fase 3.

## 1. Keyring (MySQL 8.4, WAMP local)

Arquivos já criados por esta fase:

- `C:\wamp64\bin\mysql\mysql8.4.6\bin\mysqld.my` — manifest que carrega
  `component_keyring_file`;
- `C:\wamp64\bin\mysql\mysql8.4.6\lib\plugin\component_keyring_file.cnf` —
  aponta o arquivo de chaves para `C:/wamp64/keyring/` (fora do datadir).

**Passo manual necessário:** reiniciar o MySQL (Wampmanager → MySQL →
Service administration → Restart) — o serviço exige privilégio de admin.

Verificação após o restart:

```sql
SELECT * FROM performance_schema.keyring_component_status;
-- Component_status deve ser 'Active'
```

> Backup da pasta `C:\wamp64\keyring\` é obrigatório e deve ficar SEPARADO
> do backup do banco — sem a chave, as tabelas cifradas são irrecuperáveis;
> junto com o dump, a criptografia perde o sentido.

## 2. Cifrar as tabelas

```bash
php scripts/lgpd/ativar_criptografia_tabelas.php --dry-run   # revisa
php scripts/lgpd/ativar_criptografia_tabelas.php             # aplica
```

O script cifra todas as tabelas InnoDB do schema (idempotente — pula as já
cifradas). Novas tabelas: definir `default_table_encryption=ON` no `my.ini`
(seção `[mysqld]`) para nascerem cifradas.

Recomendado também no `my.ini`:

```ini
default_table_encryption=ON
innodb_redo_log_encrypt=ON
innodb_undo_log_encrypt=ON
binlog_encryption=ON
```

## 3. Backups cifrados

- Linux/produção: `scripts/lgpd/backup_cifrado.sh /destino`
- Windows/local: `scripts/lgpd/backup_cifrado.ps1 -Destino D:\backups`

Ambos fazem `mysqldump | openssl enc -aes-256-cbc -pbkdf2` — o dump nunca
existe em claro no disco. A chave (`backup.key`) é gerada fora do webroot na
primeira execução; guardar cópia offline.

Restauração:

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -pass file:/caminho/backup.key -in dump.sql.enc | mysql swga
```

## 4. Produção (hospedagem compartilhada)

Em hospedagem compartilhada (cPanel) não há acesso ao `my.cnf` nem ao
keyring do servidor — encryption-at-rest do InnoDB **não pode ser ativada
pelo cliente**. Nesse cenário:

1. confirmar com o provedor se o storage já é cifrado (muitos usam LUKS/
   discos cifrados — pedir declaração por escrito para o registro LGPD);
2. os backups cifrados (item 3) continuam valendo e são obrigatórios;
3. a proteção de campos críticos vem da Fase 3 (criptografia de aplicação),
   que independe do servidor.

## Status

- [x] Manifest + cnf do keyring criados (local)
- [ ] Restart do MySQL (manual, admin)
- [ ] `ativar_criptografia_tabelas.php` executado
- [ ] `default_table_encryption=ON` + redo/undo/binlog no my.ini
- [ ] Rotina de backup cifrado agendada (Task Scheduler / cron)
- [ ] Declaração de storage cifrado do provedor (produção)
