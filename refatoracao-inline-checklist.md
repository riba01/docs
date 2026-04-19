# Refatoração de inline

## Regras

- Não alterar regra de negócio
- Extrair apenas script/style inline
- Valores dinâmicos PHP devem virar data-\*
- Testar tela após cada lote
- Commit por lote pequeno

## Lotes

- [ ] Lote 01 - scripts simples de listagem
- [ ] Lote 02 - CSS simples de tabelas e formulários
- [ ] Lote 03 - módulo mensagem
- [ ] Lote 04 - módulo credencial
- [ ] Lote 05 - módulo tesouraria
- [ ] Lote 06 - ficha de membro/ministro

## PROMPT PADRAO

Use este prompt como padrão no VS Code:
Você vai refatorar arquivos PHP legados deste projeto.

Objetivo:
Extrair apenas blocos <script> e <style> inline para arquivos externos em /assets/js e /assets/css, preservando integralmente o comportamento atual.

Regras obrigatórias:

1. Não alterar regra de negócio.
2. Não alterar consultas SQL, fluxos PHP, nomes de parâmetros POST/GET ou comportamento funcional.
3. Quando o JavaScript depender de valores dinâmicos do PHP, mover esses valores para atributos data-\* no HTML.
4. Manter compatibilidade com jQuery atual do projeto.
5. Não modernizar toda a base de uma vez. Faça o menor diff possível.
6. Se houver código repetido, proponha extração para utilitário compartilhado.
7. Ignorar arquivos backup, copy, old, sem uso, out/production, exceto se eu mandar explicitamente.
8. Ao final, mostre:
   - arquivos alterados
   - arquivos novos criados
   - riscos detectados
   - pontos a testar manualmente
