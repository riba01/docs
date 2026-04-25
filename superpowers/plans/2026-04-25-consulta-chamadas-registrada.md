# Consulta Chamadas Registrada Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Melhorar `ebd/turma/consultaChamadasRegistrada` no padrao visual recem-adotado, mantendo a consulta/edicao de chamadas registradas e adicionando o botao "Marcar todos".

**Architecture:** Fazer ajuste incremental no fluxo atual: manter entrada via `aulasRegistradas.js`, POST para `consultaChamadasRegistrada.php`, carga de dados em `dados/consultaChamadasRegistradasDados.php` e salvamento pelos endpoints existentes de `ebd/aluno`. A tela deve ganhar shell visual semelhante ao usado em EBD recente, mas sem alterar contrato principal de presenca, justificativa, motivo, data da aula e licao ministrada.

**Tech Stack:** PHP procedural legado, PDO, jQuery, jQuery UI datepicker, CSS responsivo, WAMP.

---

## File Structure

- Modify: `ebd/turma/consultaChamadasRegistrada.php`
  - Corrigir HTML da tabela.
  - Adicionar cabecalho/toolbar no padrao recente.
  - Repor elementos DOM exigidos pelo JS: `#foto_revista`, `#licaoMinistrada` e `.licao`.
  - Adicionar botao `#marcarTodos`.
  - Adicionar `data-label` nas celulas para mobile cards.
- Modify: `ebd/turma/dados/consultaChamadasRegistradasDados.php`
  - Validar `diaAula` como data.
  - Garantir defaults para `$query`, `$visitantes`, `$nomeTurma`, `$totalMatriculados`, `$totalPresentes`, `$totalFaltas`, `$percentual`.
  - Preservar `idTurmaEBD = 0` como invalido, mas nao mexer em `idCongregacao`.
- Modify: `ebd/turma/js/consultaChamadasRegistrada.js`
  - Corrigir validacao de array.
  - Adicionar `#marcarTodos`.
  - Centralizar recalculo dos totais.
  - Evitar `NaN%`/`Infinity%`.
  - Manter salvamento atual e busca de licao.
- Modify: `ebd/turma/css/consultaChamadasRegistrada.css`
  - Aplicar shell visual recente.
  - Desktop em tabela; mobile em cards por aluno.
  - Estilizar estados de presenca/falta/justificada e toolbar.

---

### Task 1: Corrigir base de dados da pagina

- [ ] **Step 1: Revisar entrada POST**

Em `ebd/turma/dados/consultaChamadasRegistradasDados.php`, substituir a captura atual de `diaAula` por validacao de data:

```php
$diaAulaRaw = filter_input(INPUT_POST, 'diaAula', FILTER_UNSAFE_RAW);
$idTurmaEBDPost = filter_input(INPUT_POST, 'idTurmaEBD', FILTER_VALIDATE_INT);

$diaAulaPost = null;
if (is_string($diaAulaRaw) && $diaAulaRaw !== '') {
    $data = DateTime::createFromFormat('Y-m-d', $diaAulaRaw);
    if ($data instanceof DateTime) {
        $diaAulaPost = $data->format('Y-m-d');
    }
}

if (!$diaAulaPost || !$idTurmaEBDPost) {
    header('Location: painel.php');
    exit();
}
```

- [ ] **Step 2: Definir defaults antes das consultas**

Ainda no mesmo arquivo, antes do `try`, declarar:

```php
$query = [];
$visitantes = 0;
$nomeTurma = '';
$totalMatriculados = 0;
$totalPresentes = 0;
$totalFaltas = 0;
$percentual = '0%';
```

- [ ] **Step 3: Calcular totais no PHP sem depender somente do JS**

Depois de `$query = $stmt->fetchAll(PDO::FETCH_ASSOC);`, adicionar:

```php
$totalMatriculados = count($query);
$totalPresentes = 0;

foreach ($query as $row) {
    if ((int) $row['registro'] === 1) {
        $totalPresentes++;
    }
    if ($nomeTurma === '' && isset($row['nomeTurma'])) {
        $nomeTurma = (string) $row['nomeTurma'];
    }
}

$totalFaltas = $totalMatriculados - $totalPresentes;
$percentual = $totalMatriculados > 0 ? ceil(($totalPresentes * 100) / $totalMatriculados) . '%' : '0%';
```

- [ ] **Step 4: Validar PHP**

Run:

```powershell
php -l ebd\turma\dados\consultaChamadasRegistradasDados.php
```

Expected: `No syntax errors detected`.

