SPEC UI-ASSINATURA-001
Redesign do modal "Autorizar assinatura eletrônica"

1. Objetivo

Substituir o modal legado de confirmação de assinatura eletrônica por um modal moderno, seguro, responsivo e visualmente consistente com aplicações corporativas atuais.

A implementação deve reproduzir com alta fidelidade o mockup aprovado, mantendo integralmente o fluxo funcional existente.

Não alterar regras de negócio, endpoint, persistência da assinatura ou mecanismo atual de autenticação.

O escopo desta tarefa é predominantemente UX/UI do modal e comportamento de interação.

2. Resultado visual esperado

O modal deve possuir esta hierarquia:

┌─────────────────────────────────────────────────────────────┐
│ │
│ [ESCUDO] Autorizar assinatura eletrônica [X] │
│ Confirme sua identidade para continuar │
│ │
│ ─────────────────────────────────────────────────────── │
│ │
│ Digite sua senha de acesso para autorizar esta │
│ assinatura. Sua senha será usada somente nesta │
│ confirmação. │
│ │
│ Senha de acesso [ícone segurança] │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ••••••••••••••• [olho] │ │
│ └─────────────────────────────────────────────────────┘ │
│ │
│ 🔒 Ambiente seguro. Sua confirmação é protegida. │
│ │
│ ─────────────────────────────────────────────────────── │
│ │
│ [ Cancelar ] [ 🔒 Autorizar assinatura ] │
│ │
└─────────────────────────────────────────────────────────────┘ 3. Overlay da página

Quando o modal estiver aberto:

background: rgba(15, 23, 42, 0.62);
backdrop-filter: blur(4px);

O conteúdo da aplicação atrás do modal deve permanecer visível, porém sem competir visualmente com a janela.

O usuário não pode interagir com elementos localizados atrás do modal.

O modal deve aparecer centralizado vertical e horizontalmente.

display: flex;
align-items: center;
justify-content: center;
padding: 24px;

Z-index suficientemente alto para ficar acima de menus, dropdowns, tooltips e demais componentes da interface.

Referência:

z-index: 10000; 4. Container principal
Desktop
Largura: 720px
Largura máxima: calc(100vw - 48px)
Altura: automática
Background: #FFFFFF
Border radius: 18px
Overflow: hidden

Sombra:

box-shadow:
0 24px 60px rgba(15, 23, 42, 0.22),
0 8px 24px rgba(15, 23, 42, 0.10);

Não utilizar borda escura ao redor do modal.

Opcionalmente:

border: 1px solid rgba(148, 163, 184, 0.18); 5. Cabeçalho

Padding:

padding: 32px 40px 28px;

Estrutura:

ícone título
subtítulo X

O ícone e os textos devem estar alinhados verticalmente.

6. Ícone principal de segurança

Utilizar:

shield + lock

ou equivalente visual.

Não utilizar emoji.

Container:

64px × 64px
border-radius: 50%
background: #EFF6FF

Ícone:

32px
stroke: #2563EB
stroke-width: 1.8 até 2

Sugestões caso o sistema use Lucide:

ShieldCheck
Shield
LockKeyhole

Preferência:

ShieldCheck 7. Título

Texto obrigatório:

Autorizar assinatura eletrônica

Estilo:

font-size: 28px;
font-weight: 700;
line-height: 1.25;
color: #0F172A;
letter-spacing: -0.02em;

Não usar uppercase.

8. Subtítulo

Texto:

Confirme sua identidade para continuar

Estilo:

font-size: 17px;
font-weight: 400;
line-height: 1.5;
color: #64748B;
margin-top: 6px; 9. Botão fechar

Posicionado no canto superior direito.

Área clicável:

40px × 40px

Ícone:

X
22px

Cor normal:

#64748B

Hover:

background: #F1F5F9;
color: #0F172A;

Border radius:

8px

Adicionar:

aria-label="Fechar" 10. Separador

Entre cabeçalho e conteúdo:

height: 1px;
background: #E2E8F0;

Margem horizontal:

40px 11. Área de conteúdo

Padding:

padding: 32px 40px 28px; 12. Texto explicativo

Usar exatamente:

Digite sua senha de acesso para autorizar esta assinatura. Sua senha será usada somente nesta confirmação.

Preferencialmente renderizado como um único parágrafo, permitindo quebra natural de linha.

Estilo:

font-size: 16px;
font-weight: 400;
line-height: 1.55;
color: #334155;

Largura máxima recomendada:

600px

Margem inferior:

28px 13. Label do campo

Texto:

Senha de acesso

Estilo:

font-size: 15px;
font-weight: 600;
line-height: 1.4;
color: #0F172A;

