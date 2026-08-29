# Plano de Confirmação de Notificações Multicanal

> **Status:** Fase 1 implementada no código; migração e validação autenticada pendentes.
>
> **Escopo:** notificações CONIECP para IECPs, usuários do sistema e membros,
> com confirmação pelo portal, e-mail, entrega pessoal, assinatura de ciente e
> testemunhas.

## Objetivo

Criar um fluxo único e auditável para publicação, entrega e confirmação de
notificações, sem confundir:

- envio técnico da mensagem;
- entrega pelo canal;
- visualização do conteúdo;
- declaração explícita de ciência;
- assinatura de recebimento ou de ciente;
- recusa, ausência ou não localização do destinatário.

O sistema deve permitir que o CONIECP saiba quem recebeu, quem tomou ciência,
por qual meio, em qual versão do documento e com qual evidência.

## Diagnóstico atual

O repositório possui confirmação de circular por IECP em
`statusconvocacao_circular`. Essa estrutura não representa confirmação de
notificação.

As telas atuais de notificação permitem cadastrar, ativar, consultar e gerar
documentos, mas não possuem destinatários individualizados nem fluxo de
ciência. O link antigo de confirmação dentro do menu de Notificação apontava
para o fluxo de circular e foi removido. O link de confirmação da Circular
continua separado.

A assinatura existente em `AutenticadorDoc` autentica o documento emitido e
seu PDF público. Ela não deve ser reutilizada como se fosse a assinatura de
ciência do destinatário. São evidências com finalidades diferentes.

## Princípios de domínio

1. Uma notificação oficial é o documento canônico; os destinatários são
   registros relacionados a ela.
2. O estado da notificação não pode substituir o estado de cada destinatário.
3. Abrir ou visualizar não significa confirmar ciência.
4. `entregue`, `ciente`, `recusado` e `não localizado` são estados diferentes.
5. A confirmação deve apontar para uma versão imutável do conteúdo apresentado.
6. A ciência institucional e a ciência pessoal têm regras diferentes.
7. A evidência física precisa ser registrada sem afirmar validade jurídica que
   ainda não tenha sido aprovada pelo responsável jurídico ou administrativo.
8. Todas as regras críticas devem ser aplicadas no servidor, nunca somente na
   interface.

## Públicos e cenários

### 1. Notificação destinada a uma IECP

**Unidade de ciência:** a IECP.

Fluxo padrão:

1. O CONIECP cria a notificação e seleciona as IECPs destinatárias.
2. O sistema materializa uma pendência por IECP no momento da publicação.
3. Um usuário autorizado daquela IECP acessa a notificação autenticado.
4. A tela exibe origem, assunto, data, prazo, documento e regra de ciência.
5. O representante seleciona `Confirmar ciência`.
6. O sistema registra IECP, usuário responsável, data, hora, versão e canal.
7. Os demais usuários da IECP passam a ver que a ciência institucional já foi
   registrada, sem poder alterar o responsável ou a data.

Regra recomendada: uma ciência por IECP. Se uma comunicação exigir ciência de
cada dirigente, ela deve ser publicada como notificação pessoal para usuários,
e não como ciência institucional.

### 2. Notificação destinada a usuários do sistema

**Unidade de ciência:** a conta do usuário.

Fluxo padrão:

1. O administrador seleciona usuários, perfis ou grupos autorizados.
2. O sistema cria uma pendência individual para cada usuário elegível.
3. A pendência aparece no menu, na caixa de entrada e, opcionalmente, por
   e-mail auxiliar.
4. O usuário visualiza a versão publicada.
5. A leitura não encerra a pendência.
6. O usuário confirma ciência individualmente.

Se o usuário estiver em mais de um grupo, continua existindo somente uma
ciência por conta. Mudanças de grupo posteriores não devem apagar a evidência
da publicação original.

### 3. Notificação destinada a membros por e-mail

**Unidade de entrega:** endereço de e-mail individualizado.

O sistema deve separar os estados `enfileirado`, `enviado`, `entregue`,
`devolvido`, `falha` e `link acessado`.

Para registrar ciência explícita:

- usar link individual, assinado e de uso único;
- armazenar somente o hash do token;
- aplicar expiração, revogação e limite de tentativas;
- não incluir CPF, matrícula ou outros dados pessoais na URL;
- exigir login, OTP ou outro fator adicional quando a comunicação for sensível.

Sem autenticação adicional, a confirmação deve ser descrita como controle do
canal de e-mail, não como prova forte da identidade do membro. A abertura por
pixel não deve ser considerada ciência.

### 4. Entrega pessoal

**Unidade de entrega:** destinatário identificado no ato da entrega.

A entrega pessoal deve ser uma modalidade explícita da notificação, e não uma
alteração manual escondida no relatório.

O responsável registra:

- destinatário e organização, quando aplicável;
- notificação e versão entregue;
- data, hora e local;
- pessoa que realizou a entrega;
- meio de identificação permitido pela política interna;
- situação: `entregue`, `ciente`, `recusado` ou `não localizado`;
- observação operacional segura;
- anexo do comprovante, quando existir.

