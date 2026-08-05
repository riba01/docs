# Lista de Presença da Assembleia Geral — Design

**Data:** 2026-08-05  
**Escopo:** `iecp/listaChamada/listaAssembleiaGeral`

## Objetivo

Modernizar a tela de geração da lista de presença, mantendo a rota e o fluxo PHP/Bootstrap existentes, com layout responsivo, acessibilidade, feedback claro e validação consistente no navegador e no servidor.

A solução reduzirá riscos técnicos relacionados à exposição indevida de dados pessoais, autorização por igreja, CSRF, injeção em HTML e parâmetros manipulados. Ela não constitui, isoladamente, certificação de conformidade legal; os documentos e processos de privacidade da organização continuam necessários.

## Experiência proposta

- Usar uma área principal sem `fieldset` ou largura fixa, com cartão fluido e largura máxima consistente com o restante do painel.
- Exibir título institucional escapado, descrição curta e uma seção de configuração com dois campos: tipo de assembleia e data.
- Usar `<input type="date">` com rótulo explícito, permitindo datas passadas e limitando apenas o futuro conforme a regra atual de até 15 dias.
- Renderizar a relação de ministros em tabela semântica dentro de um contêiner responsivo; em telas estreitas, permitir rolagem horizontal contida sem criar overflow da página.
- Cada checkbox terá `name="lista[]"`, valor escapado, `id` único e `<label>` associado. O controle “Selecionar todos” terá estado indeterminado e contador de selecionados.
- Exibir estado vazio quando não houver ministros elegíveis.
- Usar botão textual com ícone Bootstrap decorativo e rótulo “Gerar PDF”. Durante o envio, desabilitar o botão e informar “Gerando PDF…” via `aria-live`.
- Mostrar erros próximos aos campos e em uma região de alerta, sem depender de jQuery UI ou de bordas coloridas como único indicador.
- Respeitar `prefers-reduced-motion`, manter foco visível e garantir alvos de toque adequados.

Paleta local: fundo `#F8FAFC`, texto `#1E293B`, azul `#2563EB` para ações e foco, laranja `#F97316` apenas para a ação de geração. Tipografia `Inter, system-ui, sans-serif`, sem adicionar nova chamada externa de fonte.

## Fluxo e fronteiras de segurança

1. A página continua protegida por `valida_sessao_all.php` e `validar_usuario_iecp.php`.
2. O servidor gera/exibe o token por sessão usando `Classes\Csrf`.
3. O formulário envia `lista[]`, `tipo`, `data` e `csrf_token` para a rota atual. `idIecp` não será mais aceito do navegador.
4. O endpoint PDF iniciará a sessão segura e repetirá a autorização da página. O `idIecp` será obtido exclusivamente de `$_SESSION['idIecp']`.
5. O endpoint validará CSRF, método POST, tipo por lista permitida, data no formato ISO `Y-m-d` e RMs como inteiros positivos únicos.
6. A consulta buscará somente ministros elegíveis da IECP da sessão. A lista enviada será intersectada com os RMs retornados; valores de outra igreja ou inexistentes serão ignorados.
7. Toda informação dinâmica inserida no HTML do PDF será escapada com `htmlspecialchars`. O CSS será lido com caminho baseado em `__DIR__`.
8. Erros serão respondidos sem revelar SQL, caminhos, sessão ou dados pessoais; detalhes continuarão apenas no log do servidor.

## Arquivos e responsabilidades

- `iecp/listaChamada/listaAssembleiaGeral.php`: consulta parametrizada, saída escapada e marcação semântica/responsiva.
- `iecp/listaChamada/js/lista.js`: seleção em massa, contagem, validação acessível e estado de envio; sem montagem de HTML com valores de usuário.
- `iecp/listaChamada/css/lista.scss`: estilos locais responsivos; o conteúdo permanecerá CSS compatível com a forma como a aplicação já carrega esse arquivo.
- `iecp/listaChamada/pdf/gerarPdfListaPresentesAssembleia.php`: autenticação/autorização, CSRF, validação de entrada, consulta restrita à sessão e escaping do PDF.
- `iecp/listaChamada/pdf/mpdfstyletables.css`: somente ajustes de impressão se necessários para o PDF.

Não serão alteradas tabelas, dependências, menus, regras de cargo/status ou o modelo de dados nesta etapa.

## Critérios de aceite

- A tela funciona sem rolagem horizontal acidental em 375, 768, 1024 e 1440px.
- Usuários de teclado conseguem configurar, selecionar e gerar o PDF com foco visível.
- O botão informa seleção ausente, tipo/data inválidos e erro de envio de forma anunciável.
- O PDF não é gerado sem sessão válida, autorização para a IECP, CSRF válido e parâmetros válidos.
- Alterar `idIecp`, RMs, tipo ou data no POST não permite acessar dados de outra IECP nem produzir conteúdo HTML não escapado.
- Nomes e cargos com caracteres especiais ou conteúdo HTML aparecem como texto, não como marcação.
- O comportamento existente de separar presentes e faltosos e gerar assinaturas é preservado.

## Verificação

- Criar testes de regressão focados nas funções de validação/normalização do endpoint, aproveitando PHPUnit se a execução local estiver disponível.
- Executar `php -l` em todos os PHP alterados.
- Executar `npx eslint iecp/listaChamada/js/lista.js` se o ambiente suportar a configuração atual.
- Revisar diff, verificar ausência de arquivos de usuário no commit e fazer exercício manual no WAMP nos quatro breakpoints, incluindo envio válido e erros de validação.
