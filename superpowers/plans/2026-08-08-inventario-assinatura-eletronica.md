# Inventário de Assinatura Eletrônica — CONIECP e IECP

> **Para agentes:** este documento é a referência atual do serviço de assinatura eletrônica dos documentos. Antes de alterar ou ampliar o fluxo, confira os tipos documentais, os arquivos responsáveis e as lacunas registradas aqui.

**Objetivo:** registrar quais documentos possuem integração atualmente implementada com `autenticador_doc` e relacionar os arquivos envolvidos no cadastro, ativação, geração do PDF e consulta pública.

**Arquitetura:** a aplicação registra o documento em `autenticador_doc` quando ele é ativado. O gerador do PDF consulta esse registro, adiciona o assinante, a data e o QR Code de verificação, grava o PDF final e calcula os metadados de integridade. A validação pública ocorre pelo código/QR Code no módulo `autenticador/`.

**Tecnologias:** PHP, PDO/MySQL, mPDF, QR Code `chillerlan`, JavaScript/jQuery e WAMP.

## Critério de implementação

Um documento é considerado implementado quando o fluxo possui as duas partes:

1. cadastro/ativação que chama `AutenticadorDoc::inserir()`;
2. geração do PDF que consulta `autenticador_doc`, exibe a evidência de assinatura e salva o PDF final.

O serviço é uma assinatura eletrônica interna com evidência, QR Code e digest SHA-256. Ele não representa, por si só, uma assinatura com certificado digital ICP-Brasil.

## Tipos documentais implementados

| Organização | Documento | `tipo_doc` | `id_tipo_doc` | Emissor |
| --- | --- | --- | ---: | --- |
| CONIECP | Portaria | `portaria` | 1 | `0` |
| CONIECP | Edital | `edital_coniecp` | 2 | `0` |
| IECP Matriz | Edital | `edital_matriz` | 3 | `0` |
| CONIECP | Ofício | `oficio_coniecp` | 4 | `0` |
| IECP | Ofício | `oficio_iecp` | 6 | `$idIecp` |
| CONIECP | Notificação | `notificacao_coniecp` | 11 | `0` |
| IECP | Notificação | `notificacao_iecp` | 12 | `$idIecp` |
| CONIECP | Circular | `circular_coniecp` | 15 | `0` |

## Arquivos compartilhados

- `classes/AutenticadorDoc.class.php` — gera o código público, insere o registro, consulta o autenticador e salva o PDF com SHA-256, tamanho, MIME e data de finalização.
- `classes/getAssinanteDocInfo.php` — consulta assinatura da CONIECP e da IECP Matriz e fornece dados de fallback do assinante histórico.
- `classes/getAssinanteDocInfoIecp.php` — consulta assinatura das IECPs e fornece dados do dirigente da época.
- `classes/PegarPresidenteIecpDataEspecifica.php` — consulta o dirigente histórico usado pelo fluxo IECP.
- `classes/Connect.php` — conexão PDO compartilhada.
- `autenticador/index.php` — interface pública de consulta e comparação.
- `autenticador/aut.php` — consulta o PDF original pelo código.
- `autenticador/comparar.php` — compara um PDF recebido sem armazená-lo.
- `autenticador/erro.php` — resposta de erro do autenticador.
- `autenticador/rate_limit.php` — controle de tentativas e bloqueio.
- `autenticador/auntenticador.js` e `css/auntenticador.css` — interface do autenticador.
- `sql/migrate_autenticador_documentos_20260808.php` — migração, índices, aliases e campos de integridade do autenticador.

## Arquivos por documento

### CONIECP — Portaria

**Estado de validação (2026-08-08):** implementação em endurecimento e
referência técnica candidata, mas **ainda não é referência validada para os
demais documentos**. Foram executadas verificações estáticas locais; a suíte
integrada depende de `SISCONIECP_TEST_DSN` e o roteiro WAMP, a consulta pública
e a comparação de PDF ainda aguardam execução registrada. Consulte
`docs/operacao/checklist-validacao-portaria.md` antes de replicar o fluxo.

- `coniecp/portaria/cadastrarPortaria.php`
- `coniecp/portaria/cadastrarPortariaAcao.php`
- `coniecp/portaria/js/cadastrarPortaria.js`
- `coniecp/portaria/consultarPortaria.php`
- `coniecp/portaria/js/consultarPortaria.js`
- `coniecp/portaria/pdf/gerarPdfPortaria.php`
- `tests/portaria/portaria_assinatura_test.php` — cenários de aceitação com fixtures `TEMPORARY`, exclusivos para o banco dedicado `sisconiecp_test`; não grava tabelas, dados ou contadores `AUTO_INCREMENT` persistentes.
- `tests/portaria/README.md` — requisito de isolamento, permissões locais mínimas e comandos de configuração e execução da suíte de Portaria.

### CONIECP — Edital

