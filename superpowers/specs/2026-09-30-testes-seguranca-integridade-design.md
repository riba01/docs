# Portão de testes pré-deploy: segurança, ataque, responsividade e integridade

- **Data:** 2026-09-30
- **Status:** aprovado em conversa (seções 1–5), aguardando revisão do spec escrito
- **Classificação:** arquitetural (nova infraestrutura de testes)

## 1. Objetivo

Criar uma bateria de testes automatizados que funcione como **portão pré-deploy**: executada
localmente no WAMP com um único comando antes do upload manual para o HostGator. Se o portão
reprovar, os arquivos não sobem.

A bateria cobre quatro frentes:

1. **Validação de segurança** — classes de segurança testadas isoladamente.
2. **Prevenção a ciberataque** — ataques simulados via HTTP contra o ambiente local.
3. **Integridade dos dados** — consultas de consistência no banco local e regras de escrita em banco de teste.
4. **Responsividade** — telas renderizadas em navegador real em vários tamanhos.

### Critérios de sucesso

- `php tests/gate.php` executa todas as etapas e termina com exit `0` (tudo passou), `1` (algum
  teste reprovou) ou `2` (pré-requisito ausente: Apache/MySQL fora, `.env.local` faltando).
- `php tests/gate.php --fast` roda só lint + unitários + scripts legados, em menos de 1 minuto.
- Cada reprovação aparece em `tests/out/gate-report.md` com etapa, arquivo/rota e motivo.
- Um arquivo PHP novo que receba `$_POST` entra automaticamente nos testes de CSRF e autenticação.
- Nenhum teste executa contra host diferente de `localhost`/`127.0.0.1`.

### Decisões tomadas na conversa

| Pergunta | Decisão |
|---|---|
| Uso principal | Portão pré-deploy |
| Banco da integridade | Os dois: leitura no banco local `conie847_sisconiecp`, escrita em `sisconiecp_test` com tabelas `TEMPORARY` |
| Scripts legados em `tests/` | Rodam como estão, chamados pelo runner (exit 0/1) |
| Contas para testes autenticados | Criadas por script no banco local e removidas ao final |
| Ferramentas | PHPUnit 13 (já instalado) + Playwright (`@playwright/test`, Chromium) |

### Fora do escopo

- Corrigir as vulnerabilidades e inconsistências encontradas (projeto seguinte, a partir do relatório).
- CI, teste de carga/DoS, varredura contra produção.
- Migrar os scripts legados para PHPUnit.
- OWASP ZAP / sqlmap (exigem Java/Python e geram ruído; payloads dirigidos cobrem os mesmos vetores).

## 2. Contexto do repositório

- `tests/` já contém ~23 scripts avulsos (PHP com `exit(1)` em falha, JS via `node`, Python em
  `tests/autenticador/`). `tests/portaria/README.md` define a convenção `SISCONIECP_TEST_DSN` e
  tabelas `TEMPORARY` em `sisconiecp_test`.
- PHPUnit 13.2.1 está em `vendor/bin`, sem `phpunit.xml`.
- `package.json` não tem framework de teste JS.
- 85 arquivos `*Acao.php` leem `$_POST`; apenas 56 arquivos chamam `Csrf::validateToken`.
- `validar_usuario_coniecp.php` confere apenas `$_SESSION['rm']`; não barra perfil nas primeiras linhas.
- Endpoints de upload legados acessíveis: `uploadfiles/uploadify.php`,
  `script/jquery.fileupload.v.1.5.0/upload.php`, arquivos `* copy.php` e `*_old.php`.
- 115 tabelas InnoDB e somente 5 `FOREIGN KEY` no `sql/schema.sql`: integridade referencial
  depende de código e precisa ser verificada por consulta.
- Login: `index.php` posta `email`, `senha`, `perfil` e `csrf_token` para `login.php`.

## 3. Estrutura e runner

```
tests/
  gate.php                 ponto único: roda tudo, resumo, exit 0/1/2
  bootstrap.php            autoload do Composer, leitura do .env.local, helpers
  .env.example             modelo versionado
  .env.local               valores reais (ignorado pelo git)
  Support/
    Env.php                leitura e validação do .env.local
    HttpClient.php         curl + cookie jar por instância + extração de csrf_token
    TestAccounts.php       cria/remove entidades e logins de teste
    EndpointCatalog.php    varre o repositório e classifica alvos
    Payloads.php           listas de payloads XSS/SQLi compartilhadas
    allowlist.php          exceções conscientes do catálogo, uma justificativa por linha
  Unit/Security/           PHPUnit: classes isoladas
  Http/Attack/             PHPUnit: ataques contra localhost
  Integrity/Read/          PHPUnit: SELECT no banco local
  Integrity/Write/         PHPUnit: sisconiecp_test com TEMPORARY
  Integrity/baseline.json  contagens aceitas por checagem de leitura
  e2e/
    pages.json             telas curadas para responsividade
    *.spec.js              Playwright
    baseline.json          violações aceitas de alvo de toque
  out/                     relatórios (ignorado pelo git)
  (pastas legadas intactas: assinatura/, portaria/, sessao/, pagamento15/, ...)
phpunit.xml                testsuites: unit, http, integrity-read, integrity-write
playwright.config.js
```

