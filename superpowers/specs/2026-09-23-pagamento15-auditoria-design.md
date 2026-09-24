# Pagamentos de 15% — auditoria cruzada IECP × CONIECP

Data: 2026-09-23
Status: aguardando revisão do usuário
Páginas afetadas: `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15` e `iecp/tesouraria/reuniao_dados/tabela_pagamento_15`

## 1. Contexto e objetivo

A tela nasceu da sindicância de 2018, que apurou desvio nos dois lados: IECP que depositava e CONIECP que não registrava (desviando), e IECP que lançava a saída dos 15% sem depositar (desviando). A tela cruza os dois livros para que nenhum lado desvie sem aparecer.

Hoje ela tem erros de cálculo que produzem divergências falsas e escondem valores, é lenta (soma em PHP linhas brutas de até 11 anos) e pouco acessível (cor como único sinal, tabelas sem semântica). As páginas CONIECP e IECP são implementações diferentes, com funcionalidades diferentes.

Objetivo: números corretos e rastreáveis, mesma tela e mesmas palavras para os dois atores, linguagem neutra, e caminho do número até o lançamento e o comprovante.

## 2. Regras de negócio (decididas com o usuário)

1. **Defasagem de um mês.** A IECP arrecada e lança no balancete do mês M; o depósito cai na CONIECP no mês M+1. Todo valor é posicionado no **mês CONIECP**: balancete IECP de (ano, mês) vai para (ano, mês+1); dezembro vai para janeiro do ano seguinte.
2. **Mês de referência = mês do balancete** (`balancete.mes/ano`, `balancete_congregacao.mes/ano`, `balancete_coniecp.mes/ano`), nunca a data do item. Motivo: há itens datados no dia 1º do mês seguinte dentro do balancete do mês anterior (IECP 12 set/2025; congregação 16 nov/2017).
3. **Declarado** = grupo 21 ("15% CONIECP") do balancete consolidado da IECP: sede + todas as congregações. Algumas congregações depositam direto; o normal é a IECP depositar tudo. Em ambos os casos a CONIECP registra na IECP.
4. **Devido** = 15% de toda entrada (`tipoContabil = 1`) da sede e das congregações, **exceto grupos 32 (Recurso recebido da Congregação) e 34 (Recurso recebido da IECP)**, que são transferências internas.
5. **Registrado** = entradas do grupo 1 do balancete da CONIECP. A IECP do lançamento é:
   1. `itembalancete_coniecp.idIecp` quando diferente de 0;
   2. senão, o CNPJ encontrado na descrição, conferido contra `iecp_cnpj_historico` vigente na data do item;
   3. senão, contra o CNPJ atual de `iecp`;
   4. senão, **"Registrado sem IECP identificada"** — mostrado como linha própria nos totais, nunca descartado.
6. **Diferenças:** `registrado − declarado` e `registrado − devido`. Negativo = saiu/deveria sair da IECP e não entrou na CONIECP. Positivo = entrou na CONIECP sem correspondente na IECP.
7. **Tolerância:** divergência é `|diferença| ≥ R$ 0,01`, com cada lado arredondado a 2 casas antes da subtração. Nenhuma margem esconde valor.
8. **Status definitivo:** somente `Finalizado`. Fluxo: IECP altera em "Em Elaboracao" ou "Devolvido"; "Enviado" = aguarda análise da CONIECP (que finaliza ou devolve). A CONIECP altera os próprios balancetes em elaboração/enviado; reabrir exige devolução pelo Presidente (e Sec. Geral).
9. **IECPs ativas**, exceto a lista explícita `IECPS_EXCLUIDAS = [15]` (IECP Testes). Não usar regra de "CNPJ fictício": a Pirapora teve CNPJ fictício em 2018–2020.
10. **Nunca alterar os livros contábeis** para corrigir o relatório. `itembalancete_coniecp.incluidoEm` é `ON UPDATE CURRENT_TIMESTAMP`: qualquer UPDATE apaga a data de inclusão.

