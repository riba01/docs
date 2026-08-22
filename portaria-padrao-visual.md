# Padrão visual de Portaria

Este documento define o padrão das páginas de criação e consulta de Portaria.

## Escopo

- `coniecp/portaria/cadastrarPortaria.php`
- `coniecp/portaria/consultarPortaria.php`
- `coniecp/portaria/css/portaria-layout.css`

## Estrutura obrigatória

1. Cabeçalho da página com contexto, título `h1` e descrição curta.
2. Estado do documento em um card destacado.
3. Conteúdo, assinatura e auditoria em cards separados, com 16 px de intervalo.
4. Barra de ações própria após os cards.
5. Grade externa: menu `col-12 col-md-1 p-0 menu_sistema` e conteúdo `col-12 col-sm-11 col-md-10`.

## Ações

No desktop, os botões ficam alinhados à direita, na mesma borda direita dos cards, partindo dessa borda em direção ao centro. Em telas menores que 768 px, eles ocupam toda a largura, em ordem de leitura.

O botão de ativação é a ação principal. Salvar rascunho é secundário e voltar/cancelar é terciário. As regras de assinatura, a confirmação por senha e os IDs usados pelos scripts não devem ser alterados por mudanças visuais.

## Tokens

O padrão usa `Source Sans 3` no texto, `Readex Pro` nos títulos, fundo cinza-claro, cards brancos, borda `#cbd5e1` e azul institucional `#173b8f`. Estados semânticos usam âmbar para rascunho, verde para ativo e cinza para arquivado.