---

### Task 2: Ajustar markup sem mudar o fluxo

- [ ] **Step 1: Corrigir a tabela**

Em `ebd/turma/consultaChamadasRegistrada.php`, substituir o `<thead>` quebrado por:

```php
<thead>
    <tr>
        <th colspan="5">Chamada da Turma <b id="pegaNome"></b></th>
    </tr>
    <tr>
        <th>Nº</th>
        <th>Presente</th>
        <th>Nome</th>
        <th>Justificado</th>
        <th>Motivo da Falta</th>
    </tr>
</thead>
```

- [ ] **Step 2: Adicionar botao Marcar todos**

Dentro de `.acoes`, antes de `#salvar`, adicionar:

```php
<button type="button" id="marcarTodos" aria-pressed="false">
    <img src="imagem/actions/apply.png" alt="" /> Marcar todos
</button>
```

- [ ] **Step 3: Repor elementos de licao/revista esperados pelo JS**

No bloco de informacoes, apos `Revista em Uso`, adicionar:

```php
<label>Capa:</label>
<span id="foto_revista"></span>

<label>Lição Ministrada:</label>
<span class="licaoMinistrada" id="licaoMinistrada"></span>

<label class="licao" style="display:none;">Selecionar Lição:</label>
<span class="licao" style="display:none;">
    <select id="licao">
        <option value="0">Selecione a lição</option>
    </select>
</span>
```

Remover o `<select id="licao">` duplicado de `#div_editalicao` ou manter apenas um `id="licao"` na pagina.

- [ ] **Step 4: Adicionar data-label nas celulas**

No `foreach`, ajustar os `<td>`:

```php
<td data-label="Nº"><?= $aux ?></td>
<td data-label="Presente" align="center" class="caixa" id="<?= $idMatricula ?>">
...
<td data-label="Nome"><?= $nomeAluno ?></td>
<td data-label="Justificado" class="just" align="center">
...
<td data-label="Motivo da Falta">
```

- [ ] **Step 5: Validar PHP**

Run:

```powershell
php -l ebd\turma\consultaChamadasRegistrada.php
```

Expected: `No syntax errors detected`.

---

### Task 3: Implementar Marcar todos no JS

- [ ] **Step 1: Criar funcao unica de totais**

Em `ebd/turma/js/consultaChamadasRegistrada.js`, perto de `contaPresenca`, adicionar:

```javascript
function atualizaTotais() {
  var total = Number($("#totalMatricula").val()) || 0;
  var presentes = contaPresenca();
  var faltas = Math.max(total - presentes, 0);
  var percent = total > 0 ? Math.ceil((presentes * 100) / total) : 0;

  $("#totalPresentes").html(presentes);
  $("#totalMatriculados").html(total);
  $("#totalFaltas").html(faltas);
  $("#totalPercent").html(percent + "%");
}
```

- [ ] **Step 2: Criar funcao para aplicar estado visual**

Adicionar:

```javascript
function aplicaEstadoPresenca($checkbox) {
  var id = $checkbox.val();
  var $justificativa = $("#j" + id);
  var $motivo = $("#m" + id);

  if ($checkbox.is(":checked")) {
    $("#" + id).css({ "background-color": "#0F0" });
    $justificativa.prop("checked", false).prop("disabled", true);
    $motivo.val("").prop("disabled", true);
    $checkbox.css({ width: "18px", height: "18px" });
    return;
  }

  $("#" + id).css({ "background-color": "#FD1A3C" });
  $justificativa.prop("disabled", false);
  $checkbox.css({ width: "13px", height: "13px" });
}
```

- [ ] **Step 3: Substituir validacao de array**

Trocar:

```javascript
if (idMatriculaEBD < 1) {
```

por:

```javascript
if (idMatriculaEBD.length < 1) {
```

- [ ] **Step 4: Adicionar evento do botao**

Adicionar:

```javascript
$("#marcarTodos").on("click", function () {
  var $botao = $(this);
  var marcar = $botao.attr("aria-pressed") !== "true";

  $("input[name='registroPresenca[]']").each(function () {
    var $checkbox = $(this);
    $checkbox.prop("checked", marcar);
    aplicaEstadoPresenca($checkbox);
  });

  $botao.attr("aria-pressed", marcar ? "true" : "false");
  $botao.toggleClass("is-active", marcar);
  $botao.contents().filter(function () {
    return this.nodeType === 3;
  }).last().replaceWith(marcar ? " Desmarcar todos" : " Marcar todos");

  atualizaTotais();
});
```

