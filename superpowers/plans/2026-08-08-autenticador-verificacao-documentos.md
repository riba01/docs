Antes# Autenticador de Documentos — Plano de Verificação e Imutabilidade

> **Para agentes de implementação:** usar `superpowers:subagent-driven-development` ou `superpowers:executing-plans` para executar este plano tarefa por tarefa. Cada etapa usa checkbox para acompanhamento.

**Objetivo:** manter a consulta rápida por QR Code/código e transformá-la em uma verificação confiável do documento original armazenado, com caminhos claros para documentos digitais e impressos.

**Arquitetura:** o autenticador terá exatamente um registro por `(tipo_doc, emissor, id_doc)`. Esse registro terá um código público de consulta, separado do SHA-256 do PDF final, e poderá possuir versões controladas sem duplicar a identidade do documento. A consulta pública continuará retornando o arquivo canônico, mas também exibirá metadados, status e evidência de integridade. Upload será opcional e servirá para comparar um PDF digital; para papel, a validação será feita por QR/código mais comparação visual com o original.

**Tecnologias:** PHP procedural existente, PDO/MySQL, JavaScript/jQuery legado durante a transição, PDF gerado por mPDF, QR Code já utilizado no projeto.

## Restrições globais

- Não remover a consulta rápida por QR Code ou código impresso.
- Não quebrar os códigos MD5 já impressos em documentos antigos.
- O PDF final precisa ser gerado antes do cálculo do digest de integridade.
- A validação do servidor não pode depender de JavaScript ou captcha client-side.
- Acesso público deve permitir consulta, mas não alteração do documento canônico.
- Alteração, revogação e substituição devem ser eventos auditáveis, não sobrescritas silenciosas.
- Deve existir uma única linha para cada combinação `(tipo_doc, emissor, id_doc)`.
- Reativação ou nova assinatura do mesmo documento deve atualizar o registro existente ou criar uma versão relacionada, nunca inserir uma segunda identidade do documento.
- Não armazenar novos segredos no código-fonte; as credenciais atuais de banco devem ser rotacionadas antes da publicação.

---

## 1. Decisão de produto: como cada pessoa validará

### 1.1 Documento digital recebido

Fluxo recomendado:

1. A pessoa abre o QR Code ou acessa a URL de verificação.
2. O sistema mostra “Documento localizado” e os dados do registro: tipo, número, emissor, assinante, data, versão e status.
3. O sistema oferece o botão “Abrir PDF original armazenado”.
4. Opcionalmente, a pessoa envia o PDF recebido para “Comparar arquivo digital”.
5. O servidor calcula o SHA-256 do upload e informa uma destas situações:

    - “Arquivo idêntico ao original armazenado”;
    - “Código válido, mas o arquivo enviado é diferente”; ou
    - “Documento não localizado”.

O upload não substitui o QR Code. Ele apenas responde se o arquivo digital recebido é byte a byte igual ao PDF canônico.

### 1.2 Documento impresso

Fluxo recomendado:

1. A pessoa escaneia o QR Code impresso com o celular.
2. Se não puder escanear, digita o código de verificação impresso.
3. O sistema apresenta o PDF original armazenado e os metadados oficiais.
4. A pessoa compara o papel com o original exibido.
5. O sistema informa claramente: “O código pertence a este documento. A conferência do conteúdo impresso deve ser feita comparando-o com o original exibido.”

O QR Code sozinho não prova que o papel não foi editado depois da impressão. Para aumentar a resistência contra adulteração, o documento deve exibir o código em área visível, número da página, versão e, quando possível, QR Code em todas as páginas ou ao menos na primeira e última página.

### 1.3 Documento fotografado ou digitalizado

Não comparar a imagem ou o PDF escaneado como se fosse o PDF original. Impressão, scanner e OCR alteram os bytes.

Esse caso deve oferecer apenas:

- consulta pelo QR Code/código;
- comparação visual assistida; e
- eventual OCR para auxiliar a conferência, sem declarar igualdade criptográfica.

## 2. O que a implementação atual realmente garante

- `autenticador/aut.php` faz uma consulta parametrizada e retorna `doc_pdf` como PDF inline.
- A consulta pública não altera o registro.
- O código chamado de MD5 é criado a partir do conteúdo de origem mais data/hora, não do PDF final.
- Não existe, no fluxo analisado, comparação entre o PDF retornado e um digest armazenado.
- `AutenticadorDoc::salvarPdfAutenticado()` possui operação de `UPDATE` no PDF e nome do arquivo.
- Geradores como `coniecp/portaria/pdf/gerarPdfPortaria.php` também atualizam `doc_pdf` e `nome_doc`.
- O schema atual possui `UNIQUE(numero_doc)`, mas não possui unicidade para `(tipo_doc, emissor, id_doc)`.
- A base local já contém três combinações duplicadas de `(tipo_doc, emissor, id_doc)`, incluindo casos em que uma linha tem PDF preenchido e outra está nula.

