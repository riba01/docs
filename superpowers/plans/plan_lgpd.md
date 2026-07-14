Fase 0 — Pré-requisitos de segurança (urgente, sem isso criptografia é inútil)

    1. Tirar credenciais do código. Connect.php passa a ler .env (ou arquivo de config fora do webroot). Classe mantém mesma interface Connect::getInstance() — zero impacto nos
    módulos.
    2. Eliminar md5 de senha por completo. Remover fallback md5 de login.php, admin/verificaSenha.php, meus-dados/alterarSenhaAntiga/; forçar reset para contas ainda em md5.

Manter
só Argon2id. 3. Nunca guardar senha (nem hash) em $\_SESSION. Corrigir login.php:118 e usuario/meus-dados/verificaSenha.php. 4. Mover para fora do webroot: backup/, sql/\*.sql (dumps), logs/, csp-violations.log, error_log, uploadfiles//Fotos/ (servir fotos via script com checagem de sessão, não URL
direta). 5. HTTPS forçado + session.cookie_secure, httponly, samesite (criptografia em trânsito — exigência LGPD art. 46).

    Fase 1 — Inventário de dados (base legal)

    - Mapear tabelas/colunas com dados pessoais: membros, ministros, alunos EBD, usuários, mensagens. Classificar: identificador (CPF, RG), contato (telefone, e-mail, endereço),
    sensível (foto, possivelmente dados de saúde/eclesiásticos — dado religioso é sensível por definição na LGPD, art. 5º II — filiação a organização religiosa).
    - Gerar documento docs/lgpd/inventario-dados.md como registro de tratamento (art. 37).

    Fase 2 — Criptografia em repouso, camada 1: transparente (zero risco pro sistema)

    MySQL InnoDB encryption-at-rest (ENCRYPTION='Y' por tabela + keyring). Protege arquivos físicos/discos/backups roubados. Nenhuma linha de PHP muda — aplicação continua lendo
    dados normalmente. Primeiro passo porque é o único sem risco funcional.

    - Backups: mysqldump | gpg (ou openssl enc) — dump nunca em claro no disco.

    Fase 3 — Criptografia em repouso, camada 2: nível de aplicação (campos críticos)

    Só para campos que exigem proteção mesmo contra acesso ao banco (DBA, SQL injection): CPF, RG e o que inventário apontar. Endereço/telefone: avaliar custo-benefício — camada

2
quebra LIKE, ORDER BY, relatórios.

    Arquitetura (não quebra sistema):

    1. Nova classe classes/Crypto.php — libsodium (sodium_crypto_secretbox) ou defuse/php-encryption via Composer. Métodos: encrypt(), decrypt(), blindIndex().
    2. Blind index para busca: coluna cpf_bidx = HMAC-SHA256(cpf, chave_index). Busca por CPF vira WHERE cpf_bidx = ? — busca exata continua funcionando; LIKE em CPF não
    (aceitável).
    3. Migração sem downtime, por tabela:
      - a. adicionar colunas cpf_enc VARBINARY, cpf_bidx CHAR(64) (coluna antiga fica);
      - b. dual-write: gravações escrevem nas duas;
      - c. backfill em lotes via script CLI;
      - d. trocar leituras para _enc (poucos pontos: Ministro.class.php, fichas, credencial PDF, meus-dados/);
      - e. validar relatórios/PDFs (credencial, ficha ministro, matrícula EBD);
      - f. zerar e dropar coluna antiga.
    4. Gestão de chaves: chave mestra em .env/arquivo fora do webroot, permissão 400; nunca no banco nem no git. Prever rotação (versionar chave no prefixo do ciphertext —

defuse
já faz).

    O que NÃO criptografar campo a campo: chaves primárias, campos de junção, datas usadas em filtros de relatório, nomes (busca/ordenação em listagens como listarMembros.php
    quebraria). Nome protegido pela camada 2 (fase 2) + controle de acesso.

    Fase 4 — Direitos do titular

    - meus-dados/ já existe → estender: exportar dados (portabilidade, art. 18 V), solicitar correção.
    - Exclusão/anonimização: rotina que anonimiza membro desligado após prazo de retenção (manter registros eclesiásticos exigidos por estatuto = base legal, documentar).
    - Consentimento: termo no cadastro + registro de aceite (data, IP, versão do termo).
    - Política de privacidade publicada; página de contato do encarregado (DPO).

    Fase 5 — Auditoria e resposta a incidentes

    - Log de acesso a dados pessoais (quem visualizou ficha/CPF de quem, quando) — tabela auditoria_acesso.
    - Retenção de logs sem dados pessoais em claro (hoje log/ e error_log merecem revisão).
    - Procedimento de notificação de incidente à ANPD (art. 48).

    Ordem de execução sugerida

    ┌─────┬─────────────────────────────────────────────┬────────────────────────────────┬─────────────┐
    │  #  │                    Item                     │       Risco pro sistema        │   Esforço   │
    ├─────┼─────────────────────────────────────────────┼────────────────────────────────┼─────────────┤
    │ 1   │ Fase 0 (credenciais, md5, sessão, webroot)  │ baixo                          │ 1-2 dias    │
    ├─────┼─────────────────────────────────────────────┼────────────────────────────────┼─────────────┤
    │ 2   │ Fase 2 (InnoDB encryption + backup cifrado) │ quase nulo                     │ 1 dia       │
    ├─────┼─────────────────────────────────────────────┼────────────────────────────────┼─────────────┤
    │ 3   │ Fase 1 (inventário)                         │ nenhum                         │ paralelo    │
    ├─────┼─────────────────────────────────────────────┼────────────────────────────────┼─────────────┤
    │ 4   │ Fase 3 (CPF/RG cifrados + blind index)      │ médio, mitigado por dual-write │ 1-2 semanas │
    ├─────┼─────────────────────────────────────────────┼────────────────────────────────┼─────────────┤
    │ 5   │ Fases 4-5                                   │ baixo                          │ incremental │
    └─────┴─────────────────────────────────────────────┴────────────────────────────────┴─────────────┘

    Ponto-chave: criptografia transparente (fase 2) resolve "dados no banco cifrados" pra maior parte da LGPD sem tocar em código; criptografia por campo (fase 3) fica restrita

a
CPF/RG com blind index pra não quebrar buscas.

    Quer que eu comece? Sugiro Fase 0 item 1 (.env no Connect.php) — maior ganho, menor risco.

● Começar Fase 0 item 1: Connect.php lê .env. Ler contexto primeiro.
