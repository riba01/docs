# Padrão de listagem de documentos — Portarias

## Objetivo

Criar uma referência visual e comportamental para telas de listagem de documentos no SISConIECP2, usando `coniecp/portaria/listarPortaria` como primeira aplicação. A tela deve facilitar a triagem por status, mostrar rapidamente os metadados essenciais e levar o usuário à consulta sem expor o conteúdo integral na lista.

## Decisão de design

Adotar um padrão híbrido: tabela semântica e compacta em telas médias/grandes; cards empilhados em telas pequenas. A listagem terá cabeçalho editorial, filtro de status, resumo da quantidade encontrada, área de resultados, estados de carregamento/erro/vazio e paginação acessível.

### Estrutura

1. Breadcrumb: `Documentos / Portarias`.
2. Cabeçalho com título `Portarias`, descrição curta e ação primária `Nova portaria`.
3. Barra de controle com label associado ao select de status e contador de documentos.
4. Card de resultados com título, descrição contextual e tabela/cards.
5. Cada documento mostra número, data, resumo de até duas linhas, status textual com ícone e ação explícita `Visualizar`.
6. Rodapé da lista com intervalo exibido e paginação.

### Estados

- Inicial: instrução para selecionar um status.
- Carregando: indicador visível e mensagem em `aria-live`.
- Sucesso: resultados com contador e paginação.
- Vazio: mensagem contextual e orientação para escolher outro status.
- Erro: mensagem de falha e orientação para tentar novamente.

## Linguagem visual

- Fundo: `#f1f5f9`; superfícies: `#ffffff`; texto principal: `#0f172a`; texto secundário: `#475569`.
- Ação institucional: `#173b8f`; foco acessível: `#0369a1` com anel visível.
- Bordas: `#cbd5e1`; cantos de 12px; sombras discretas.
- Títulos em `Readex Pro`, corpo em `Source Sans 3`, mantendo o padrão já adotado nas telas de cadastro e consulta de portaria.
- Status usa cor, ícone e texto: ativo (verde), elaboração (âmbar), arquivado (cinza) e cancelada (vermelho).
- Ícones existentes do sistema continuam sendo usados onde já estão disponíveis; botões icon-only recebem nome acessível.

## Responsividade e acessibilidade

- Em desktop, a tabela mantém colunas de largura previsível e resumo limitado visualmente.
- Em mobile, cada linha vira um card sem rolagem horizontal.
- Controles clicáveis têm área mínima de 44px, `:focus-visible` claro e transições curtas.
- A informação de status não depende apenas de cor.
- Mensagens dinâmicas usam `aria-live`; tabela usa `caption`, `scope` e ação com nome descritivo.
- Animações respeitam `prefers-reduced-motion`.

## Escopo técnico

- Atualizar `listarPortaria.php`, `listarPortariaAcao.php`, `coniecp/portaria/js/listarPortaria.js` e criar/ajustar o CSS específico da listagem.
- Preservar sessão, autorização, endpoint POST, status existentes, paginação e navegação para `consultarPortaria`.
- Não implementar busca textual nesta primeira aplicação, pois o endpoint atual não oferece filtro/paginação por termo; a área de controles deve permitir essa extensão futura sem redesenho.
- Não alterar as telas de cadastro ou consulta nesta etapa.

## Critérios de aceite

- A tela tem hierarquia visual clara antes da seleção de status.
- O conteúdo integral não aparece na listagem; cada item exibe somente resumo e ação de consulta.
- O filtro, carregamento, erro, vazio, sucesso e paginação continuam funcionais.
- A visualização é adequada em 375px, 768px, 1024px e 1440px.
- Arquivos PHP alterados passam em `php -l`; JS alterado passa no lint disponível ou em validação sintática equivalente.