À direita do texto pode existir pequeno ícone de segurança.

Ícone:

16px
color: #2563EB

Não utilizar tooltip desnecessária.

14. Campo de senha

O campo deve ocupar 100% da largura disponível.

Dimensões:

height: 56px
width: 100%

Estilo padrão:

background: #FFFFFF;
border: 1px solid #CBD5E1;
border-radius: 10px;
padding-left: 16px;
padding-right: 52px;
font-size: 16px;
color: #0F172A;
outline: none;

Transição:

transition:
border-color 150ms ease,
box-shadow 150ms ease,
background-color 150ms ease; 15. Estado focus

Ao receber foco:

border-color: #2563EB;
box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.12);

Não utilizar o amarelo existente no modal legado.

16. Tipo do campo

Obrigatoriamente:

<input type="password">

Deve permitir alternar entre:

password
text

através do botão de visualização.

Nunca transportar ou armazenar a senha em:

localStorage
sessionStorage
cookie
query string
data attribute
HTML
DOM persistente 17. Botão mostrar/ocultar senha

Posicionado dentro do campo, no lado direito.

Área clicável mínima:

44px × 44px

Ícones:

Eye
EyeOff

Estado inicial:

senha oculta

ARIA dinâmico:

Mostrar senha
Ocultar senha

Clicar nesse botão não pode submeter o formulário.

Portanto:

type="button" 18. Informação de segurança

Imediatamente abaixo do input.

Margem superior:

14px

Estrutura:

[ícone cadeado] Ambiente seguro. Sua confirmação é protegida.

Container do ícone:

32px × 32px
background: #ECFDF3
border-radius: 50%

Ícone:

Lock
16px
color: #16A34A

Texto:

font-size: 14px;
color: #64748B;

Importante: essa mensagem é apenas informativa.

Não transformar em alert, banner ou box chamativo.

19. Rodapé

Separado do conteúdo através de:

border-top: 1px solid #E2E8F0;

Background:

#FFFFFF

Padding:

padding: 24px 40px;

Layout desktop:

display: flex;
align-items: center;
justify-content: space-between;
gap: 16px; 20. Botão Cancelar

Texto:

Cancelar

Dimensões:

height: 48px
min-width: 150px

Estilo:

background: #FFFFFF;
border: 1px solid #CBD5E1;
border-radius: 9px;
color: #334155;
font-size: 15px;
font-weight: 600;

Hover:

background: #F8FAFC;
border-color: #94A3B8;

Active:

background: #F1F5F9;

Não usar vermelho para cancelar.

21. Botão principal

Texto obrigatório:

Autorizar assinatura

Ícone:

Lock

Dimensões:

height: 48px
min-width: 230px

Estilo:

background: #2563EB;
border: 1px solid #2563EB;
border-radius: 9px;
color: #FFFFFF;
font-size: 15px;
font-weight: 600;

Hover:

background: #1D4ED8;
border-color: #1D4ED8;

Active:

background: #1E40AF;

Focus:

box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.20);

Ícone:

18px

Espaçamento ícone/texto:

8px 22. Regra de habilitação

Quando o campo estiver vazio:

Autorizar assinatura = disabled

Estilo:

opacity: 0.55;
cursor: not-allowed;

Quando houver conteúdo:

enabled

A presença de conteúdo no campo não significa que a senha é válida.

A validação definitiva continua sendo realizada pelo backend.

23. Submissão

Formulário deve permitir:

Enter → Autorizar assinatura

Desde que o campo possua conteúdo.

Fluxo:

usuário digita senha
↓
clica Autorizar assinatura
↓
bloquear nova submissão
↓
mostrar loading
↓
enviar senha para fluxo existente
↓
backend valida identidade
↓
sucesso ou erro

Não modificar o contrato existente de autenticação/assinatura.

24. Loading

Imediatamente após o envio:

Botão passa para:

Autorizando...

Adicionar spinner.

Exemplo visual:

[spinner] Autorizando...

Durante o processamento:

campo senha → disabled
botão autorizar → disabled
botão cancelar → disabled
X → preferencialmente disabled

Não permitir duplo clique.

Não permitir requisições simultâneas.

25. Erro de senha

Em caso de senha inválida, não fechar o modal.

Campo:

border-color: #DC2626;

Focus de erro:

box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.10);

Mensagem:

Senha incorreta. Verifique sua senha e tente novamente.

Estilo:

font-size: 14px;
font-weight: 400;
color: #DC2626;
margin-top: 8px;

Após erro:

limpar campo de senha
retornar foco para o input
reativar controles

Não informar detalhes internos do mecanismo de autenticação.

26. Erro técnico

