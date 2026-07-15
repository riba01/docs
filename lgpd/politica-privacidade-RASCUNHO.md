# Política de Privacidade — SISCONIECP/SWGA (RASCUNHO)

> **RASCUNHO para revisão do responsável.** Campos entre colchetes exigem
> decisão/preenchimento: `[RAZÃO SOCIAL]`, `[CNPJ]`, `[ENDEREÇO]`,
> `[DPO_NOME]`, `[DPO_CONTATO]`, `[PRAZO_DESLIGADO]`, `[PRAZO_MENSAGENS]`.
> Recomenda-se revisão jurídica antes da publicação.

**Última atualização:** [DATA DE PUBLICAÇÃO] — versão 1.0

## 1. Quem somos

O SISCONIECP (Sistema de Gestão da Convenção das Igrejas Evangélicas Cristãs
Pentecostais) é operado por **[RAZÃO SOCIAL]**, CNPJ **[CNPJ]**, com sede em
**[ENDEREÇO]** ("Organização"), na condição de **controladora** dos dados
pessoais tratados no sistema.

## 2. Encarregado de Dados (DPO)

Encarregado pelo tratamento de dados pessoais (LGPD, art. 41):
**[DPO_NOME]** — contato: **[DPO_CONTATO]**.

## 3. Dados que tratamos e finalidades

| Categoria | Exemplos | Finalidade |
|---|---|---|
| Identificação civil | nome, CPF, RG, filiação, data de nascimento | Cadastro de membros/ministros, emissão de credenciais e certificados |
| Contato e endereço | e-mail, telefone, endereço | Comunicação institucional |
| Vida eclesiástica | cargo, batismo, data de ingresso, histórico ministerial | Gestão convencional e estatutária |
| Registros disciplinares | sindicâncias, pareceres | Cumprimento de normas estatutárias |
| Dados de alunos EBD | nome, data de nascimento, frequência, avaliações | Gestão da Escola Bíblica Dominical |
| Registros de acesso | IP, data/hora, navegador | Segurança e obrigação legal (Marco Civil, art. 15) |

**Dado sensível:** a vinculação a esta Organização constitui dado relativo a
convicção religiosa (LGPD, art. 5º, II). O tratamento ampara-se no
art. 11, II, "a" e na atividade legítima de organização religiosa sem fins
lucrativos em relação a seus membros.

**Menores de idade:** dados de alunos menores da EBD são tratados no melhor
interesse da criança/adolescente (art. 14), com consentimento de ao menos um
dos pais ou responsável quando exigido.

## 4. Bases legais

- Cumprimento de obrigação estatutária/legal (art. 7º, II; art. 11, II, "a").
- Execução das atividades da organização religiosa junto a seus membros.
- Consentimento, quando aplicável (art. 7º, I) — registrado com data, IP e
  versão do termo aceito.
- Legítimo interesse para segurança do sistema (art. 7º, IX).

## 5. Como protegemos seus dados

- CPF e RG armazenados **cifrados** (criptografia de campo, libsodium).
- Banco de dados com **criptografia em repouso** e backups cifrados.
- Senhas armazenadas com hash **Argon2id**; tráfego somente via **HTTPS**.
- Fotos e documentos pessoais servidos apenas a usuários autenticados.
- **Auditoria de acesso**: consultas a fichas e documentos com CPF são
  registradas (quem acessou, o quê, quando).

## 6. Compartilhamento

Não vendemos nem compartilhamos dados pessoais com terceiros para fins
comerciais. Dados podem ser compartilhados apenas: (i) por obrigação legal ou
ordem de autoridade competente; (ii) com o provedor de hospedagem, na condição
de operador, limitado ao necessário para o funcionamento do sistema.

## 7. Retenção

| Dado | Prazo |
|---|---|
| Cadastro de membro ativo | Enquanto durar o vínculo |
| Membro desligado | **[PRAZO_DESLIGADO]** após o desligamento; depois, anonimização |
| Mensagens internas | **[PRAZO_MENSAGENS]** |
| Registros de acesso (logs) | 6 meses (Marco Civil, art. 15) |
| Registros de auditoria de acesso a dados | 6 meses |

## 8. Seus direitos (LGPD, art. 18)

Você pode solicitar: confirmação de tratamento, **acesso** aos seus dados,
**correção**, anonimização/bloqueio/eliminação do que for desnecessário,
**portabilidade**, informação sobre compartilhamentos e **revogação de
consentimento**.

Como exercer: pelo menu **Meus Dados** no sistema ou pelo contato do
Encarregado (seção 2). Prazo de resposta: 15 dias.

## 9. Incidentes de segurança

Incidentes com risco relevante aos titulares serão comunicados à ANPD e aos
afetados (art. 48), conforme procedimento interno documentado.

## 10. Alterações desta política

Alterações serão publicadas nesta página com nova data e versão. Alterações
relevantes serão comunicadas no acesso ao sistema, com novo registro de aceite.
