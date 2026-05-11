# Contexto da pasta `classes/` - SISCONIECP / SWGA

## Arquivos importantes

### `classes/Connect.php`

Responsabilidade:

- centralizar conexão com banco de dados;
- Nãso usar a criação manual de `mysqli` ou `PDO` diretamente nos módulos;
- manter padrão único de acesso ao banco.

Uso esperado:

- Usar a classe `Connect.php` em vez de criar nova conexão local;
- não expor credenciais em arquivos de módulo;
- manter prepared statements;
- evitar usar `SELECT *` sem necessidade;
- não alterar a classe sem avaliar impacto global.

Atenção:

- alteração em `Connect.php` é sensível, pois pode afetar todo o sistema.

### `classes/PdfComponentes.php`

Responsabilidade:

- centralizar componentes reutilizáveis de PDFs;
- cabeçalhos;
- rodapés;
- capas;
- blocos visuais;
- padronização de relatórios.

Uso esperado:

- antes de criar novo cabeçalho/rodapé/capa em PDF, verificar esta classe;
- reaproveitar métodos existentes;
- evitar CSS inline quando o módulo já possui stylesheet externo;
- manter compatibilidade com mPDF.
- Não alterar a classe sem avaliar impacto global.

Atenção:

- alteração nesta classe pode afetar vários relatórios PDF;
- em relatórios grandes, evitar HTML excessivo em uma única chamada `WriteHTML`.

## Orientações para uso com PDF

Quando trabalhar com mPDF:

- usar `PdfComponentes.php` quando houver cabeçalho, rodapé ou capa padronizada;
- carregar CSS externo quando possível;
- evitar CSS inline dentro do PHP;
- usar `WriteHTML($stylesheet, \Mpdf\HTMLParserMode::HEADER_CSS)` para stylesheet;
- dividir HTML grande em blocos quando houver risco de `pcre.backtrack_limit`;
- preservar margens e padrão visual do relatório existente.

## Orientações para banco de dados

Quando trabalhar com consultas:

- usar a conexão padrão do projeto;
- usar prepared statements;
- validar entradas com `filter_input`, casting seguro ou validação explícita;
- evitar `SELECT *`;
- usar aliases consistentes;
- preservar nomes de campos esperados pelo front-end;
- não alterar schema sem demanda explícita.

## Orientações para segurança

Ao usar qualquer classe da pasta `classes/`:

- não expor detalhes técnicos para o usuário final;
- usar `error_log()` para erros internos;
- sanitizar saída HTML com `htmlspecialchars`; cuidado pois o projeto usar tinymce em muitas partes;
- proteger contra SQL Injection com prepared statements;
- preservar autenticação, sessão, permissões e CSRF;
- não alterar fluxo sensível sem plano prévio.

## Como o Claude deve trabalhar

Antes de alterar qualquer arquivo que dependa de `classes/`:

1. Identificar quais classes são usadas no arquivo.
2. Verificar se existe helper equivalente antes de criar novo código.
3. Fazer alteração mínima.
4. Preservar contratos existentes.
5. Executar `php -l` nos arquivos alterados.
6. Informar impacto potencial se alterar classe global.

## Classificação de risco

Alterações em arquivos de `classes/` devem ser tratadas como **Sensíveis** quando envolverem:

- conexão com banco;
- autenticação;
- sessão;
- CSRF;
- PDF usado por múltiplos módulos;
- componente compartilhado;
- validação global;
- segurança.

Alterações apenas em uso local de uma classe podem ser classificadas como **Média**, desde que não alterem a própria classe.

## Padrão de resposta esperado

Ao alterar arquivos que usam `classes/`, responder com:

1. Classificação da demanda.
2. Classes identificadas.
3. Arquivos alterados.
4. Motivo da alteração.
5. O que foi preservado.
6. Testes executados.
7. Riscos ou pontos de atenção.
8. Pendências, se houver.