Para falha de servidor, comunicação ou erro inesperado:

Não foi possível autorizar a assinatura. Tente novamente.

Não exibir ao usuário:

stack trace
SQL
nome de tabela
PHP warning
exception
endpoint interno
código sensível

Esses dados podem ser registrados apenas no mecanismo de log da aplicação.

27. Sucesso

Após confirmação bem-sucedida:

1. concluir fluxo atual da assinatura;
2. fechar o modal;
3. atualizar a interface conforme comportamento já existente;
4. apresentar confirmação de sucesso, caso o sistema já possua esse padrão.

Mensagem recomendada:

Assinatura autorizada com sucesso.

Não introduzir nova etapa de confirmação depois da senha.

28. Regra crítica de negócio

O modal NÃO deve permitir selecionar outro signatário.

O signatário deve continuar sendo determinado pelo usuário autenticado na sessão.

Fluxo obrigatório:

Usuário autenticado
↓
abre documento
↓
solicita assinatura
↓
informa sua própria senha
↓
backend valida a identidade
↓
assinatura é vinculada ao usuário autenticado

A interface nunca deve possuir:

select de usuário
campo de CPF do signatário
campo de e-mail do signatário
campo de nome do signatário
alteração manual do signatário

Isso preserva o modelo atual de assinatura do SWGA/SISCONIECP.

29. Fechamento do modal

Permitir fechar através de:

X
Cancelar
ESC

Clique no overlay:

não deve fechar o modal.

Motivo: trata-se de ação sensível e o fechamento acidental deve ser evitado.

30. Comportamento do ESC

Se não houver processamento:

ESC → fechar modal

Durante:

Autorizando...

ESC deve ser ignorado.

31. Foco inicial

Ao abrir:

campo Senha de acesso recebe foco automaticamente

O cursor deve estar pronto para digitação.

Não focar automaticamente no botão principal.

32. Focus trap

Enquanto o modal estiver aberto, TAB deve circular somente entre seus controles.

Sequência recomendada:

X
Senha
Mostrar senha
Cancelar
Autorizar assinatura

Após o último:

TAB → volta ao primeiro

Com Shift + TAB:

primeiro → último 33. Acessibilidade

Modal:

role="dialog"
aria-modal="true"

Associar:

aria-labelledby → título
aria-describedby → descrição

Campo:

autocomplete="current-password"

Não utilizar placeholder como substituto de label.

Contraste deve atender WCAG AA.

Área mínima dos elementos interativos:

44 × 44px 34. Responsividade
Até 768px

Modal:

width: calc(100vw - 32px);
max-width: 720px;

Padding:

24px

Título:

24px
Até 480px

Container:

width: calc(100vw - 24px)
border-radius: 14px

Header:

padding: 24px 20px 20px

Conteúdo:

padding: 24px 20px

Footer:

padding: 20px

Botões:

width: 100%

Ordem mobile:

Autorizar assinatura
Cancelar

Layout:

display: flex;
flex-direction: column;

O botão principal deve aparecer primeiro visualmente.

35. Tipografia

Não introduzir fonte externa apenas para este componente.

Usar a fonte já utilizada pela aplicação.

Fallback:

font-family:
Inter,
system-ui,
-apple-system,
BlinkMacSystemFont,
"Segoe UI",
sans-serif; 36. Tokens visuais obrigatórios
Primary 600 #2563EB
Primary 700 #1D4ED8
Primary 800 #1E40AF

Slate 900 #0F172A
Slate 700 #334155
Slate 500 #64748B
Slate 400 #94A3B8
Slate 300 #CBD5E1
Slate 200 #E2E8F0
Slate 100 #F1F5F9
Slate 50 #F8FAFC

Success #16A34A
Success BG #ECFDF3

Error #DC2626

White #FFFFFF

Não criar variações arbitrárias de azul.

37. Espaçamento

Aplicar escala consistente:

4px
6px
8px
12px
16px
20px
24px
28px
32px
40px

Evitar valores aleatórios como:

13px
17px
19px
23px
27px

exceto quando necessários para tipografia.

38. Animação de entrada

Permitida animação discreta.

Overlay:

opacity 0 → 1
150ms

Modal:

opacity 0 → 1
transform scale(.98) → scale(1)
180ms

Não utilizar:

bounce
slide exagerado
zoom forte
efeitos elásticos

O modal representa uma operação de segurança e deve transmitir estabilidade.

39. Arquitetura de implementação

Não misturar regras de assinatura com apresentação visual.

Separar logicamente:

Modal
PasswordField
ModalActions
estado de submissão
tratamento de erro
integração com fluxo existente

