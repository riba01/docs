# Design: Paridade Visual CONIECP ← IECP — Balancete Mensal

**Data:** 2026-05-01  
**Módulo:** `coniecp/tesouraria/balanceteMensal/consultarBalancete/`  
**Referência visual:** `iecp/tesouraria/balanceteMensal/consultarBalancete/`

---

## Objetivo

Aplicar o mesmo padrão visual da página IECP na página CONIECP, preservando todas as funcionalidades, endpoints, variáveis e regras de negócio específicas da CONIECP.

---

## Arquivos Alterados

| Arquivo | Tipo de mudança |
|---|---|
| `coniecp/tesouraria/balanceteMensal/consultarBalancete/balanceteMensal.php` | Reescrita completa do HTML + bloco PHP de segurança + DASH_DATA |
| `coniecp/tesouraria/balanceteMensal/js/balanceteMensal.js` | Reescrita completa |
| `coniecp/tesouraria/balanceteMensal/css/balanceteMensal.css` | Adição de regra de correção de conflito para `#recibo_div2` |

## Arquivos Referenciados (não alterados)

| Arquivo | Uso |
|---|---|
| `iecp/tesouraria/balanceteMensal/css/consultarBalancete.css` | Carregado via `<link>` na CONIECP |
| `coniecp/tesouraria/balanceteMensal/consultarBalancete/dadosBalanceteMensal.php` | Não alterado |

---

## Variáveis CONIECP Preservadas

| Variável | Nota |
|---|---|
| `$valorgrupo` | Minúsculo — diferente da IECP (`$valorGrupo`) |
| `$listaIdCongregacao` | Diferente da IECP (`$tabelaIdCongregacao`) |
| `$possuiCong` | Valor booleano `true/false` (não inteiro) |
| `$quinzePorCento` | Calculado na iteração de despesas |
| `$despCongrValor` | Array indexado por `$i` |
| `$statusCong` | Não setado em `dadosBalanceteMensal.php` — pré-existente; `isset()` evita erro |
| `$nomeIecp` | Usado com `htmlspecialchars` no novo código |

---

## Endpoints CONIECP — Preservados

| Operação | Endpoint |
|---|---|
| Finalizar / Devolver balancete | `painel.php?pagina=coniecp/tesouraria/balanceteMensal/modificaStatusBalancete` |
| Listar receitas | `coniecp/tesouraria/balanceteMensal/listarReceitasBalancete.php` (caminho direto — comportamento atual) |
| Listar despesas | `coniecp/tesouraria/balanceteMensal/listarDespesasBalancete.php` (caminho direto — comportamento atual) |
| Imprimir PDF | `painel.php?pagina=coniecp/tesouraria/balanceteMensal/pdf/balanceteMensalPDF` |
| Voltar | `painel.php?pagina=coniecp/tesouraria/balanceteMensal/listarBalancete` |
| Recarregar balancete | `painel.php?pagina=coniecp/tesouraria/balanceteMensal/consultarBalancete/balanceteMensal` |

## Endpoints IECP Preservados (já usados pela CONIECP atualmente)

> Estes endpoints são parte do comportamento legado da CONIECP.  
> Não foram introduzidos nesta tarefa — já existiam no JS anterior.

| Operação | Endpoint |
|---|---|
| Incluir receita | `iecp/tesouraria/balanceteMensal/incluirReceita.php` |
| Incluir despesa | `iecp/tesouraria/balanceteMensal/incluirDespesa.php` |

---

## Funcionalidades CONIECP Preservadas

- `require 'validar_usuario_coniecp.php'` mantido
- Botões de ação exclusivos da CONIECP:
  - **Finalizar** (value="Finalizado") → visível quando status ∈ `['Enviado', 'Modificado', 'Finalizado']`
  - **Devolver** (value="Devolvido") → visível quando status ∈ `['Enviado', 'Modificado', 'Finalizado']`
- Formulário de **receita com 4 colunas** (Data, Tipo de Entrada, Valor, Incluir) — sem campo Descrição
- Formulário de **despesa com 5 colunas** (Data, Tipo de Despesa, Descrição, Valor, Incluir) — comportamento atual
- Validação de receita: 3 campos (dia, grupo, valor) — sem descrição
- Validação de despesa: 4 campos (dia, grupo, descricao, valor)
- Recibo: **visualização apenas** (`#recibo_div2`) — sem formulário de upload
- Nenhum `deleteItemBalancete` adicionado

---

## Mudanças Visuais Aplicadas

### CSS
- `iecp/tesouraria/balanceteMensal/css/consultarBalancete.css` adicionado via `<link>`
  - Seletores escopados em `#conteudo .bal-consulta-*` — não vaza para outros módulos