- [ ] **Step 5: Usar as funcoes nos eventos atuais**

No carregamento inicial e no click de `.caixa input[type=checkbox]`, chamar `aplicaEstadoPresenca($(this)); atualizaTotais();` em vez de repetir toda a logica.

- [ ] **Step 6: Validar JS**

Run:

```powershell
node --check ebd\turma\js\consultaChamadasRegistrada.js
```

Expected: sem erro de sintaxe.

---

### Task 4: Aplicar padrao visual recente

- [ ] **Step 1: Estilizar shell e toolbar**

Em `ebd/turma/css/consultaChamadasRegistrada.css`, manter `#fieldMat`, mas evoluir para visual consistente:

```css
#fieldMat {
  display: grid;
  grid-template-columns: 160px minmax(0, 1fr);
  gap: 10px 14px;
  align-items: center;
  margin: 18px 0 20px;
  padding: 18px;
  background: #fff;
  border: 1px solid #e7e2dd;
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(35, 31, 28, 0.06);
}

#fieldMat .acoes {
  grid-column: 1 / -1;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: flex-start;
  max-width: none;
}

#marcarTodos.is-active {
  background: #0f766e;
  color: #fff;
}
```

- [ ] **Step 2: Desktop em tabela**

Adicionar:

```css
.tblEntrada {
  width: 100%;
  border-collapse: collapse;
  background: #fff;
}

.tblEntrada th,
.tblEntrada td {
  padding: 10px 12px;
  border-bottom: 1px solid #eee7e2;
  vertical-align: middle;
}
```

- [ ] **Step 3: Mobile em cards por aluno**

Adicionar:

```css
@media (max-width: 760px) {
  #fieldMat {
    grid-template-columns: 1fr;
  }

  #fieldMat label {
    text-align: left;
  }

  .tblEntrada thead tr:nth-child(2) {
    display: none;
  }

  .tblEntrada tbody tr {
    display: block;
    margin-bottom: 12px;
    padding: 10px;
    border: 1px solid #eee7e2;
    border-radius: 8px;
    background: #fff;
  }

  .tblEntrada tbody td {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    border-bottom: 0;
  }

  .tblEntrada tbody td::before {
    content: attr(data-label);
    font-weight: 700;
    color: #6b5f58;
  }
}
```

---

### Task 5: Verificacao manual do fluxo

- [ ] **Step 1: Abrir fluxo de origem**

No sistema local, acessar a tela que lista aulas registradas e acionar uma data. O POST deve continuar indo para:

```text
painel.php?pagina=ebd/turma/consultaChamadasRegistrada
```

- [ ] **Step 2: Conferir edicao de presenca**

Validar:

- Marcar um aluno atualiza presentes, faltas e percentual.
- Desmarcar um aluno libera justificativa.
- Justificar falta libera motivo.
- Salvar continua chamando `painel.php?pagina=ebd/aluno/atualizaChamadaAcao`.

- [ ] **Step 3: Conferir Marcar todos**

Validar:

- Primeiro clique marca todos os alunos como presentes.
- Segundo clique desmarca todos.
- Ao marcar todos, justificativas e motivos ficam limpos/desabilitados.
- Totais nao exibem `NaN%` nem `Infinity%`.

- [ ] **Step 4: Conferir licao**

Validar:

- Revista em uso aparece.
- Capa aparece quando `foto_revista` vier no JSON.
- Licao ministrada aparece quando ja cadastrada.
- Edicao/insercao de licao continua chamando `ebd/aluno/atualizaLicaoMinistrada.php`.

- [ ] **Step 5: Rodar validacoes finais**

Run:

```powershell
php -l ebd\turma\consultaChamadasRegistrada.php
php -l ebd\turma\dados\consultaChamadasRegistradasDados.php
node --check ebd\turma\js\consultaChamadasRegistrada.js
```

Expected: todos sem erro.

---

## Notes

- Nao alterar `ebd/relatorio/js/aulasRegistradas.js`, salvo se a navegacao quebrar durante teste manual.
- Nao reescrever `ebd/aluno/atualizaChamadaAcao.php` neste plano; ele e dependencia do fluxo e deve ficar para uma fase de hardening separada.
- O padrao visual deve seguir a escolha ja adotada em EBD: desktop em tabela e mobile em cards, preservando markup semantico.
- `idCongregacao = 0` continua sendo valor valido em EBD. Este plano nao deve introduzir `empty()` ou `!empty()` para filtrar congregacao.
