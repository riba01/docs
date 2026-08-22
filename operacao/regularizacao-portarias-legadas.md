# Regularizacao controlada de Portarias legadas

Este procedimento se aplica somente a Portarias CONIECP em `Ativo` que ainda nao possuem a identidade `portaria/0/<idPortaria>` em `autenticador_doc`. Ele nao altera o texto, a numeracao, a data ou o status da Portaria. A regularizacao cria, de modo individual, o PDF canonico, o hash SHA-256, o codigo publico e o evento de auditoria.

## Responsabilidade e preparacao

1. Obtenha autorizacao explicita da diretoria CONIECP responsavel e registre os IDs aprovados. A pessoa que executa deve ser membro de uma diretoria CONIECP ativa; informe seu RM no argumento `--rm-autoridade` e confirme a credencial da mesma conta quando o programa solicitar a senha.
2. Gere um backup completo do banco, registre data, responsavel e local protegido do arquivo, e confirme que a restauracao foi testada ou aprovada pelo responsavel tecnico.
3. Execute o procedimento primeiro em um banco de teste com uma copia autorizada dos dados. Nao use `--apply` em producao para validar configuracao.
4. Antes de cada ID, compare o texto administrativo armazenado com o documento institucional aprovado. Defina se os campos historicos de assinador, cargo e funcao da Portaria sao a fonte correta. Se nao forem, corrija o registro administrativo pelo processo institucional antes de regularizar.

O PDF mostra o assinador historico armazenado na Portaria. A data da assinatura eletronica e a data/hora da regularizacao, em horario de Brasilia; ela nao declara retrospectivamente uma assinatura digital historica. Essa origem tambem fica registrada no evento `ATIVADA`.

## Relatorio sem gravacao

Execute:

```powershell
php sql/verificar_portarias_legadas.php --dry-run
```

O relatorio lista somente ID, numero, data, status e indicadores de autenticador/PDF. Nao exibe conteudo da Portaria nem dados pessoais do assinador. Este modo faz apenas consultas de leitura.

## Regularizacao individual

Para cada Portaria aprovada, na janela autorizada e apos o backup, execute um unico comando:

```powershell
php sql/verificar_portarias_legadas.php --apply=18 --confirmar=REGULARIZAR-PORTARIA-18 --rm-autoridade=123
```

Substitua `18` e `123` pelo ID aprovado e pelo RM da autoridade ativa. O token de confirmacao deve repetir exatamente o mesmo ID. Depois do comando, informe a senha dessa autoridade no prompt interativo. A senha nunca e aceita como argumento, variavel de ambiente, arquivo, pipe ou redirecionamento, e nao e gravada em auditoria ou log. O programa recusa `--apply` quando a entrada padrao nao e um terminal interativo. O programa nao aceita lista, intervalo, arquivo de IDs nem aplicacao em lote.

O comando consulta o hash da senha em `login` por statement preparado e usa `password_verify` antes de iniciar a regularizacao. Ele bloqueia a Portaria candidata durante a transacao, gera o PDF pelo `PortariaPdfRenderer`, finaliza o registro com `AutenticadorDoc::finalizarPdf` e registra `ATIVADA`. Se faltarem campos necessarios no snapshot, nao cria PDF e registra `REJEITADA` uma unica vez para aquela condicao. Qualquer outra falha faz rollback da identidade, do PDF e da auditoria.

## Conferencia posterior

1. Rode novamente o `--dry-run`; o ID regularizado nao deve mais aparecer como candidato.
2. Consulte `autenticador_doc` e confirme uma unica identidade `portaria/0/<idPortaria>`, `finalized_at` preenchido, PDF presente, `pdf_size` igual ao tamanho do blob e `pdf_sha256` igual ao SHA-256 do blob.
3. Abra o PDF administrativo e confira QR Code, numero da Portaria, assinador, data/hora da regularizacao e codigo publico.
4. Abra o codigo/QR no autenticador publico e confirme que entrega o mesmo PDF finalizado.
5. Registre no chamado operacional o ID, a autoridade (RM), a referencia do backup, a origem do assinador historico e o resultado da conferencia.

Nao execute novo `--apply` para um ID ja regularizado. Ele deixara de ser candidato e o comando falhara sem substituir o PDF canonico existente.