Caso o projeto atual seja legado e não possua componentes reutilizáveis, não é necessário introduzir framework novo apenas para este modal.

A implementação deve respeitar a stack atual do SWGA.

Não migrar para React, Vue, Bootstrap ou outra biblioteca somente por causa desta tarefa.

40. Segurança

O redesign não pode enfraquecer o mecanismo atual de assinatura.

Obrigatório:

senha enviada apenas na requisição de autenticação
HTTPS
validação server-side
identidade obtida da sessão autenticada
não confiar em userId enviado pelo front-end
não registrar senha em logs
não persistir senha
não devolver senha na resposta
não concatenar senha em URL

A identidade efetiva do signatário deve ser determinada pelo backend.

41. Preservar backend existente

Não alterar nesta tarefa:

estrutura do documento
hash existente
registro da assinatura
PDF
QR Code
armazenamento do documento
banco de dados
endpoint, salvo necessidade técnica comprovada
regra de vinculação do signatário

No fluxo atual do SISCONIECP/SWGA, o documento assinado é tratado como documento autenticado e o fluxo histórico possui registro do signatário e armazenamento do PDF. A modernização do modal não deve alterar essa camada.

42. Estados obrigatórios do componente

O agente deve implementar e testar visualmente:

1.  modal aberto
2.  input vazio
3.  input focado
4.  senha digitada
5.  senha visível
6.  senha oculta
7.  botão habilitado
8.  enviando/autorizando
9.  senha incorreta
10. erro de servidor
11. sucesso
12. desktop
13. tablet
14. mobile
15. navegação por teclado
16. Critérios de aceite

A tarefa somente pode ser considerada concluída quando:

[ ] Modal visualmente compatível com o mockup aprovado.
[ ] Modal centralizado corretamente.
[ ] Overlay escurece e suaviza o conteúdo de fundo.
[ ] Título correto.
[ ] Subtítulo correto.
[ ] Texto explicativo correto.
[ ] Ícone de segurança presente.
[ ] Campo de senha possui label permanente.
[ ] Campo possui show/hide password.
[ ] Botão Cancelar funciona.
[ ] Botão Autorizar assinatura funciona.
[ ] Enter envia o formulário.
[ ] ESC fecha quando permitido.
[ ] Clique fora não fecha.
[ ] Existe loading durante submissão.
[ ] Duplo envio é impedido.
[ ] Senha incorreta é tratada dentro do modal.
[ ] Erro de servidor é tratado.
[ ] Senha nunca é persistida no navegador.
[ ] Signatário continua sendo o usuário autenticado.
[ ] Não existe possibilidade de selecionar outro usuário.
[ ] Funciona com teclado.
[ ] Focus trap funciona.
[ ] Funciona em desktop.
[ ] Funciona em tablet.
[ ] Funciona em celular.
[ ] Não altera o fluxo atual da assinatura.
[ ] Não altera regras existentes do backend.
[ ] Não cria dependência visual desnecessária.
[ ] Não introduz warnings ou erros no console.
[ ] Não introduz regressões em outras telas. 44. Referência visual obrigatória para o agente

O agente deve tratar o mockup aprovado como referência visual principal.

Prioridades, nesta ordem:

1. Comportamento funcional e segurança.
2. Hierarquia visual do mockup.
3. Proporções.
4. Espaçamentos.
5. Tipografia.
6. Cores.
7. Ícones.
8. Microinterações.

Não interpretar o mockup apenas como "inspiração".

O objetivo é reproduzir o padrão visual apresentado, adaptando apenas dimensões necessárias para responsividade.

45. Instrução final para o agente

Implemente exclusivamente o redesign do modal de autorização de assinatura eletrônica conforme esta especificação. Preserve integralmente o fluxo funcional, autenticação, regras de negócio, identificação do signatário e integração existente. Não faça refatorações fora do escopo. Antes de alterar código, identifique os arquivos atualmente responsáveis pelo modal, formulário, autenticação e chamada de assinatura. Reutilize a arquitetura e dependências existentes sempre que tecnicamente adequadas. A interface final deve reproduzir com alta fidelidade o mockup fornecido, incluindo hierarquia, espaçamento, estados, responsividade, acessibilidade e comportamento descritos nesta SPEC. Não considere a tarefa concluída apenas porque o modal funciona: todos os critérios visuais, funcionais, responsivos, de acessibilidade e segurança devem ser validados.

Sugestão de identificação no projeto:

SPEC: UI-ASSINATURA-001
Feature: Redesign do modal de autorização de assinatura eletrônica
Prioridade: Alta
Tipo: Melhoria de UX/UI
Escopo: Front-end + integração existente
Breaking change: Não
Alteração de regra de negócio: Não