### Variáveis em `tests/.env.local`

| Chave | Uso |
|---|---|
| `GATE_BASE_URL` | ex.: `http://localhost/sisconiecp2` — o runner recusa host que não seja `localhost` ou `127.0.0.1` |
| `GATE_LOCAL_DSN`, `GATE_LOCAL_READ_USER`, `GATE_LOCAL_READ_PASSWORD` | banco local, usuário MySQL somente `SELECT` |
| `GATE_LOCAL_WRITE_USER`, `GATE_LOCAL_WRITE_PASSWORD` | banco local, usuário usado só por `TestAccounts` |
| `SISCONIECP_TEST_DSN`, `SISCONIECP_TEST_DB_USER`, `SISCONIECP_TEST_DB_PASSWORD` | banco `sisconiecp_test` (mesma convenção dos testes legados) |

### Ordem de execução do `gate.php`

1. Pré-requisitos: `.env.local` válido, host local, Apache responde em `GATE_BASE_URL`, MySQL conecta. Falha → exit 2.
2. `php -l` nos arquivos PHP alterados desde o último commit (`git diff --name-only HEAD` + não rastreados).
3. PHPUnit `unit`.
4. Scripts legados: cada um executado em processo separado; exit ≠ 0 é reprovação. Script que exige
   variável de ambiente ausente é **pulado com aviso**, não reprovado.
5. `TestAccounts::limparSobras()` e `TestAccounts::criar()`.
6. PHPUnit `http`, `integrity-read`, `integrity-write`.
7. Playwright.
8. `TestAccounts::remover()` — sempre, em `finally`.
9. Resumo em tabela (etapa × passou/reprovou/pulou) no terminal e em `tests/out/gate-report.md`.

Uma etapa reprovada não interrompe as seguintes; o relatório final mostra todas.

Flags: `--fast` (etapas 1–4 sem exigir Apache), `--suite=<unit|legado|http|integrity-read|integrity-write|e2e>`
para rodar uma etapa isolada.

## 4. Validação de segurança (PHPUnit `unit`)

Sem Apache nem banco. Incluída no `--fast`.

| Classe | Verificações |
|---|---|
| `Classes\Csrf` | token com 64 caracteres hex; token estável na mesma sessão; `validateToken` recusa vazio, token errado e token com um caractere trocado; comparação via `hash_equals` |
| `classes/security/Sanitizer.php`, `PortariaInputValidator` | todos os payloads XSS de `Payloads.php` saem sem código executável; HTML legítimo do TinyMCE (tabela, negrito, lista, imagem `data:`) preservado |
| `ConteudoBase64` | decodifica `<campo>_b64` válido; base64 inválido não quebra nem injeta; campo legado sem `_b64` permanece intacto |
| `Crypto` | `encrypt`→`decrypt` ida e volta; ciphertext diferente a cada chamada; adulterar um byte gera exceção; `blindIndex` determinístico |
| `PasswordResetToken` | formato e tamanho do token; `isValidFormat` recusa curto, não-hex, array e null; `hash` ≠ token; `expiresAt` no futuro correto |
| `StartSecureSession` | parâmetros do cookie: `httponly`, `samesite`, `secure` sob HTTPS, host não confiável não define `domain` |
| `AssinaturaAutorizacao::resolverAssinador` | ator não assina por outro sem permissão |
| `ValidarCpf`, `ValidarCnpj` | válidos, dígito errado, sequências repetidas, com e sem máscara, entrada lixo |
| `ocultarCPF` | nunca devolve o CPF completo |

`Payloads.php` contém ~30 payloads XSS (script, handlers `on*`, `javascript:`, `<svg onload>`,
`<iframe>`, entidades codificadas, caixa mista) e payloads SQLi apenas de leitura/tempo
(`' OR 1=1--`, `UNION SELECT`, `SLEEP(3)`, variações codificadas). Nenhum payload destrutivo
(`DROP`, `DELETE`, `UPDATE`).