`Entregue` não deve ser convertido automaticamente em `ciente`. Se o
destinatário se recusar a assinar, o sistema registra a recusa e seu motivo,
sem criar uma falsa confirmação.

### 5. Assinatura de ciente

A assinatura de ciente é uma declaração do destinatário, diferente da
assinatura do emissor do documento.

Modalidades previstas:

- assinatura eletrônica autenticada pelo portal;
- assinatura eletrônica com reautenticação ou OTP para documentos sensíveis;
- assinatura física em termo impresso, com digitalização do comprovante;
- assinatura em dispositivo presencial, se houver suporte operacional aprovado.

O sistema deve guardar o método, o ator, a data, a hora, a versão do conteúdo,
o identificador da evidência e o hash do arquivo anexado quando houver. A
imagem isolada de uma assinatura não deve ser tratada como evidência suficiente
sem o evento, o contexto e a vinculação ao documento.

### 6. Entrega com testemunhas

Testemunhas devem ser uma opção configurável por tipo de notificação ou por
publicação, não uma exigência indiscriminada.

Quando exigidas:

1. O responsável informa o destinatário e as testemunhas antes da finalização.
2. O servidor valida que testemunha, entregador e destinatário são pessoas
   distintas, conforme a regra aprovada.
3. Cada testemunha assina ou é identificada no termo correspondente.
4. O sistema registra data, hora, local, método, versão do documento e ordem
   dos eventos.
5. O comprovante físico ou eletrônico é fechado, recebe hash e não pode ser
   sobrescrito.

O relatório deve distinguir `ciente com testemunhas`, `recusado com
testemunhas` e `não localizado com testemunhas`. A presença de testemunhas
não deve transformar ausência ou recusa em ciência.

## Modelo funcional proposto

Manter `notificacao` como documento principal e criar uma camada de
destinatários e evidências. Os nomes abaixo são propostas e não representam
DDL aprovado:

```text
notificacao
  └── notificacao_destinatario
        ├── notificacao_entrega
        ├── notificacao_ciencia
        ├── notificacao_testemunha
        └── notificacao_evento
```

### `notificacao_destinatario`

Deve registrar o tipo de destinatário (`iecp`, `usuario` ou `membro`), o
identificador validado no servidor, o canal, a obrigatoriedade, o prazo e a
situação atual.

Deve existir uma restrição lógica para impedir duplicidade da mesma
notificação, destinatário e canal. A implementação deve validar a relação em
PHP e não depender de `CHECK` em MySQL 5.7.

### `notificacao_entrega`

Registra tentativas por portal, e-mail ou entrega pessoal, incluindo resultado,
data, operador e erro técnico seguro. Reenvio cria nova tentativa sem apagar o
histórico anterior.

### `notificacao_ciencia`

Registra declaração de ciência, método, ator, data, hora, versão/hash do
documento e vínculo com a evidência eletrônica ou física.

### `notificacao_testemunha`

Registra as testemunhas e sua participação no evento presencial. O desenho
final deve definir quais dados pessoais são estritamente necessários, prazo de
retenção e forma de consulta.

### `notificacao_evento`

Registra transições relevantes: criação, publicação, alteração bloqueada,
entrega, visualização, ciência, recusa, não localização, reenvio, contestação,
cancelamento e arquivamento.

## Máquina de estados

O documento e o destinatário terão estados independentes.

```text
Documento:
rascunho → publicado → encerrado
              └──────→ cancelado

Destinatário:
pendente → enfileirado → enviado → entregue → visualizado → ciente
    ├──────────────→ falha/devolvido
    ├──────────────→ recusado
    ├──────────────→ não localizado
    └──────────────→ expirado
```

Os estados de entrega e de ciência não devem ser comprimidos em uma coluna
genérica de `status`.

## Interfaces previstas

### Administração

1. Editor atual da notificação.
2. Seleção de público e canal.
3. Opção `Exige confirmação de ciência`.
4. Opção `Exige entrega pessoal`.
5. Opção `Exige assinatura de ciente`.
6. Opção `Exige testemunhas` e quantidade mínima.
7. Prazo, prévia de destinatários e validação de e-mails.
8. Confirmação de publicação com resumo das regras.
9. Relatório com filtros por público, canal, situação, prazo e evidência.

### Destinatário

- lista de pendências;
- identificação clara de prazo e obrigatoriedade;
- documento na versão publicada;
- ação explícita de ciência;
- comprovante após a confirmação;
- indicação do responsável quando a ciência for institucional.

### Operação presencial

- seleção da notificação publicada;
- identificação do destinatário;
- registro de entrega;
- coleta da assinatura de ciente;
- inclusão das testemunhas, quando exigidas;
- anexação e fechamento do termo;
- geração de comprovante para consulta autorizada.

## Segurança, privacidade e integridade

