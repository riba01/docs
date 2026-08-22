# Checklist operacional — assinatura eletrônica de Portaria

**Objetivo:** registrar a evidência necessária para promover a Portaria a
referência de assinatura eletrônica para Edital, Ofício, Notificação e Circular.
Este checklist não substitui a política institucional de assinatura, arquivamento
e regularização.

## Registro desta execução — 2026-08-08

| Verificação | Resultado | Evidência/limite |
| --- | --- | --- |
| Sintaxe PHP da camada Portaria, autenticador, migrações e suíte | Concluída | `php -l` aprovado em 19 arquivos locais envolvidos. |
| Sintaxe JavaScript das telas de Portaria | Concluída | `node --check` aprovado para cadastro e consulta. |
| Integridade do diff rastreado | Concluída | `git diff --check` retornou código 0; houve apenas aviso local de arquivo global de ignore inacessível. |
| Suíte integrada de Portaria | Bloqueada | `php tests/portaria/portaria_assinatura_test.php` retornou código 2 antes de conectar: `SISCONIECP_TEST_DSN` não configurado. |
| ESLint das telas | Bloqueada | `npx eslint` não iniciou: dependência local `@eslint/js` indisponível. |
| Roteiro WAMP, banco, QR, consulta pública e comparação | Não executado | Não houve sessão WAMP, banco de teste, URL pública ou browser automatizado disponíveis nesta execução. |

**Conclusão desta execução:** a Portaria permanece como referência técnica
candidata. Não está aprovada como referência endurecida até que os itens
operacionais pendentes tenham evidência registrada.

## Pré-requisitos para a execução integrada

- [ ] Banco descartável dedicado, com nome explicitamente autorizado para testes.
- [ ] `SISCONIECP_TEST_DSN`, usuário e senha de teste configurados somente no ambiente local.
- [ ] Schema e fixtures documentados, sem usar dados de produção.
- [ ] Conta CONIECP autorizada para o assinador e conta distinta para os cenários de recusa.
- [ ] `AUTENTICADOR_PUBLIC_URL` configurada para o ambiente de teste.
- [ ] Dependências JavaScript instaladas, incluindo `@eslint/js`.
- [ ] Backup confirmado antes de qualquer regularização de legado; não executar `--apply` em lote.

## Regressão integrada da Portaria

- [ ] Executar `php tests/portaria/portaria_assinatura_test.php` com `SISCONIECP_TEST_DSN` e registrar saída de sucesso.
- [ ] Criar rascunho e confirmar ausência de `autenticador_doc` e PDF canônico.
- [ ] Tentar ativar com outro RM, senha incorreta e CSRF inválido; confirmar recusa sem alteração persistida.
- [ ] Ativar com assinador autorizado e senha correta; confirmar PDF canônico, SHA-256, tamanho, `finalized_at`, auditoria e estado `Ativo` na mesma operação.
- [ ] Confirmar que erro de renderização/finalização preserva o snapshot anterior ou remove o novo rascunho transacional.
- [ ] Tentar alterar conteúdo/assinador de Portaria finalizada e confirmar rejeição; confirmar que arquivamento permanece permitido.

## Roteiro manual WAMP e verificador público

- [ ] Abrir o PDF administrativo autenticado e confirmar QR Code, assinador, data/hora em `America/Sao_Paulo`, código público e hash.
- [ ] Consultar o QR Code na página pública e confirmar que o PDF entregue é o canônico e íntegro.
- [ ] Enviar o PDF original ao comparador e confirmar resultado “idêntico”.
- [ ] Alterar um byte de uma cópia do PDF e confirmar resultado “diferente”.
- [ ] Arquivar a Portaria e confirmar que o PDF público permanece acessível e íntegro.
- [ ] Testar sessão expirada, método inválido, ID inválido, limite de tentativas e indisponibilidade de configuração; confirmar respostas controladas, sem vazamento de dados.

## Critérios para expandir a outros documentos

- [ ] Preservar `tipo_doc`, `id_tipo_doc`, `emissor` e `id_doc` do tipo documental.
- [ ] Reutilizar `PortariaAssinaturaService` quando o contrato comportar o documento; caso contrário, extrair uma abstração equivalente compartilhada. Não duplicar autorização, CSRF, reautenticação, finalização, hash, auditoria ou imutabilidade.
- [ ] Usar renderer separado, sem receber `$_POST` nem executar SQL; gerar o PDF antes de marcá-lo como finalizado.
- [ ] Finalizar PDF, persistir metadados, registrar auditoria e ativar o documento em uma única transação.
- [ ] Proteger endpoints administrativos por sessão, autorização CONIECP/IECP, método e validação de ID; manter o verificador público limitado a PDF finalizado e íntegro.
- [ ] Validar e sanitizar HTML rico no servidor; usar consultas parametrizadas em todo acesso a dados.
- [ ] Adicionar suíte de aceitação com banco descartável e cobrir rascunho, recusas, ativação, imutabilidade, integridade e falha transacional.
- [ ] Executar as verificações estáticas, o roteiro WAMP e o roteiro público deste checklist para o novo tipo antes de atualizá-lo como implementado e validado no inventário.

## Pendências operacionais antes de produção

- [ ] Usar usuário de banco com privilégio mínimo e rotacionar credenciais históricas.
- [ ] Configurar segredos fora do repositório e da raiz pública.
- [ ] Ajustar limites de upload, timeout, memória e concorrência do WAMP/Apache para o limite de comparação de PDF.
- [ ] Confirmar IP real atrás de proxy antes de confiar em `REMOTE_ADDR` para rate limit.
- [ ] Aprovar política institucional e jurídica para assinatura interna, guarda, cancelamento e regularização de legados.