- `coniecp/tesouraria/balanceteMensal/css/balanceteMensal.css` recebe regra corretiva:
  ```css
  #conteudo #recibo_div2.recibo-modal {
    position: fixed;
    top: 50vh;
    left: 50vw;
    transform: translate(-50%, -50%);
  }
  ```
  Essa regra resolve o conflito entre `#recibo_div2 { position: absolute }` (regra antiga) e `.recibo-modal { position: fixed }` (nova) usando seletor mais específico.

### Estrutura HTML do PHP

**Header shell:**
```
bal-consulta-shell (grid)
  ├── bal-consulta-shell__summary (kicker + meta)
  ├── bal-consulta-shell__status (badge com cor semântica)
  └── bal-consulta-shell__actions (botões CONIECP)
```

**Abas:** `bal-consulta-tab` + `aria-controls` + `aria-selected` + `bal-consulta-tab--active`

**Tabelas:** `bal-consulta-content-card > bal-consulta-table-wrap > bal-consulta-table`  
Row classes: `--total`, `--subtotal`, `--balance`, `--highlight`, `--spacer`, `--coniecp`, `--hidden-row`

**Dashboard ECharts (aba gráfico):**
```
dashboard-relatorios
  ├── kpi-grid (4 KPIs: receitas, despesas, saldo, recibos)
  ├── charts-grid--3col (barras, donut despesas, donut receitas)
  └── charts-grid--3col (fluxo caixa, top5 despesas, análise)
```

### CSS inline `<style>` — quando necessário
Preferência é por arquivo `.css`. Bloco `<style>` inline no PHP **somente** se necessário para scroll do `#tabs-1 .bal-consulta-table-wrap` (mesma abordagem da IECP, já documentada). Registrar no resumo final se usado.

---

## DASH_DATA — Injeção PHP

Injetado ao final da página via `json_encode`. Usa variáveis CONIECP:

```php
$dashData['receitasPorGrupo']  → $grupo[1] / $valorgrupo[1]
$dashData['despesasPorGrupo']  → $grupo[2] / $valorgrupo[2]
$dashData['totalReceitas']     → $totalReceitasMatriz ?? $totalReceitas
$dashData['totalDespesas']     → $totalDespesasMatriz ?? $totalDespesas
$dashData['saldoMes']          → $saldoMes ?? 0
$dashData['saldoAnt']          → $saldoAnt ?? 0
$dashData['porSemana']         → calculado de $itembalancete (query preparada)
$dashData['fluxoCaixa']        → calculado de $itembalancete (query preparada)
$dashData['recibosTotal...']   → query em recibo_armazenado_iecp
```

**Fallback seguro:** todos os valores usam `?? 0`, cast `(float)`, e arrays vazios `[]` quando a variável não existir. Se a query falhar, `error_log` + valores zerados — página não quebra.

---

## ECharts

- CDN adicionado: `https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js`
- ECharts **não é carregado globalmente** no projeto — apenas nas páginas que usam (IECP, alguns módulos)
- Sem duplicação: CONIECP carrega apenas uma vez, apenas quando a aba de gráficos existe
- Gráficos renderizados exclusivamente via `DASH_DATA` injetado no load — **sem AJAX refresh** (CONIECP não tem `dadosGraficosBalanceteMensal`)

---

## Pontos de Atenção

1. **`$statusCong` não setado**: variável pré-existente; `isset($statusCong[...])` retorna `false` sem erro. Não alterado.
2. **Botões `.deletar` renderizados via AJAX**: se `listarDespesasBalancete.php` renderizar botões `.deletar`, eles não funcionarão (sem endpoint `deleteItemBalancete` na CONIECP). Comportamento pré-existente — não alterado nesta tarefa.
3. **Endpoints legados IECP (`incluirReceita.php`, `incluirDespesa.php`)**: preservados como estão. Documentados explicitamente acima.
4. **`coniecp/balanceteMensal.css` é carregado pela IECP também** (linha 9 do PHP da IECP). A regra corretiva adicionada (`#conteudo #recibo_div2.recibo-modal`) é inofensiva para a IECP, pois a IECP já usa `abrirModalRecibo()` que aplica `position: fixed` via JS.

---

## Testes Esperados

1. Carregar página CONIECP — sem erro PHP, sem erro de console
2. Navegar entre abas — Balancete, Receitas, Despesas, Gráficos
3. Lançar receita (3 campos) — AJAX para `incluirReceita.php`
4. Lançar despesa (5 campos) — AJAX para `incluirDespesa.php`
5. Abrir aba Gráficos — KPIs + ECharts renderizando
6. Clicar Finalizar ou Devolver — dialog de confirmação + redirect
7. Clicar Imprimir — PDF abre em nova aba
8. Clicar Voltar — retorna para `listarBalancete`
9. Desktop, tablet (768px), mobile (375px) — layout responsivo
10. Verificar Network — sem chamadas para endpoints IECP indevidos
11. Verificar que `listarReceitasBalancete.php` e `listarDespesasBalancete.php` respondem