Conclusão: no fluxo normal, o arquivo é gravado quando existe assinatura e `doc_pdf` ainda está vazio; depois é servido do banco sem nova gravação. Porém, a identidade do documento não é única no schema atual, e a imutabilidade não está comprovada no banco. Um usuário com permissão administrativa, uma rotina de regeneração, uma credencial de banco ou uma alteração SQL ainda pode substituir o PDF.

“Imutável” deve ser tratado em três níveis:

1. **Imutabilidade de interface:** a consulta pública só lê.
2. **Imutabilidade de aplicação:** depois da finalização, o código não permite sobrescrever o PDF; uma correção gera nova versão.
3. **Imutabilidade verificável:** o digest ou assinatura detecta qualquer alteração, inclusive alteração direta no banco.

O objetivo do plano é alcançar os três níveis. Imutabilidade física absoluta não pode ser prometida a quem controla o servidor ou o banco; o sistema pode oferecer controle de acesso, trilha de auditoria e evidência criptográfica de adulteração.

## 3. Modelo de dados proposto

### 3.1 Separar identidade pública e integridade

Adicionar ao registro final, ou a uma tabela de versões relacionada, campos equivalentes a:

```sql
verification_token VARBINARY(32) NOT NULL UNIQUE,
legacy_md5         CHAR(32) NULL,
pdf_sha256         CHAR(64) NOT NULL,
pdf_size           BIGINT UNSIGNED NOT NULL,
mime_type          VARCHAR(100) NOT NULL DEFAULT 'application/pdf',
status             ENUM('valid','revoked','superseded') NOT NULL DEFAULT 'valid',
version            INT UNSIGNED NOT NULL DEFAULT 1,
finalized_at       DATETIME NOT NULL,
revoked_at         DATETIME NULL,
revoked_reason     VARCHAR(500) NULL
```

O nome exato deve respeitar o schema existente. O ponto essencial é não reutilizar `numero_doc` MD5 como prova de integridade e adicionar a restrição de negócio:

```sql
UNIQUE KEY uq_autenticador_documento (tipo_doc, emissor, id_doc)
```

O `numero_doc` legado continua único para preservar os QR Codes antigos, mas não substitui a unicidade do documento lógico.

### 3.2 Token público

Gerar o token com fonte criptograficamente segura:

```php
$token = bin2hex(random_bytes(32));
```

O token identifica o registro público. Ele não precisa ser o digest do arquivo.

### 3.3 Digest do PDF

Depois de o PDF final ser produzido:

```php
$pdfSha256 = hash('sha256', $pdfContent);
```

O digest deve ser calculado sobre exatamente os bytes armazenados em `doc_pdf`.

### 3.4 Versões e revogação

Não sobrescrever o PDF finalizado. Alteração do conteúdo deve:

1. criar nova versão;
2. gerar novo PDF;
3. gerar novo digest;
4. manter o histórico anterior;
5. marcar a versão antiga como `superseded` ou `revoked`;
6. registrar quem, quando e por qual motivo fez a operação.

## 4. Plano de implementação

### Tarefa 1: inventariar todos os escritores do documento canônico

**Arquivos:**

- Inspecionar: `autenticador/aut.php`
- Inspecionar: `classes/AutenticadorDoc.class.php`
- Inspecionar: `classes/Connect.php`
- Inspecionar: `coniecp/portaria/pdf/gerarPdfPortaria.php`
- Inspecionar: demais geradores que fazem `UPDATE autenticador_doc`
- Consultar: schema real da tabela `autenticador_doc`

- [ ] Listar todos os pontos que inserem ou atualizam `doc_pdf`, `nome_doc` e `numero_doc`.
- [ ] Identificar se existem índices únicos e permissões separadas para leitura e escrita.
- [ ] Confirmar e documentar os registros duplicados atuais antes de qualquer migração.
- [ ] Identificar documentos antigos sem PDF armazenado, sem digest ou sem status.
- [ ] Definir a regra de migração dos registros legados.

**Validação:** produzir uma matriz com cada gerador, tipo de documento, momento da finalização e operação SQL utilizada.

