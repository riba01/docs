# Retenção de logs — LGPD Fase 5

Atualizado em 15/07/2026. Revisão exigida pelo plano (`plan_lgpd.md`, Fase 5).

## Base legal

- **Marco Civil da Internet, art. 15**: provedor de aplicação deve guardar
  registros de acesso por **no mínimo 6 meses**, em sigilo.
- **LGPD, art. 15-16**: dados pessoais devem ser eliminados após o fim do
  tratamento; logs contendo IP/identificação são dados pessoais.

**Política adotada (proposta): reter 6 meses, purgar depois.** Ajustar se o
responsável definir prazo diferente (decisão da Fase 4).

## Inventário de logs

### Em banco (cobertos pela criptografia da Fase 2)

| Origem | Conteúdo | Retenção | Purga |
|---|---|---|---|
| `auditoria_acesso` | quem viu ficha/CPF de quem (Fase 5) | 6 meses | `scripts/lgpd/purgar_auditoria.php` (agendar) |
| `user_sessions` | sessões: rm, IP, user-agent, datas | 6 meses | pendente — criar purga análoga |
| `registro_atividade` | ações do operador (buscas, PDFs) | 6 meses | pendente — criar purga análoga |
| `user_login` | último acesso por conta | mantém só o último | ok |

### Em arquivo (bloqueados via HTTP pelo `.htaccess` raiz — Fase 0)

| Arquivo | Escritor | Conteúdo | Ação |
|---|---|---|---|
| `logs/security.log` | `painel.php` | eventos de segurança, IP | purgar > 6 meses |
| `csp-violations.log` | `csp-report.php` | violações CSP, IP/URL | purgar > 6 meses |
| `error_log` (raiz, `classes/`, `admin/`, `autenticador/`, `Fotos/`) | PHP `error_log()` | mensagens de erro — podem conter dados pessoais em stack traces | purgar > 6 meses; evitar logar valores de CPF/RG |
| `classes/check_matricula_debug.log` | debug antigo | verificar; provavelmente morto | apagar/remover escritor |
| `log/mpdf/` | mPDF (temporários) | fontes/cache, sem dado pessoal | limpar quando conveniente |
| `.playwright-cli/`, `.playwright-mcp/` | ferramentas de dev local | console de testes | fora do deploy; não subir para produção |

## Regras

1. Nunca gravar CPF/RG em claro em log (usar rm como identificador).
2. Logs de arquivo ficam fora do webroot em produção quando possível; onde não
   der, o `.htaccess` raiz nega acesso (`.log`, `error_log`) — já ativo.
3. Purga agendada (Task Scheduler em dev/Windows; cron no cPanel em produção):
   - `php scripts/lgpd/purgar_auditoria.php` — semanal.
   - Purga de `user_sessions`/`registro_atividade` — criar script análogo
     quando o prazo for confirmado pelo responsável.
4. Backups cifrados (Fase 2) contêm cópias dos logs de banco — o prazo de
   retenção dos backups limita a eliminação efetiva; documentar no registro de
   tratamento.

## Pendências

- [ ] Responsável confirmar prazo (6 meses proposto).
- [ ] Script de purga para `user_sessions` e `registro_atividade`.
- [ ] Agendar purgas (dev: Task Scheduler; produção: cron do cPanel).
- [ ] Verificar/remover `classes/check_matricula_debug.log` e seu escritor.