- autorização por papel e escopo de IECP no servidor;
- CSRF nas ações de publicação, ciência, recusa e registro presencial;
- reautenticação para ciência de alto risco;
- tokens de e-mail armazenados por hash, com uso único e expiração;
- rate limit para links de confirmação;
- nenhuma confiança em IDs de destinatário enviados pelo navegador;
- conteúdo confirmado congelado por versão ou digest;
- anexos protegidos contra acesso público, path traversal e sobrescrita;
- logs sem tokens, senhas, documentos completos ou dados pessoais desnecessários;
- política de retenção específica para comprovantes e testemunhas;
- registro de contestação e correção como novo evento, sem apagar o histórico.

## Compatibilidade e restrições de banco

Não executar migração automaticamente como parte deste plano.

Antes de criar tabelas ou índices, consultar o schema de produção, a versão
MySQL 5.7 e os relacionamentos efetivamente usados pelo legado. A tabela atual
`notificacao` é legada e usa MyISAM; portanto, uma futura operação que escreva
nela e em novas tabelas não poderá ser descrita como atomicamente transacional
sem resolver essa limitação.

Não usar CTE, funções de janela, `CHECK` como regra de negócio ou sintaxe
exclusiva do MySQL 8.

## Fases de implementação

### Fase 0: decisões de negócio e evidência

- [ ] Aprovar o significado operacional de `ciente`.
- [ ] Definir quando a ciência institucional basta.
- [ ] Definir tipos que exigem assinatura, entrega pessoal ou testemunhas.
- [ ] Definir política para recusa, ausência, contestação e reentrega.
- [ ] Definir retenção de assinaturas, termos e identificadores.
- [ ] Validar o texto dos comprovantes com responsável jurídico/administrativo.

### Fase 1: confirmação de IECP pelo portal

- [x] Criar o modelo de destinatário e ciência.
- [x] Materializar pendências na publicação.
- [x] Criar tela de pendências e confirmação.
- [x] Criar relatório administrativo.
- [x] Reutilizar padrões da confirmação de circular sem reutilizar sua tabela.
- [ ] Testar escopo de acesso entre IECPs.

**Implementação local registrada:** `classes/NotificacaoCienciaService.php`,
`sql/migrate_notificacao_ciencia_20260823.php`, os endpoints de recebimento e
relatório, e os menus de CONIECP/IECP. A migração ainda deve ser executada
explicitamente no banco local controlado antes do roteiro autenticado.

### Fase 2: confirmação individual de usuários

- [ ] Resolver destinatários por usuário e grupo.
- [ ] Criar contador e caixa de entrada.
- [ ] Implementar ciência individual.
- [ ] Tratar usuário desativado, duplicidade e alteração de grupo.

### Fase 3: entrega por e-mail para membros

- [ ] Confirmar infraestrutura de envio e fila disponível.
- [ ] Implementar tentativas, entrega, devolução e reenvio.
- [ ] Implementar link seguro de ciência.
- [ ] Definir quando exigir login ou OTP.
- [ ] Tratar e-mail ausente, inválido, alterado ou compartilhado.

### Fase 4: entrega pessoal, assinatura e testemunhas

- [ ] Criar fluxo de registro presencial.
- [ ] Criar termo de ciência com versão imutável.
- [ ] Implementar assinatura eletrônica ou anexação de assinatura física,
  conforme modalidade aprovada.
- [ ] Implementar testemunhas e validação de participantes distintos.
- [ ] Fechar o comprovante com hash e trilha de auditoria.
- [ ] Implementar recusa, ausência, reentrega e contestação.

### Fase 5: endurecimento e operação

- [ ] Executar testes de autorização, CSRF, replay de token e acesso a anexos.
- [ ] Validar responsividade, teclado, foco e mensagens de erro/sucesso.
- [ ] Testar estados pendente, vazio, falha, bloqueado, expirado e concluído.
- [ ] Testar com banco isolado e confirmar compatibilidade MySQL 5.7.
- [ ] Executar roteiro autenticado no WAMP para portal, e-mail e operação
  presencial simulada.
- [ ] Documentar procedimento operacional e suporte.

## Critérios de aceite

- Uma notificação publicada gera destinatários corretos e não duplicados.
- IECPs não conseguem consultar ou confirmar pendências de outra IECP.
- Visualização não altera ciência automaticamente.
- Cada ciência identifica ator, método, data, hora e versão do conteúdo.
- E-mail entregue, e-mail aberto e ciência explícita aparecem separadamente.
- Recusa e não localização não aparecem como ciência.
- Testemunhas não podem ser o destinatário nem o entregador quando a regra
  exigir participantes distintos.
- Um comprovante finalizado não pode ser sobrescrito silenciosamente.
- O relatório permite localizar pendências, confirmações e evidências.
- O fluxo preserva as rotas atuais de notificação e não reativa o link de
  circular dentro do menu de Notificação.

## Não escopo inicial

- Não transformar a assinatura de ciência em assinatura ICP-Brasil.
- Não declarar validade jurídica automática para assinatura física, eletrônica
  ou testemunhas.
- Não enviar notificações em massa antes de existir controle de fila, falha e
  reprocessamento.
- Não modificar a tabela `notificacao` ou executar DDL sem plano de migração,
  backup, dry-run e autorização explícita.