### Tarefa 2: proteger segredos e acesso ao armazenamento

**Arquivos:**

- Modificar: `classes/Connect.php`
- Verificar: configurações de produção fora do repositório
- Verificar: permissões do usuário MySQL

- [ ] Rotacionar as credenciais atuais do banco.
- [ ] Remover credenciais hardcoded de `Connect.php`.
- [ ] Carregar host, usuário, banco e senha de variáveis de ambiente ou arquivo fora da raiz pública.
- [ ] Criar usuário de banco de leitura para `autenticador/aut.php` quando a infraestrutura permitir.
- [ ] Garantir que o usuário público não tenha `INSERT`, `UPDATE` ou `DELETE` na tabela canônica.

**Validação:** confirmar que a consulta pública continua funcionando e que o usuário de leitura não consegue modificar um documento.

### Tarefa 3: implementar finalização, digest e versões

**Arquivos:**

- Modificar: `classes/AutenticadorDoc.class.php`
- Modificar: geradores de PDF que gravam `doc_pdf`
- Criar ou alterar: migração SQL da tabela `autenticador_doc`

- [ ] Gerar o PDF completo antes de persistir o registro final.
- [ ] Calcular `pdf_sha256` sobre os bytes finais.
- [ ] Gerar token público com `random_bytes()`.
- [ ] Bloquear `UPDATE` do PDF depois da finalização normal.
- [ ] Fazer alteração de conteúdo criar nova versão.
- [ ] Adicionar índice único ao token público.
- [ ] Adicionar índice único em `(tipo_doc, emissor, id_doc)`.
- [ ] Trocar os `INSERT`s de reativação/assinatura por atualização do registro existente ou por versão relacionada.
- [ ] Usar o `id` da linha autenticadora selecionada nos `UPDATE`s; não atualizar pelo trio lógico quando houver possibilidade de versões.
- [ ] Tornar a primeira gravação atômica para evitar duas requisições concorrentes sobrescreverem o mesmo registro.
- [ ] Preservar `numero_doc` para os documentos antigos durante a migração.

**Validação:** primeiro consolidar as três duplicidades atuais; depois confirmar que a criação do índice rejeita nova duplicidade, que duas requisições concorrentes resultam em uma única linha e que alterar um byte do PDF em ambiente de teste faz o digest deixar de coincidir.

### Tarefa 4: criar a resposta de verificação

**Arquivos:**

- Modificar: `autenticador/aut.php`
- Modificar ou criar: `autenticador/index.php`
- Modificar: `autenticador/erro.php`
- Criar: template de resultado do autenticador, se a estrutura atual exigir

- [ ] Aceitar token novo e código MD5 legado.
- [ ] Validar formato no servidor.
- [ ] Consultar somente documentos com status adequado.
- [ ] Exibir status, emissor, tipo, assinante, data, versão e digest.
- [ ] Disponibilizar o PDF original armazenado.
- [ ] Não declarar que um PDF enviado é igual sem comparação SHA-256.
- [ ] Diferenciar “código válido, arquivo diferente”, “documento revogado” e “não encontrado”.

**Validação:** cobrir token válido, token inexistente, documento revogado, documento legado e arquivo ausente.

### Tarefa 5: adicionar upload opcional para PDFs digitais

**Arquivos:**

- Modificar: `autenticador/index.php`
- Criar: endpoint específico de comparação, por exemplo `autenticador/comparar.php`
- Criar: JavaScript específico do upload

- [ ] Aceitar apenas `POST` multipart.
- [ ] Limitar tamanho do arquivo.
- [ ] Validar MIME e assinatura inicial `%PDF-`.
- [ ] Não salvar permanentemente o upload do visitante.
- [ ] Calcular SHA-256 no servidor.
- [ ] Comparar somente com o digest da versão consultada.
- [ ] Remover o temporário após o processamento.
- [ ] Informar que scans e fotografias não permitem igualdade byte a byte.

**Validação:** comparar o PDF original, uma cópia byte a byte, um PDF reprocessado e um scan; somente a cópia idêntica deve retornar “arquivo idêntico”.

### Tarefa 6: manter e melhorar a consulta por papel

**Arquivos:**

- Modificar: `autenticador/index.php`
- Modificar: geradores de PDF que inserem QR Code e código
- Modificar: `autenticador/auntenticador.js`
- Modificar: `css/auntenticador.css`

