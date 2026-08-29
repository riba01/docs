# Análise técnica: relatórios QDM sem envio mensal pelas IECP

Data do levantamento: 29/08/2026

## Decisão resumida

É possível deixar de exigir o envio manual mensal para parte relevante dos indicadores do Questionário de Desempenho Mensal (QDM). Não é possível, entretanto, reproduzir com segurança todo o conteúdo histórico do QDM apenas consultando o banco no momento em que o relatório é solicitado.

Os relatórios de crescimento e perda disponibilizados atualmente em `coniecp/qdm/relatorio` já consultam `cadastroministro` diretamente. Isso demonstra a viabilidade técnica de relatórios automáticos, mas não comprova que os seus resultados tenham o mesmo significado dos números declarados mensalmente pela IECP.

Para substituir o envio manual sem perder rastreabilidade, o modelo recomendado é uma consolidação automática por competência, com fechamento mensal e registro da completude das fontes. Consultas ao vivo devem ser usadas para painéis do período atual, não como substituto de um histórico fechado.

## Escopo analisado

Foram rastreados os fluxos e relatórios em:

- `coniecp/qdm/`;
- `coniecp/qdm/relatorio/`;
- `iecp/qdm/`;
- `classes/Qdm.class.php`;
- fontes de membros, cargos, EBD e situação do membro.

A estrutura consultada foi o dump disponível `database/schema/conie847_sisconiecp06082026.sql`. Os arquivos de esquema de produção e local referidos pelas instruções do repositório não estão presentes com os nomes esperados, portanto a compatibilidade com a base atualmente em execução não foi confirmada por conexão direta.

## Funcionamento atual

O QDM grava uma linha mensal por IECP na tabela `qdm`, com indicadores de membros, EBD, obra missionária, corpo de obreiros e metadados de envio. A tabela é MyISAM e não possui índice único para a combinação `idIecp`, `ano` e `mes`.

No fluxo da IECP, `iecp/qdm/carregaValores.php` já pré-carrega automaticamente:

- total do mês anterior, a partir do QDM anterior;
- quantitativo de obreiros, a partir de `cadastroministro`;
- matrículas e frequências da EBD, a partir de `dados_ebd`.

Outros campos são declarados no formulário. Em especial, evangelismo, conversões, batismos, observações e parte dos indicadores do rol de membros não possuem uma fonte automática equivalente comprovada pelo código analisado.

## Relatórios existentes

### Crescimento de membros

`listarCrescimento.php` e `graficoCrescimento.php` contam registros em `cadastroministro` cujo status atual é ativo e agrupam o resultado pelo mês de `cadastradoEm`.

Esse relatório pode ser gerado sem QDM. Porém, ele representa cadastros que permanecem ativos no momento da consulta, não necessariamente o crescimento líquido ocorrido na competência. Uma alteração posterior no status de um membro pode alterar retroativamente o resultado de meses antigos.

### Perda de membros

`listarPerda.php` e `graficoPerda.php` contam registros cujo status atual não é ativo e os agrupam pelo mês de `atualizadoEm`.

Também pode ser gerado sem QDM, mas não é confiável como perda mensal definitiva: `atualizadoEm` pode mudar após qualquer edição do cadastro e não identifica, por si só, o tipo ou a data efetiva do desligamento, da exclusão ou da transferência.

### Relatórios dependentes do QDM

Existem `listarRelatorioCrescimento.php` e `listarRelatorioPerda.php`, que calculam os números a partir dos valores arquivados em `qdm`. Eles não são chamados pelo JavaScript atual da página de relatórios, mas evidenciam que o sistema também possui uma leitura baseada nos números declarados mensalmente.

### Controle de envio

A grade `listarQdmAcao.php` informa envio no prazo, atraso, recebimento, devolução e ausência de envio. Se o envio manual for descontinuado, esses estados deixam de ter o mesmo significado. A substituição adequada é uma situação de consolidação automática, como `completa`, `incompleta` ou `com falha de fonte`, e não uma simulação de envio.

## Matriz de viabilidade