## 5. Prevenção a ciberataque (PHPUnit `http`)

Executado contra `GATE_BASE_URL` com `HttpClient`.

### Catálogo automático (`EndpointCatalog`)

Varre o repositório excluindo `vendor/`, `node_modules/`, `backup/`, `tinymce/`, `tests/`, `docs/`.
Classifica:

- **handlers POST**: arquivos que leem `$_POST`/`INPUT_POST`;
- **páginas por área**: `coniecp/`, `iecp/`, `congregacao/`, `ebd/`, `usuario/`;
- **públicos**: `index.php`, `login.php`, `esqueci-senha.php`, `redefinir-senha.php`,
  `politica-privacidade.php`, `autenticador/` e demais listados na allowlist como públicos.

Exceções ficam em `tests/Support/allowlist.php`, cada entrada com justificativa. Arquivo novo entra
nos testes sem edição manual.

### Casos

| Grupo | Critério de aprovação |
|---|---|
| Autenticação | página/handler protegido sem sessão → redireciona para login ou responde 401/403, nunca 200 com dados; após logout o cookie antigo não dá acesso; ID de sessão muda após login |
| Autorização | matriz 5 perfis × 5 áreas: cada perfil acessa só sua área; congregação A não lê nem edita registro da congregação B trocando `id` em GET/POST (amostra de rotas com ID) |
| CSRF | todo handler POST do catálogo, com sessão válida: sem token, token errado e token de outra sessão → recusa **e nenhuma linha gravada** (contagem antes/depois nas tabelas afetadas pelas entidades de teste) |
| SQL injection | payloads SQLi em parâmetros GET/POST: resposta sem mensagem de erro SQL/PDO, tempo < 2,5 s, sem conteúdo adicional em relação à resposta com valor normal |
| XSS refletido | payloads XSS em parâmetros: resposta nunca contém o payload cru |
| Upload | `.php`, `.phtml`, `shell.php.jpg`, SVG com script, arquivo acima do limite, MIME falso → recusado; se aceito, a URL do arquivo não executa PHP |
| Exposição | 403/404 para `.env`, `config/*.php` servido como texto, `.git/`, `composer.json`, `*.sql`, `*.log`, `error_log`, `csp-violations.log`, `info.php`, `* copy.php`, `*_old.php`, uploads legados; sem listagem de diretório |
| Headers | presentes: CSP (ou Report-Only), `frame-ancestors`/`X-Frame-Options`, `X-Content-Type-Options: nosniff`, COOP, CORP; ausente: `X-Powered-By`; cookie de sessão com `HttpOnly` e `SameSite`; páginas de erro sem stack trace nem caminho `C:\wamp64` |
| Força bruta | N tentativas de login erradas seguidas → bloqueio ou atraso. Se não houver proteção, o teste reprova e documenta |

## 6. Integridade dos dados

### 6a. `integrity-read` — banco local, somente leitura

Conexão com usuário MySQL que tem apenas `GRANT SELECT`. Cada checagem é uma consulta que deve
retornar zero linhas; em reprovação lista até 20 IDs.

| Família | Checagens |
|---|---|
| Órfãos | `recibo_armazenado_*` sem item correspondente em `itembalancete_*`; `itembalancete_*` sem `balancete_*`; `anexo_oficio*` sem ofício; `historicocargo`/`historicofuncao`/`historicopunicao` sem `cadastroministro`; `login` sem ministro; `matriculaebd` sem turma; `certificado_2via` sem `certificado_consagracao` |
| Referências | `cadastroministro.idCongregacao` inexistente; congregação apontando IECP inexistente; `idStatusMinistro` fora de `statusministro` |
| Contábil | total gravado do balancete = soma dos itens; balancete finalizado sem itens; pagamento 15% sem duplicidade por mês de referência |
| Unicidade | e-mail de login duplicado; CPF duplicado; número de documento (portaria, ofício, circular) repetido no mesmo ano e emissor; código de certificado repetido |
| Formato | CPF inválido segundo `ValidarCpf`; datas `0000-00-00` ou anos fora de 1900–(ano atual + 1); e-mail inválido em `login` |
| Autenticador | `autenticador_doc` finalizado sem hash SHA-256 ou com arquivo ausente no disco |

Os nomes exatos de colunas são confirmados contra `sql/schema.sql` no plano de implementação.

**Linha de base:** `tests/Integrity/baseline.json` guarda a contagem aceita por checagem (ex.: 148
recibos órfãos conhecidos). O teste reprova somente se a contagem **aumentar**. Reduzir a baseline
é ação manual após limpeza.