- [ ] Manter QR Code e entrada manual como primeiro fluxo.
- [ ] Trocar o rótulo “HASH MD5” por “Código de verificação”.
- [ ] Mostrar o código em formato legível no PDF.
- [ ] Exibir instrução de que o papel deve ser comparado com o original retornado.
- [ ] Usar `type="submit"`, `required`, `maxlength` e padrão de formato.
- [ ] Remover a concatenação de HTML com entrada do usuário.
- [ ] Corrigir o erro de sintaxe existente no JavaScript.
- [ ] Adicionar estado de carregamento, erro inline, foco acessível e layout responsivo.
- [ ] Substituir o captcha client-side por rate limiting e, se ainda necessário, desafio validado no servidor.

**Validação:** testar QR Code, digitação manual, tecla Enter, celular, teclado sem mouse, leitor de tela e JavaScript indisponível.

### Tarefa 7: auditoria, abuso e cabeçalhos

**Arquivos:**

- Modificar: `autenticador/index.php`
- Modificar: `autenticador/aut.php`
- Avaliar: `header_security.php`
- Criar ou usar: serviço de auditoria já existente

- [ ] Aplicar CSP, `X-Content-Type-Options` e `Referrer-Policy` ao autenticador.
- [ ] Implementar rate limiting por IP e por código.
- [ ] Registrar consultas suspeitas sem gravar o token completo quando isso não for necessário.
- [ ] Definir `Content-Disposition` com nome de arquivo sanitizado.
- [ ] Definir política de cache para PDFs públicos ou sensíveis.
- [ ] Monitorar picos de consultas, códigos inexistentes e downloads repetidos.

**Validação:** realizar consultas repetidas e confirmar bloqueio progressivo, registro de evento e retorno sem detalhes internos do banco.

### Tarefa 8: migração e compatibilidade legada

**Arquivos:**

- Criar: migração SQL versionada
- Modificar: `autenticador/aut.php`
- Modificar: geradores de QR Code
- Modificar: rotinas de cadastro/reativação que chamam `AutenticadorDoc::inserir()`

- [ ] Fazer inventário das duplicidades por `(tipo_doc, emissor, id_doc)`.
- [ ] Escolher uma linha canônica por grupo, priorizando a que possui PDF preenchido e os metadados da assinatura válida.
- [ ] Preservar os códigos `numero_doc` antigos como aliases de compatibilidade ou registrar a política de redirecionamento.
- [ ] Transferir o PDF e os metadados necessários para a linha canônica.
- [ ] Registrar em auditoria quais linhas foram consolidadas.
- [ ] Somente depois da limpeza, criar `UNIQUE(tipo_doc, emissor, id_doc)`.
- [ ] Manter leitura dos MD5 existentes.
- [ ] Calcular e armazenar SHA-256 dos PDFs antigos já existentes.
- [ ] Associar token novo aos documentos migrados sem alterar o texto impresso.
- [ ] Reimprimir somente documentos novos ou versões substituídas.
- [ ] Marcar documentos antigos sem PDF ou sem metadados suficientes como “legado — conferência limitada”.

**Validação:** testar pelo menos um documento antigo de cada tipo, um documento novo e uma versão revogada.

## 5. Critérios para decidir se o sistema está pronto

- Uma pessoa com o documento impresso consegue validar pelo QR Code ou código manual.
- O sistema devolve o PDF original armazenado sem permitir alteração pela consulta pública.
- Um PDF digital idêntico é reconhecido pelo SHA-256.
- Um PDF visualmente parecido, mas alterado, é rejeitado como diferente.
- Um scan é identificado como “não comparável byte a byte”, sem falso positivo.
- Alteração direta no PDF armazenado é detectada pelo digest ou assinatura.
- Documentos revogados ou substituídos aparecem com status correto.
- O banco rejeita qualquer segunda linha com o mesmo `(tipo_doc, emissor, id_doc)`.
- Reativar ou assinar novamente um documento não cria uma nova linha autenticadora.
- O servidor rejeita entradas inválidas, excesso de consultas e uploads perigosos.
- Documentos antigos continuam consultáveis.
- A experiência funciona em celular, teclado e leitor de tela.

## Decisão recomendada

Manter a consulta rápida atual como fluxo principal, porque ela é adequada para documentos impressos e conferências ocasionais. Acrescentar upload apenas como recurso avançado para documentos digitais. A melhoria mais importante não é transformar todo usuário em alguém que precisa fazer upload; é fazer com que o PDF retornado seja um artefato canônico, versionado, com SHA-256 e status verificável.

Assim, o sistema continuará simples para quem recebeu um documento, mas passará a oferecer evidência técnica real de integridade para quem precisar de uma conferência mais rigorosa.