## 3. Situação de cada célula

Calculada por IECP × mês CONIECP, na ordem de precedência abaixo (a primeira que casar vence):

| Situação | Condição | Exibição |
|---|---|---|
| `futuro` | mês CONIECP posterior ao mês corrente | "—", sem valor |
| `aguardando_coniecp` | não existe `balancete_coniecp` do mês | marca ○ + texto |
| `aguardando_iecp` | não existe `balancete` da sede da IECP no mês de origem | marca ◌ + texto |
| `provisorio` | algum balancete envolvido existe e não está `Finalizado` (CONIECP do mês; sede e congregações da IECP no mês de origem) | marca ◐ + texto |
| `definitivo` | todos os balancetes envolvidos `Finalizado` | sem marca |

Visões de um lado só usam só aquele lado: a visão CONIECP (①) considera apenas o balancete CONIECP; as visões IECP (②) e devido (⑤) consideram apenas os balancetes da IECP. Linhas de total recebem a pior situação entre suas células (ordem: aguardando > provisório > definitivo).

Valores são sempre mostrados, mesmo provisórios; a situação acompanha o valor.

## 4. Dados

### 4.1 Tabela nova `iecp_cnpj_historico`

```sql
CREATE TABLE iecp_cnpj_historico (
  id INT NOT NULL AUTO_INCREMENT,
  idIecp INT NOT NULL,
  cnpj VARCHAR(18) NOT NULL,
  vigente_de DATE NULL,        -- NULL = desde sempre
  vigente_ate DATE NULL,       -- NULL = até hoje
  observacao VARCHAR(255) NULL,
  cadastradoEm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_cnpj (cnpj),
  KEY idx_iecp (idIecp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Carga inicial:

| idIecp | cnpj | vigente_de | vigente_ate | observacao |
|---|---|---|---|---|
| 6 (Resende) | 29.178.753/0001-73 | NULL | 2014-09-30 | CNPJ usado nas descrições até set/2014 |
| 14 (Pirapora) | 00.000.000/0000-02 | NULL | 2020-04-30 | CNPJ provisório até o definitivo |

Migração: `sql/migrate_iecp_cnpj_historico_20260923.php --dry-run|--apply`, idempotente (não recria a tabela nem duplica linhas; confere por `idIecp + cnpj`). A definição também entra em `sql/schema.sql`. O `--apply` em produção é executado pelo usuário.

### 4.2 Consultas

Todas com parâmetros ligados, somas no banco, filtros por intervalo de `ano`/`mes` do balancete (sem `YEAR(dia)` em WHERE).

- **Registrado:** `itembalancete_coniecp` (grupo 1, tipo 1) ⨝ `balancete_coniecp` → `ano, mes, status, idIecp, descricao, dia, SUM(valor)`. Itens com `idIecp = 0` voltam individualmente (poucos) para a identificação por CNPJ em PHP (MySQL 5.7 não tem `REGEXP_SUBSTR`).
- **Declarado:** `itembalancete` (grupo 21) ⨝ `balancete` ∪ `itembalancete_congregacao` (grupo 21) ⨝ `balancete_congregacao` → `idIecp, ano, mes, SUM(valor)` agrupado; balancetes com `mes` inválido (vazio ou fora de 1–12) são ignorados e contados em log.
- **Devido:** mesmas uniões, `tipoContabil = 1 AND idGrupo NOT IN (32, 34)`, `SUM(valor) * 0.15`.
- **Situação:** existência e status dos balancetes por `(idIecp, ano, mes)` para sede e congregações, e por `(ano, mes)` para a CONIECP. Não há duplicidade de balancete por entidade/mês (verificado em 2026-09-23).

## 5. Componentes

### 5.1 `classes/Pagamento15Regras.php` (puro, sem banco)

- `mesConiecp(int $ano, int $mes): array{ano:int, mes:int}` — deslocamento +1.
- `mesOrigemIecp(int $anoConiecp, int $mesConiecp): array{ano:int, mes:int}` — inverso.
- `situacao(...)`: recebe a existência/status dos balancetes envolvidos e o mês corrente; devolve uma das situações da seção 3.
- `extrairCnpj(string $descricao): ?string` — regex `\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}`.
- `diferenca(float $registrado, float $outro): float` e `divergente(float $diferenca): bool` (regra 7).
- `pior(array $situacoes): string`.

### 5.2 `classes/Pagamento15.php` (leitura; recebe `PDO` no construtor)

| Método | Retorno |
|---|---|
| `iecps(int $idIecp): array` | `[{id, nome}]` — ativas, fora `IECPS_EXCLUIDAS`; `0` = todas |
| `registradoConiecp(int $anoIni, int $anoFim): array` | `[idIecp|'nao_identificado'][ano][mes] => valor` + status CONIECP por `[ano][mes]` |
| `declaradoIecp(int $anoIni, int $anoFim): array` | `[idIecp][ano][mes] => valor`, já em mês CONIECP |
| `devidoArrecadacao(int $anoIni, int $anoFim): array` | idem, 15% |
| `situacoes(int $anoIni, int $anoFim): array` | status dos balancetes para `Pagamento15Regras::situacao` |
| `lancamentos(int $idIecp, int $ano, int $mes): array` | itens dos dois lados para o detalhamento |

`anoIni/anoFim` são anos CONIECP; o método converte para a janela de origem da IECP (dez/(anoIni−1) a nov/anoFim).

### 5.3 Endpoints (`coniecp/tesouraria/reuniao_dados/api/`)

Padrão do `coniecp/sindicancia/selecionaMinistro.php`: `StartSecureSession`, `valida_sessao_all`, `Content-Type: application/json`, só POST, CSRF obrigatório, resposta `{ok, mensagem, dados}`.

- `acessoPagamento15.php` (incluído pelos três): nível 1 (CONIECP) pode qualquer `idIecp`, `0` = todas; demais usuários: `idIecp` = IECP da sessão, outro valor → 403. Substitui `tabelas_pagamentos/validarAcessoPagamento15.php`.
- `dadosMensal.php` — entrada `idIecp`, `ano` (2014 … ano corrente). Saída:
  ```json
  {
    "ano": 2025,
    "meses": [{"mes": 1, "rotulo": "Jan/25", "referencia": "Dez/24", "situacaoConiecp": "definitivo"}],
    "iecps": [{"id": 5, "nome": "Porto Real",
               "celulas": {"1": {"registrado": 0, "declarado": 0, "devido": 0,
                                 "situacao": "provisorio", "situacaoIecp": "definitivo"}}}],
    "naoIdentificado": {"1": 0},
    "totais": {"mensal": {"1": {"registrado": 0, "declarado": 0, "devido": 0, "situacao": "..."}},
               "anual": {"registrado": 0, "declarado": 0, "devido": 0}},
    "resumo": {"registrado": 0, "declarado": 0, "diferenca": 0, "devido": 0,
               "diferencaDevido": 0, "iecpsComDivergencia": 0, "naoIdentificado": 0},
    "avisos": ["CONIECP: mar–dez/2025 em elaboração — valores provisórios."]
  }
  ```
- `dadosHistorico.php` — entrada `idIecp`. Janela: `anoFim` = ano corrente, `anoIni = max(2014, anoFim − 9)` (igual à tela atual). Saída: mesma forma, com `anos` no lugar de `meses` e `celulas` por ano; mais `indicadores` (diferença acumulada, declarado, registrado, períodos divergentes, maior diferença) e `notas` por ano (seção 6.4).
- `dadosLancamentos.php` — entrada `idIecp` (≥ 1), `ano`, `mes` (mês CONIECP). Saída:
  ```json
  {
    "coniecp": [{"data": "2025-02-05", "descricao": "...", "valor": 0, "statusBalancete": "Finalizado", "identificadoPor": "idIecp|cnpj_historico|cnpj_atual"}],
    "iecp": [{"origem": "Sede|Congregação <nome>", "mesBalancete": "01/2025", "data": "...", "descricao": "...", "valor": 0, "statusBalancete": "...", "comprovanteUrl": "..."|null}],
    "totais": {"registrado": 0, "declarado": 0, "diferenca": 0},
    "leitura": "texto neutro da seção 6.3"
  }
  ```
  `comprovanteUrl` resolvida como na consulta de balancete da CONIECP (`coniecp/tesouraria/balanceteMensal/consultarBalancete`), a partir de `recibo_armazenado_iecp` / `recibo_armazenado_congregacao`.

Validação: parâmetro inválido → 422; método ≠ POST → 405; sem permissão ou CSRF inválido → 403; erro de banco → 500 com mensagem genérica e detalhe só em `error_log`.

### 5.4 Páginas

```
coniecp/tesouraria/reuniao_dados/
  tabela_pagamento_15.php        página CONIECP: sessão + validar_usuario_coniecp + partial (modo 'coniecp')
  partials/pagamento15.php       marcação comum (filtros, indicadores, abas, tabela, gráficos, notas, diálogo)
  js/pagamento15.js              módulo comum: requisições, cache, renderização, CSV, diálogo, gráficos
  css/pagamento15.css            tokens e estilos comuns, @media print