### 6b. `integrity-write` — `sisconiecp_test`, tabelas `TEMPORARY`

Segue o padrão de `tests/portaria/`: o teste cria as tabelas `TEMPORARY` na conexão e injeta o PDO
no serviço/classe real.

- excluir item de balancete remove o recibo vinculado (regressão de `c061a5a1`);
- lançamento com valor negativo, não numérico ou `NaN` é recusado;
- mesma submissão repetida gera um único registro;
- falha no meio de gravação multi-tabela → rollback completo;
- texto com acentos, emoji e aspas é gravado e relido idêntico (utf8mb4);
- campo sensível cifrado com `Crypto` não aparece em texto puro na coluna.

Onde a regra vive em handler procedural sem classe injetável, o teste correspondente vai para o
grupo HTTP (seção 5) usando as entidades de teste, em vez de refatorar o handler.

## 7. Responsividade (Playwright)

- Chromium apenas. Viewports: 360×740, 768×1024, 1366×768, 1920×1080.
- Telas em `tests/e2e/pages.json` (lista curada): login, painel de cada perfil e ~15 telas mais
  usadas (balancete, dashboards IECP/CONIECP, cadastros de documento, membros, credencial). Cada
  entrada define perfil de login e parâmetros necessários.
- Login feito uma vez por perfil; `storageState` reaproveitado.

| Checagem | Critério |
|---|---|
| Overflow horizontal | `document.documentElement.scrollWidth ≤ innerWidth` em todos os viewports |
| Alvos de toque | em 360 px, botões/links visíveis ≥ 44×44 px; violações comparadas com `tests/e2e/baseline.json` |
| Menu | em 360 px o menu colapsa e abre/fecha por clique |
| Tabelas | DataTables em 360 px: o contêiner rola, a página não |
| Texto | nenhum texto visível com fonte < 12 px; nenhum elemento visível fora da área horizontal |
| Console/CSP | nenhum erro JS e nenhuma violação CSP ao carregar |
| XSS armazenado | payload gravado por formulário real (conta de teste) e aberto na listagem/visualização não dispara `dialog` nem executa script |

Screenshots salvos em `tests/e2e/out/` apenas em falha.

## 8. Contas e entidades de teste (`TestAccounts`)

- Cria no banco local, com o usuário de escrita: IECP e congregação com prefixo `TESTE_GATE`,
  ministros e 5 logins `teste_gate_<perfil>@invalid.local` (coniecp, iecp, congregação, EBD, usuário),
  senha aleatória gerada a cada execução e guardada só em memória/arquivo temporário do processo.
- Duas congregações de teste (A e B) para o teste de IDOR.
- Tudo que os testes HTTP/Playwright gravarem fica vinculado a essas entidades.
- `limparSobras()` no início remove resíduos de execução interrompida (mesmo prefixo);
  `remover()` no fim, sempre executado.
- As tabelas e colunas exatas usadas para criar login e perfil são levantadas no plano a partir de
  `login.php`, `defineNivel.php` e `sql/schema.sql`.

## 9. Falhas e relatório

- Exit codes: `0` passou, `1` reprovação, `2` pré-requisito ausente.
- Cada etapa é independente; exceção inesperada numa etapa vira reprovação dela, não aborta o runner
  (exceto etapa 1).
- `tests/out/gate-report.md`: por etapa, cada reprovação com arquivo/rota, caso e motivo. É a lista
  de correções do projeto seguinte.
- `.gitignore` recebe: `tests/.env.local`, `tests/out/`, `tests/e2e/out/`, `test-results/`,
  `playwright-report/`.

## 10. Expectativa da primeira execução

A primeira rodada deve reprovar em vários pontos (ex.: ~29 handlers POST sem validação CSRF,
possível acesso entre perfis, uploads legados expostos, ausência de limite de tentativas de login).
Isso é o resultado esperado: o portão passa a funcionar como lista priorizada. Para permitir deploys
enquanto as correções não chegam, reprovações conhecidas de segurança podem ser registradas em
`tests/Support/allowlist.php` com justificativa e data — a allowlist aparece inteira no relatório
para não virar esquecimento.

## 11. Dependências novas

- npm dev: `@playwright/test` + `npx playwright install chromium`.
- Nenhuma dependência PHP nova (PHPUnit 13 já instalado; `curl` e `pdo_mysql` já presentes).
- Dois usuários MySQL locais: leitura (`SELECT` em `conie847_sisconiecp`) e escrita (para
  `TestAccounts`), além do acesso já documentado a `sisconiecp_test`.
