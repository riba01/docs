# Procedimento de resposta a incidentes de segurança — LGPD art. 48

Atualizado em 15/07/2026. Complementa `retencao-logs.md` e o plano LGPD.

## 1. O que é incidente notificável

Incidente de segurança que possa acarretar **risco ou dano relevante** aos
titulares (art. 48): vazamento/exposição de CPF, RG, fichas, credenciais de
acesso, dados de disciplina eclesiástica ou de menores (EBD); perda de
disponibilidade com destruição de dados; acesso não autorizado confirmado.

Referência ANPD: Resolução CD/ANPD nº 15/2024 (comunicação de incidentes).
Formulário oficial: <https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis>

## 2. Prazos

- **Comunicar à ANPD e aos titulares afetados em até 3 dias úteis** a partir
  do conhecimento de que o incidente afeta dados pessoais (Res. 15/2024).
- Registro interno: **imediato**, mesmo para incidentes não notificáveis
  (obrigação de manter registro — art. 48 § 3º e boas práticas).

## 3. Passo a passo

1. **Conter**: bloquear o vetor (trocar senhas/chaves comprometidas — `.env`:
   credenciais MySQL, `APP_ENC_KEY`/`APP_BIDX_KEY` se expostas; revogar
   sessões apagando `user_sessions`; tirar o sistema do ar se necessário).
2. **Preservar evidências**: copiar `auditoria_acesso`, `user_sessions`,
   `logs/security.log`, `error_log` e logs do provedor **antes** de qualquer
   limpeza; anotar data/hora de descoberta.
3. **Avaliar**: quais dados, quantos titulares, sensibilidade (CPF/RG,
   menores, disciplina), probabilidade de dano. Usar `auditoria_acesso` para
   delimitar o que foi acessado e por quem.
4. **Decidir notificação**: se risco/dano relevante → notificar (prazo do
   item 2). Na dúvida, notificar. Quem decide: Encarregado (DPO) com o
   responsável pela Organização.
5. **Comunicar ANPD** pelo formulário oficial (item 1) com: natureza dos
   dados, titulares afetados, medidas de contenção, riscos, contato do DPO.
6. **Comunicar titulares** afetados (e-mail do cadastro): o que vazou, o que
   foi feito, o que o titular deve fazer (ex.: monitorar uso do CPF).
7. **Registrar internamente**: relatório em `docs/lgpd/incidentes/` —
   `AAAA-MM-DD-resumo.md`: linha do tempo, causa raiz, dados/titulares,
   notificações feitas, correções aplicadas.
8. **Corrigir e revisar**: eliminar a causa raiz; reavaliar este procedimento.

## 4. Contatos

| Papel | Quem |
|---|---|
| Encarregado (DPO) | [DPO_NOME] — [DPO_CONTATO] (**pendente definição**) |
| Responsável técnico | Armando Ribamar — armando.ribamar@gmail.com |
| Provedor de hospedagem | cPanel — suporte do provedor (produção) |

## 5. Mitigadores já implantados (reduzem dever de comunicação)

Criptografia de campo (CPF/RG) com chaves fora do banco, criptografia em
repouso + backups cifrados, hash Argon2id de senhas: vazamento do banco sem
as chaves tende a **não** gerar risco relevante (art. 48 § 1º, II é atenuado
quando os dados estão cifrados) — ainda assim, avaliar caso a caso e
registrar a decisão.
