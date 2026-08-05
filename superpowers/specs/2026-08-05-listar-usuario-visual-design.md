# Listagem de usuários — direção visual

## Objetivo

Atualizar `iecp/usuario/listarUsuario` para seguir o padrão visual institucional das telas `listarMembroFoto` e `gerarCredencialMembro`, sem mudar a consulta, as colunas, os destinos de edição/exclusão ou o fluxo de confirmação.

## Direção aprovada

- Fundo geral azul-claro/cinza (`#f0f4f8`) e conteúdo em cartão branco.
- Cabeçalho de página com eyebrow, título, descrição e chip contextual.
- Resumo visual com total de usuários, acessos liberados, bloqueados e nunca acessados.
- Barra de busca/filtro no padrão dos componentes `lmf-*`/`gcm-*`.
- Tabela dentro de cartão responsivo, com status em badges e ações com ícones Bootstrap.
- Paleta institucional azul (`#1a3a6b`) com vermelho reservado para ações destrutivas e alerta de acesso.
- Foco visível, estados hover estáveis, `cursor: pointer` e adaptação para larguras de 375px, 768px, 1024px e 1440px.

## Limites

- Preservar a consulta SQL e os dados exibidos.
- Preservar `edit` enviando `rm` para `iecp/usuario/editarUsuario`.
- Preservar `del`, confirmação e POST para `coniecp/usuario/deletarUsuario.php`.
- Manter DataTables para busca, ordenação e paginação.
- Não adicionar dependências novas.
