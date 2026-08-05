# Inventário de Dados Pessoais — SISCONIECP/SWGA

Registro das operações de tratamento de dados pessoais (LGPD, art. 37).
Base: schema do banco `swga` em 14/07/2026.

**Nota sobre dado sensível:** por se tratar de sistema de gestão de organização
religiosa, a própria vinculação de qualquer titular ao sistema constitui dado
relativo a convicção religiosa — **dado pessoal sensível** (LGPD art. 5º, II).
Tratamento amparado pelo art. 11, II, "a" (cumprimento de obrigação
estatutária/legal) e art. 5º combinado com atividade de organização religiosa
sem fins lucrativos para seus membros.

## Titulares

| Titular | Tabelas principais |
|---|---|
| Ministros/obreiros | `cadastroministro`, `login`, `credencial`, `historicocargo`, `historicofuncao`, `historicopunicao`, `historicosindicancia`, `sindicancia`, `situacao_membro`, `transferencia`, `doc_membros`, `qdm` |
| Alunos EBD | `matriculaebd`, `matricula_turmaebd`, `avaliacaoalunoebd`, `registropresencaebd` |
| Usuários do sistema | `login`, `registrovisita`, `user_login`, `user_sessions`, `password_reset_*`, `registro_atividade` |
| Comunicações internas | `mensagem`, `mensagemenviada` |

## Classificação por coluna

### `cadastroministro` (núcleo — maior concentração de dados)

| Coluna | Categoria | Criticidade |
|---|---|---|
| `cpf` | Identificador civil | **Alta — candidata a criptografia de campo (Fase 3)** |
| `identidade` (RG), `orgao_emissor`, `dataEmissao` | Identificador civil | **Alta — candidata a criptografia de campo (Fase 3)** |
| `nome`, `nomePai`, `nomeMae` | Identificação | Média (busca/ordenação — não cifrar campo a campo; proteger com camada 2 + acesso) |
| `foto` (aponta para `Fotos/<CPF>.jpg`) | Biométrico em potencial / imagem | **Alta — acesso já restrito via `Fotos/serve.php`; nome de arquivo contém CPF (corrigir na Fase 3)** |
| `dataNasc`, `sexo`, `estadoCivil`, `profissao`, `idEscola` | Perfil pessoal | Média |
| `rua`, `numero`, `bairro`, `cidade`, `uf`, `cep` | Endereço | Média |
| `tel`, `celular`, `email` | Contato | Média |
| `batismo`, `dataIngresso`, `idCargo`, `idStatusMinistro` | Vida eclesiástica | **Sensível (art. 5º, II — convicção religiosa)** |
| `senha` (hash legado — coluna aparentemente redundante com `login.senha`) | Credencial | **Alta — verificar se ainda é usada; se não, zerar/dropar** |

### `login`

| Coluna | Categoria | Criticidade |
|---|---|---|
| `email` | Contato/credencial | Média |
| `senha` | Hash Argon2id (MD5 legado bloqueado no login desde Fase 0.2) | Alta |
| `password_updated` | Flag migração | Baixa |

### `matriculaebd` (alunos, inclui menores em potencial)

| Coluna | Categoria | Criticidade |
|---|---|---|
| `nomeAluno`, `dataNasc` | Identificação, possível menor de idade | **Alta (art. 14 — dados de crianças/adolescentes)** |
| `visitante`, `statusMatricula`, datas | Vida eclesiástica | Sensível |

### Disciplina eclesiástica — `sindicancia`, `historicopunicao`, `situacao_membro`

`fato`, `parecer`, `apuracao`, `defesa`, `conclusao`, `motivo` (textos livres):
podem conter relatos de conduta, saúde, vida familiar — **potencialmente
sensíveis e difamatórios se vazados. Criticidade alta.** Acesso deve ser
restrito por perfil e auditado (Fase 5).

### Mensagens internas — `mensagem`, `mensagemenviada`

`assunto*`, `texto*` (mediumtext): conteúdo livre entre usuários; pode conter
qualquer categoria de dado. Criticidade média-alta. Retenção: definir prazo.

### Telemetria/segurança — `registrovisita`, `user_login`, `user_sessions`, `password_reset_*`, `registro_atividade`

| Dado | Observação |
|---|---|
| `ip`, `ip_address` | Dado pessoal (identificador online). Retenção sugerida: 6 meses (Marco Civil, art. 15 exige guarda de 6 meses de logs de acesso a aplicação). |
| `user_agent`, `username` (User-Agent em `registrovisita`) | Baixa |
| `email_hash`, `token_hash` | Já pseudonimizados — bom |

### Documentos anexos — `doc_membros` (`caminho_doc`)

Arquivos de documentos pessoais no filesystem. Verificar diretório e aplicar
mesmo gate de sessão usado em `Fotos/` (pendência Fase 0.4-bis).

## Decisões para a Fase 3 (criptografia de campo)

Cifrar com blind index: `cadastroministro.cpf`, `cadastroministro.identidade`.
Avaliar custo-benefício: `tel`, `celular`, endereço (quebra LIKE/relatórios).
Não cifrar campo a campo: nomes, datas de filtro, chaves de junção.

## Bases legais (resumo)

| Tratamento | Base legal |
|---|---|
| Cadastro e gestão de ministros/membros | Art. 7º, V (execução de contrato/estatuto) + art. 11, II, "a" |
| Credenciais e fichas eclesiásticas | Obrigação estatutária — documentar no estatuto |
| Logs de acesso (IP, sessão) | Art. 7º, II (obrigação legal — Marco Civil art. 15) e X (proteção ao crédito não se aplica; usar legítimo interesse art. 7º, IX para segurança) |
| EBD (alunos menores) | Art. 14 — consentimento específico de ao menos um dos pais/responsável |

## Pendências

- [ ] Confirmar se `cadastroministro.senha` ainda é lida em algum fluxo; zerar coluna.
- [ ] Renomear arquivos de foto para não usar CPF como nome (Fase 3).
- [ ] Gate de sessão para diretório de `doc_membros.caminho_doc`.
- [ ] Definir prazos de retenção por tabela (mensagens, logs, desligados).
- [ ] Nomear encarregado (DPO) e publicar política de privacidade (Fase 4).