iecp/tesouraria/reuniao_dados/
  tabela_pagamento_15.php        página IECP: sessão + validar_usuario_iecp + partial (modo 'iecp')
```

O modo só muda o seletor de IECP (CONIECP: todas + "Todas as IECPs"; IECP: fixo na própria). ECharts continua vindo de `node_modules/echarts/dist/echarts.min.js`.

## 6. Tela

### 6.1 Estrutura

1. Título, filtros **IECP** e **Ano**, botão **Limpar**. Carrega ao mudar filtro (sem "Aplicar"). O seletor de ano sempre mostra o ano efetivamente carregado.
2. **Avisos** de período (ex.: "CONIECP: mar–dez/2025 em elaboração — valores provisórios").
3. **Indicadores do ano:** Registrado CONIECP · Declarado IECPs · Diferença (C − I) · Devido (15% arrecadação) · Diferença (C − devido) · IECPs com divergência. Se houver, "Registrado sem IECP identificada". "IECPs com divergência" = quantidade de IECPs com ao menos um mês não-`futuro` em que `registrado − declarado` é divergente (regra 7); "períodos divergentes" do histórico usa a mesma regra por ano.
4. **Abas:** "Ano {A}" e "Histórico {anoIni}–{anoFim}".
   - Ano — visões: **Comparação** (padrão), **Registrado CONIECP** (①), **Declarado IECP** (②), **15% da arrecadação** (⑤).
   - Histórico — visões: **Registrado × declarado** (④), **Registrado × devido** (⑥); indicadores do histórico, gráfico comparativo, gráfico de divergência e notas por ano (herdados da página IECP). Com "Todas", gráficos e indicadores somam todas as IECPs. Clicar num ano leva à aba Ano com aquele ano.
5. Ferramentas da tabela: **Buscar IECP** (quando "Todas"), **Só divergências**, **Ordenar** (maior diferença, nome), **CSV**, **Imprimir**.
6. **Legenda fixa:** "Diferença = registrado pela CONIECP − declarado pela IECP. Negativo: declarado pela IECP e não registrado na CONIECP. Positivo: registrado na CONIECP sem declaração correspondente da IECP. O depósito do mês M da IECP é registrado no mês M+1 da CONIECP." Mais a legenda das marcas de situação.

### 6.2 Tabela

- `<caption>`, `thead` com `scope="col"`, primeira coluna `th scope="row"`, totais em `tfoot`.
- Cabeçalho de mês: "Jan/25" e, abaixo, "ref. Dez/24" nas visões Comparação e ②/⑤.
- Cabeçalho e primeira coluna fixos (sticky); rolagem horizontal no contêiner, nunca na página.
- Números alinhados à direita, `font-variant-numeric: tabular-nums`, formato `R$ 1.234,56`.
- Na Comparação, a célula mostra só a diferença, com sinal por escrito (`+`/`−`), zero como "—", e a marca de situação. Cor reforça, nunca é o único sinal; contraste AA.
- Células com valor (Comparação, ①, ②) são `<button>` que abrem o detalhamento. Células de total e da visão ⑤ não abrem.

### 6.3 Detalhamento (diálogo)

- Título: IECP, mês CONIECP e mês de referência IECP.
- Coluna **CONIECP**: data, descrição, valor, status do balancete, e como a IECP foi identificada.
- Coluna **IECP**, agrupada por **Sede** e por **Congregação**: mês do balancete, data, descrição, valor, status, **comprovante** ("Ver recibo" abre no visualizador existente; senão "sem comprovante").
- Rodapé: totais, diferença e leitura neutra:

| Caso | Leitura |
|---|---|
| declarado > 0, registrado = 0 | "Declarado pela IECP e não registrado na CONIECP. A IECP não depositou ou a CONIECP não registrou; o comprovante de depósito decide." |
| registrado > 0, declarado = 0 | "Registrado na CONIECP sem declaração da IECP. A IECP não lançou a saída ou o depósito foi atribuído à IECP errada." |
| ambos > 0, diferença ≠ 0 | "Valores diferentes entre os dois livros. Conferir os lançamentos e os comprovantes." |
| diferença = 0 | "Valores coincidentes." |

Diálogo acessível: `role="dialog"`, `aria-modal`, foco preso, Esc fecha, foco volta à célula de origem.

### 6.4 Notas por ano (histórico)

Mesma lógica da página IECP atual, com títulos neutros:

| Tipo | Condição | Título |
|---|---|---|
| critical | registrado = 0, declarado > 0 | Declarado pela IECP, sem registro na CONIECP |
| warning | registrado > 0, declarado = 0 | Registrado na CONIECP, sem declaração da IECP |
| warning | diferença < 0 | Declarado pela IECP acima do registrado na CONIECP |
| warning | diferença > 0 | Registrado na CONIECP acima do declarado pela IECP |
| ok | diferença = 0 | Conferência coincidente |

Se o ano tiver célula provisória, a nota acrescenta "(valores provisórios)".

### 6.5 Exportar e imprimir

- **CSV** da visão e aba atuais: separador `;`, decimal `,`, UTF-8 com BOM; colunas IECP, período, valores da visão, situação. Nome: `pagamento15_{aba}_{visao}_{iecp}_{ano}.csv`.
- **Imprimir:** `@media print` com todas as visões da aba atual expandidas, legenda, avisos, filtros aplicados, data/hora e usuário que gerou.

### 6.6 Acessibilidade e responsivo

`aria-live` apenas na linha de status (ex.: "Atualizado: 2025, 14 IECPs, 3 com divergência"); regiões das tabelas sem `aria-live`. Alvos de toque ≥ 44px; foco visível; `prefers-reduced-motion` desliga animações dos gráficos; gráficos com `aria-label` e a tabela como alternativa. Larguras de validação: 375, 768, 1024, 1440px. Seguir o padrão de layout do projeto (`<div class="row">`, sem `g-0`).

## 7. Desempenho

- Cada endpoint faz no máximo 5 consultas agregadas; nenhum laço IECP × mês × lançamento em PHP.
- Histórico em cache no navegador por `idIecp` (não depende do ano).
- Requisições com sequência: resposta de filtro antigo é descartada.

## 8. Testes

1. `tests/pagamento15/pagamento15_regras_test.php` — sem banco: deslocamento de mês (dez→jan do ano seguinte, nov→dez), inverso, precedência de situação, extração de CNPJ, tolerância de R$ 0,01, `pior`.
2. `tests/pagamento15/pagamento15_consultas_test.php` — `sisconiecp_test` com tabelas `TEMPORARY` e `PDO` injetado (padrão de `tests/portaria/README.md`). Cenários: IECP com congregação; IECP que começa no meio da janela (caso Jardim Aliança 2); item com `idIecp = 0` identificado por CNPJ histórico; item não identificável vai para `nao_identificado`; grupos 32 e 34 fora do devido; IECP 15 excluída; item datado fora do mês do balancete cai no mês do balancete; balancete com `mes` vazio ignorado.
3. `tests/pagamento15/pagamento15_acesso_test.php` — usuário IECP pedindo outra IECP → 403; sem CSRF → 403; ano/mês inválidos → 422; GET → 405.
4. `tests/pagamento15/pagamento15_conferencia.php` — somente leitura na base real: compara totais novos × lógica antiga e falha se sobrar diferença fora da lista de casos conhecidos (seção 9).
5. `php -l` em todos os PHP novos/alterados; `node --check` no JS.

## 9. Casos conhecidos que a conferência deve explicar

| Caso | Efeito esperado (novo − antigo) |
|---|---|
| Jardim Aliança 2 (13) e Pirapora (14), 1º lançamento em 2018 | histórico: 2018 passa a ter valor; 2019 perde o que estava deslocado; total sobe (R$ 4.578,25 no declarado; R$ 5.461,20 no devido, janela 2017–2026) |
| Pirapora, 11 itens com CNPJ provisório (out/2018–abr/2020, R$ 3.579,00) | passam a contar como registrado da IECP 14 |
| Resende, 9 itens com CNPJ 0001-73 (jan–set/2014, R$ 12.820,50) | passam a contar na visão mensal ① de 2014 |
| Grupo 34 (desde abr/2025) | sai da base do devido |
| IECP 12 set/2025 (R$ 153,60) e congregação 16 nov/2017 (R$ 222,75) | mudam de mês (e o segundo, de ano fiscal) |
| IECP 15 (Testes) | deixa de aparecer |
| Base do devido na tela atual (⑤) sem filtro de IECP ativa | IECPs inativas deixam de aparecer; IECPs sem arrecadação passam a aparecer com "—" |

## 10. Entrega

1. Migração, `Pagamento15Regras`, `Pagamento15`, testes 1 e 2.
2. Endpoints, teste 3 e conferência 4 — **parar e mostrar o resultado da conferência ao usuário.**
3. Tela nova em rota paralela `coniecp/tesouraria/reuniao_dados/tabela_pagamento_15_nova` (fora do menu); a antiga continua no ar. Capturas em 375/768/1440px via navegador; **se o login do WAMP bloquear, pedir ao usuário para logar.** **Parar para avaliação visual.**
4. Ajustes pedidos.
5. Com aprovação: a rota oficial passa a usar a tela nova (a rota paralela é removida); página IECP passa a usar o partial; remoção de:
   - `coniecp/tesouraria/reuniao_dados/tabelas_pagamentos/` (4 endpoints + `validarAcessoPagamento15.php`);
   - métodos `buscaTodosValores15RegNaConiecp`, `buscaValores15PorAno`, `buscaValores15BaseArrecadacao`, `buscaValores15BaseArrecadacaoIecpEspecifica` de `classes/Iecp.class.php` (sem outro uso, verificado em 2026-09-23);
   - `js/tabela_pagamento_15.js`, `js/tabela_pagamento_15 copy.js`, `css/tabela_pagamento_15.css`, `css/tabela_pagamento_15.scss` (CONIECP) e JS/CSS antigos da página IECP;
   - `lista_pagamento_15-backup.php`; `lista_pagamento_15.php` só se não houver outro uso.

## 11. Fora de escopo (registrado)

- Tela para a CONIECP anexar recibos aos seus lançamentos (hoje 0% têm).
- Desativar `coniecp/tesouraria/balanceteMensalConiecp/updateItensBalConiecp.php`, que reescreve o livro da CONIECP e apaga `incluidoEm`.
- Trilha de auditoria de alterações nos itens de balancete.
