# Credencial de membro no CONIECP — Desenho

## Objetivo

Levar para `coniecp/credencial/gerarCredencialMembro` a mesma experiência de consulta e geração de credenciais disponível em `iecp/membro/credencial/gerarCredencialMembro`, preservando o contexto administrativo central do CONIECP.

## Escopo

- Reproduzir a estrutura visual acessível, os estados de feedback, a busca por nome e a seleção em lote.
- Disponibilizar os dez cargos usados pelo fluxo de membros.
- Manter o seletor de uma ou todas as IECPs.
- Manter os endpoints CONIECP de listagem, registro de entrega e PDF.
- Não alterar consultas, registro de entrega ou geração do PDF.

## Fluxo

1. O usuário escolhe uma IECP, o status da credencial e os cargos.
2. A tela envia os filtros para `coniecp/credencial/entregarCredencial_lista.php`.
3. A lista retornada é renderizada, inicializa os datepickers e pode ser filtrada localmente por nome.
4. O usuário seleciona membros, registra entrega/validade ou abre o PDF em nova aba.
5. Mensagens de carregamento, aviso, sucesso e falha ficam em uma região acessível ao leitor de tela.

## Decisões de interface

- Usar cartões e controles da tela IECP como referência, com identidade textual CONIECP.
- Usar SVG/Bootstrap Icons já disponíveis no projeto; não introduzir emojis.
- Manter foco visível, alvos de toque confortáveis, contraste alto e layout responsivo.
- Respeitar `prefers-reduced-motion` nas transições.

## Verificação

- Teste estrutural CLI para garantir os dez cargos, busca, endpoints e contratos de acessibilidade.
- `php -l` no PHP alterado.
- `npx eslint` no JavaScript alterado, se a configuração aceitar o arquivo legado.
- Revisão do diff para confirmar que nenhuma rota CONIECP foi substituída por rota IECP.
