# Cadastro de Usuário com Link de Ativação — Design

**Data:** 2026-08-06
**Escopo:** `iecp/usuario/cadastrarUsuario`

## Objetivo

Modernizar a tela de cadastro de acesso para seguir a linguagem visual de
`iecp/usuario/listarUsuario` e substituir o envio de senha em texto puro por um
link de ativação/redefinição de uso único. O fluxo deve manter a arquitetura
PHP/Bootstrap existente, funcionar em PHP 8.5+ e reforçar autorização, CSRF,
escapamento, validação de entrada e tratamento de erros.

## Experiência proposta

- Usar o mesmo shell visual da listagem: fundo claro, azul institucional
  `#1A3A6B`, cards brancos, bordas discretas, tipografia já carregada pelo
  painel, eyebrow “Administração” e chip de segurança.
- Exibir uma única ação primária: “Enviar link de ativação”. A página não terá
  campo de senha, senha oculta, botão “Gerar senha” nem senha renderizada no
  DOM.
- Apresentar um card de formulário com select pesquisável/nativo para escolher
  o ministro elegível, nome e e-mail visíveis na opção, e uma área de orientação
  explicando que o destinatário criará a própria senha.
- Usar labels associados, mensagens de erro próximas aos campos, região
  `aria-live` para carregamento/sucesso/erro, foco visível e alvos de toque de
  pelo menos 44px quando aplicável.
- Desabilitar o botão durante o envio, respeitar `prefers-reduced-motion` e
  manter comportamento responsivo em 375, 768, 1024 e 1440px.Aprovad

## Fluxo de ativação e redefinição

1. A página valida a sessão e o perfil IECP antes de consultar os ministros.
2. A consulta lista somente ministros ativos da IECP da sessão, com função
   elegível e sem registro correspondente em `login`.
3. O administrador seleciona o RM; o navegador envia apenas o RM e o
   `csrf_token`. E-mail e `idIecp` não são confiados ao cliente.
4. Um endpoint dedicado valida método POST, CSRF, RM inteiro positivo e vínculo
   do ministro com a IECP da sessão. A autorização é repetida no endpoint para
   impedir chamadas diretas ou manipulação de parâmetros.
5. Tokens pendentes do RM são invalidados. Um novo token de 32 bytes é gerado
   com `random_bytes`; somente o hash SHA-256 é salvo em
   `password_reset_tokens`, com validade de 45 minutos.
6. O endpoint envia ao e-mail já existente no cadastro um link para
   `redefinir-senha.php`. Nenhuma senha é criada, armazenada ou enviada por
   e-mail nesse momento.
7. `redefinir-senha.php` valida formato, expiração, uso único e CSRF. Ao salvar
   uma senha forte, executa transação que cria o registro em `login` quando for
   uma ativação ou atualiza o registro quando for uma redefinição, e marca o
   token como usado atomicamente.
8. O link não revela se o RM existe além do contexto autenticado do
   administrador; falhas de envio e banco retornam mensagens genéricas e são
   registradas apenas no log do servidor.

## Segurança e compatibilidade

- Remover a dependência do fluxo de cadastro em
  `meus-dados/cadastrarUsuarioAcao.php`, que atualmente recebe senha do
  navegador e envia credencial em texto puro.
- Remover credenciais SMTP hardcoded dos fluxos de envio envolvidos e usar
  `config/smtp.php`, provisionado fora do controle de versão, seguindo
  `config/smtp.example.php`.
- Não exibir exceções PDO, caminhos, credenciais, tokens brutos ou dados de
  infraestrutura na resposta HTTP.
- Usar `declare(strict_types=1)`, tipos escalares/retornos explícitos,
  `DateTimeImmutable`, `random_bytes`, `password_hash(..., PASSWORD_ARGON2ID)`
  e APIs sem chamadas legadas incompatíveis com PHP 8.5+.
- Manter consultas parametrizadas, escaping com
  `htmlspecialchars(..., ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` e resposta
  JSON com `JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES`.
- Não criar senha no frontend e não aceitar `email`, `idIecp` ou status de
  acesso enviados pelo navegador como fonte de autoridade.

## Arquivos e responsabilidades

- `iecp/usuario/cadastrarUsuario.php`: marcação semântica, consulta restrita,
  token CSRF e carregamento versionado de CSS/JS.
- `iecp/usuario/css/cadastrarUsuario.css`: visual `cu-*` alinhado aos tokens
  e estados de `listarUsuario.css`.
- `iecp/usuario/js/cadastrarUsuario.js`: seleção, confirmação, POST seguro,
  feedback acessível e prevenção de envio duplicado; sem inserção de HTML com
  dados de resposta.
- `iecp/usuario/enviarLinkAtivacao.php`: novo endpoint autenticado para
  gerar/inutilizar token, buscar o e-mail no banco, montar a URL e enviar o
  link.
- `redefinir-senha.php`: completar a ativação de contas sem `login`, tornar o
  consumo do token atômico e preservar o fluxo público existente de recuperação.
- `esqueci-senha.php` e um helper/configuração SMTP compartilhada, se
  necessário: eliminar credenciais expostas e preservar o mesmo formato de
  mensagem de link.
- `tests/`: testes focados para normalização, validade/uso único de tokens,
  autorização por IECP e regras de senha, conforme o runner disponível.

Não serão alteradas tabelas nesta etapa: será reutilizada a tabela existente
`password_reset_tokens`. Caso a instalação não possua essa tabela, a migração
de infraestrutura será reportada separadamente, sem criar SQL destrutivo no
fluxo da página.

## Critérios de aceite

- A página possui a mesma linguagem visual de `listarUsuario`, sem senha em
  campo oculto, HTML ou resposta do endpoint.
- Usuário sem perfil autorizado, RM de outra IECP, RM inexistente, método
  diferente de POST ou CSRF ausente/inválido são rejeitados.
- O link recebido é válido por 45 minutos, só pode ser usado uma vez e não
  contém a senha.
- O primeiro uso cria o login; usos posteriores redefinem a senha existente;
  ambos usam hash Argon2id e não armazenam senha em texto puro.
- Token antigo é invalidado ao solicitar novo link.
- E-mail e credenciais SMTP não são aceitos do navegador nem mantidos em
  código-fonte versionado.
- Nomes, e-mails e mensagens com HTML são tratados como texto.
- O fluxo funciona em PHP 8.5+ sem warnings/depreciações introduzidos pela
  alteração.

## Verificação

- Executar testes focados do fluxo de token/senha e, se disponível, PHPUnit.
- Executar `php -l` em todos os PHP alterados.
- Executar `npx eslint iecp/usuario/js/cadastrarUsuario.js`.
- Executar `git diff --check` e conferir que nenhum segredo ou token bruto foi
  adicionado.
- Exercitar manualmente: lista vazia, seleção válida, envio duplicado, erro de
  CSRF, novo link, link expirado, link usado e criação da senha em WAMP.
- Confirmar visual nos quatro breakpoints e navegação completa por teclado.