| Grupo de dados | Fonte identificada | Viabilidade sem envio manual | Limitação para repetir o histórico do QDM |
| --- | --- | --- | --- |
| Total de membros | `cadastroministro` e `situacao_membro` | Parcial | O cadastro atual não é uma fotografia mensal; o histórico depende da cobertura de `situacao_membro`. |
| Homens, mulheres e jovens | `cadastroministro` | Parcial | É possível para a data da consulta. Para competências passadas, é necessário reconstruir a situação e a vinculação à IECP na data de corte. |
| Disciplinados, desligados e excluídos | `situacao_membro` e status de membro | Parcial | Requer confirmação dos códigos de status e auditoria da completude das datas de início e fim. |
| Membros no mês anterior | Fotografia anterior | Condicional | Sem QDM, depende de uma consolidação da competência anterior ou de reconstrução histórica confiável. |
| Matrículas e frequência EBD | `dados_ebd` | Sim, com validação de completude | A regra deve reproduzir a classificação de classes usada pelo QDM. Ausência de registros precisa ser diferenciada de valor zero. |
| Média e status da EBD | `dados_ebd` | Sim, após padronizar a fórmula | O carregamento inicial considera cinco classes, enquanto o JavaScript recalcula a média com quatro, ignorando novos convertidos. |
| Corpo de obreiros | `cadastroministro`, `historicocargo` e `situacao_membro` | Parcial | O valor atual é calculável. O histórico depende do encerramento correto de cargos e situações. |
| Batismos | `cadastroministro.batismo` | Condicional | Não há regra que assegure que cada data de batismo representa o indicador QDM da competência e da IECP. |
| Evangelismo e conversões | Nenhuma fonte estruturada equivalente encontrada | Não | São valores declaratórios no QDM. |
| Outras atividades e observações | `qdm.outras`, `qdm.obsEvang`, `qdm.obsConver` | Não | São textos livres exclusivos do formulário. |
| Enviado por, data e status de envio | `qdm` e `statusqdm` | Não aplicável | São informações do processo manual que seria removido. |

## Fontes reutilizáveis

Há componentes já existentes que devem orientar uma futura implementação:

- `iecp/qdm/carregaValores.php` consolida EBD e corpo de obreiros;
- `classes/MembroHistoricoTotal.php` calcula total anual de membros usando `situacao_membro` para anos passados;
- `coniecp/cadastrar-iecp/crescimento.php` e `coniecp/cadastrar-iecp/ebd.php` mostram como os dados do QDM são consumidos em gráficos;
- `dados_ebd` contém `diaAula`, classe, matriculados, presenças, faltas e frequência;
- `historicocargo` contém vigência de cargos, mas é MyISAM;
- `situacao_membro` contém vigência e IECP associada à situação do membro.

## Riscos de integridade e semântica

1. Consulta ao vivo não preserva o passado. Uma transferência, exclusão, correção de cargo ou edição de cadastro pode mudar números de competências já encerradas.
2. A aplicação já calcula o total QDM como homens + mulheres + jovens - desligados - excluídos. Esse conceito precisa ser formalizado antes de qualquer substituição automática.
3. Os relatórios atuais de crescimento e perda usam o status atual do membro. Portanto, não devem ser usados como base de comparação histórica sem revisão da regra.
4. Os campos de missão não têm fonte estruturada substituta. Extinguir o envio mensal sem definir essa coleta elimina esses indicadores.
5. O dump mostra ausência de índices compostos para consultas por competência em `qdm` e `dados_ebd`. A necessidade de índices deve ser medida em ambiente local antes de qualquer alteração de esquema.
6. Não foi executada consulta no banco local nem de produção. Assim, a taxa real de preenchimento dos históricos não é conhecida.

## Estratégia recomendada

### Etapa 1: validação somente leitura

Comparar, por IECP e competência, os valores já salvos no QDM com valores reconstruídos das fontes de membros, EBD e cargos. A comparação deve separar zero, ausência de dado e divergência de regra.

### Etapa 2: consolidação automática por competência

Criar, mediante demanda específica, uma rotina de fechamento mensal que:

1. lê as fontes estruturadas em uma data de corte definida;
2. valida se há dados suficientes de EBD, membros e cargos;
3. grava uma fotografia imutável da competência, com versão da regra e situação de completude;
4. aponta campos sem fonte estruturada como pendentes ou indisponíveis, sem convertê-los silenciosamente em zero;
5. restringe a execução e a consulta por permissões de servidor.

Essa fotografia pode substituir a finalidade analítica do QDM, mas não deve sobrescrever o histórico já declarado pelas IECP.

### Etapa 3: revisão dos relatórios

Os relatórios devem consultar a fotografia de competência para períodos encerrados e fontes ao vivo apenas para o período em aberto. O relatório de acompanhamento de envio deve ser substituído por um relatório de qualidade da consolidação.

## Conclusão

O envio mensal manual pode ser retirado para os indicadores de EBD e para parte dos indicadores de membros e obreiros, desde que haja fechamento automático e auditoria histórica. Ele não pode ser retirado integralmente enquanto evangelismo, conversões, atividades e observações continuarem sem uma fonte estruturada no banco.

Nenhuma alteração de código, esquema ou dados foi realizada como parte deste levantamento.