- `coniecp/edital/cadastrarEdital.php`
- `coniecp/edital/cadastrarEditalAcao.php`
- `coniecp/edital/js/cadastrarEdital.js`
- `coniecp/edital/verEdital.php`
- `coniecp/edital/js/verEdital.js`
- `coniecp/edital/pdf/gerarPdfEdital.php`
- `coniecp/edital/pdf/verificaDoc_aut.php` — rotina auxiliar/legada de consulta.

### IECP Matriz — Edital

- `coniecp/edital_iecp_matriz/cadastrarEdital.php`
- `coniecp/edital_iecp_matriz/cadastrarEditalAcao.php`
- `coniecp/edital_iecp_matriz/js/cadastrarEdital.js`
- `coniecp/edital_iecp_matriz/verEdital.php`
- `coniecp/edital_iecp_matriz/js/verEdital.js`
- `coniecp/edital_iecp_matriz/pdf/gerarPdfEdital.php`

### CONIECP — Ofício

- `coniecp/oficio/cadastrarOficio.php`
- `coniecp/oficio/cadastrarOficioAcao.php`
- `coniecp/oficio/js/cadastrarOficio.js`
- `coniecp/oficio/consultarOficio.php`
- `coniecp/oficio/js/consultaOficio.js`
- `coniecp/oficio/pdf/gerarPdfOficio.php`

### CONIECP — Notificação

- `coniecp/notificacao/cadastrarNotificacao.php`
- `coniecp/notificacao/cadastrarNotificacaoAcao.php`
- `coniecp/notificacao/js/cadastrar.js`
- `coniecp/notificacao/notificacao.js`
- `coniecp/notificacao/verNotificacao.php`
- `coniecp/notificacao/verNotificacao.js`
- `coniecp/notificacao/verDoc.php`
- `coniecp/notificacao/js/verDoc.js`
- `coniecp/notificacao/pdf/gerarPdf.php`

### CONIECP — Circular

- `coniecp/circular/cadastrarCircular.php`
- `coniecp/circular/cadastrarCircular.js`
- `coniecp/circular/cadastrarCircularAcao.php`
- `coniecp/circular/js/cadastrar.js`
- `coniecp/circular/verCircular.php`
- `coniecp/circular/verCircular.js`
- `coniecp/circular/verDoc.php`
- `coniecp/circular/js/verDoc.js`
- `coniecp/circular/pdf/gerarPdfCircular.php`

### IECP — Ofício

- `iecp/oficio/oficioIecp.php`
- `iecp/oficio/cadastrarOficioAcao.php`
- `iecp/oficio/js/cadastrarOficio.js`
- `iecp/oficio/js/oficioIecp.js`
- `iecp/oficio/consultarOficio.php`
- `iecp/oficio/consultarOficioConiecp.php`
- `iecp/oficio/js/consultaOficio.js`
- `iecp/oficio/pdf/gerarPdfOficioIecp.php`

### IECP — Notificação

- `iecp/notificacao/cadastrar.php`
- `iecp/notificacao/cadastrarAcao.php`
- `iecp/notificacao/js/cadastrar.js`
- `iecp/notificacao/ver.php`
- `iecp/notificacao/js/ver.js`
- `iecp/notificacao/pdf/gerarPdf.php`

## Módulos que não devem ser tratados como implementados

- `coniecp/ata/`, `coniecp/ata_iecp_matriz/` e `coniecp/ataReuniao/` exibem textos sobre assinatura, mas não possuem fluxo completo de inserção em `autenticador_doc` e finalização do PDF.
- `iecp/edital/edital_iecp/` instancia `AutenticadorDoc` e envia `assinadoPor` pela interface, mas a ação não chama o autenticador e o gerador de PDF não consulta nem grava `autenticador_doc`.
- Certificados, cartas e anexos de membros não fazem parte desse serviço de assinatura documental.

## Regras para futuras alterações

- Preservar os identificadores `tipo_doc`, `id_tipo_doc`, `emissor` e `id_doc`.
- Não criar um segundo registro para o mesmo documento lógico.
- Manter o PDF final protegido contra sobrescrita depois de salvo.
- Alterações em um tipo documental devem atualizar a ação de ativação, a tela/JavaScript correspondente, o gerador de PDF e os testes do autenticador.
- Qualquer novo tipo deve ser incluído neste inventário antes de ser considerado parte do serviço.

## Validação de referência

Para conferir a implementação de um tipo, procurar no action correspondente por `new AutenticadorDoc()` e `->inserir()`, e no gerador por `SELECT ... FROM autenticador_doc` ou `salvarPdfAutenticado()`. A validação sintática dos arquivos PHP alterados deve usar `php -l`; alterações JavaScript devem usar `node --check`; e o conjunto deve ser verificado com `git diff --check`.

Para que a Portaria se torne a referência endurecida, o checklist operacional
deve estar integralmente concluído, incluindo suíte com banco descartável,
roteiro WAMP, consulta pública e comparação de integridade. A referência não
deve ser atribuída com base apenas em validações estáticas.
