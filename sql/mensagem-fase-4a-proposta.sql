-- ============================================================
--  PROPOSTA SQL — Fase 4A do módulo de mensagens internas
--  Projeto: SISCONIECP2
--  Data: 2026-05-22
--
--  ⚠️  ESTE ARQUIVO É UMA PROPOSTA — NÃO EXECUTAR EM PRODUÇÃO
--      SEM ANTES:
--      1. Realizar backup completo das tabelas
--      2. Validar o backup (ver seção VERIFICAÇÃO PRÉ)
--      3. Testar em ambiente de staging/desenvolvimento
--      4. Executar em janela de baixo uso (fora do horário comercial)
--      5. Ter plano de rollback pronto (ver seção ROLLBACK)
-- ============================================================

-- ============================================================
-- DIAGNÓSTICO ATUAL (executar antes — somente leitura)
-- ============================================================

-- Estado das tabelas
SHOW TABLE STATUS LIKE 'mensagem';
SHOW TABLE STATUS LIKE 'mensagemenviada';

-- Estrutura atual
SHOW CREATE TABLE mensagem;
SHOW CREATE TABLE mensagemenviada;

-- Índices atuais (apenas PK em ambas)
SHOW INDEX FROM mensagem;
SHOW INDEX FROM mensagemenviada;

-- Contagem de registros
SELECT
    'mensagem'           AS tabela,
    COUNT(*)             AS total,
    SUM(status = 0)      AS nao_lidas,
    SUM(status = 1)      AS lidas,
    SUM(recebidaEm IS NULL) AS sem_data_leitura,
    MAX(enviadaEm)       AS mais_recente
FROM mensagem
UNION ALL
SELECT
    'mensagemenviada',
    COUNT(*),
    SUM(status = 0),
    SUM(status = 1),
    SUM(recebidaEm IS NULL),
    MAX(enviadaEm)
FROM mensagemenviada;

-- Verificar registros órfãos (rm sem cadastro — importante antes de adicionar FK)
SELECT COUNT(*) AS orfaos_remetente_mensagem
FROM mensagem m
LEFT JOIN cadastroministro c ON m.remetenteRec = c.rm
WHERE c.rm IS NULL;

SELECT COUNT(*) AS orfaos_destinatario_mensagem
FROM mensagem m
LEFT JOIN cadastroministro c ON m.destinatarioRec = c.rm
WHERE c.rm IS NULL;

SELECT COUNT(*) AS orfaos_remetente_mensagemenviada
FROM mensagemenviada v
LEFT JOIN cadastroministro c ON v.remetenteEnv = c.rm
WHERE c.rm IS NULL;

-- Amostra dos 5 registros mais recentes (validação pós-migração)
SELECT idMensagemRec, remetenteRec, destinatarioRec, assuntoRec, enviadaEm, status
FROM mensagem
ORDER BY idMensagemRec DESC
LIMIT 5;

SELECT idMensagemEnv, remetenteEnv, destinatarioEnv, assuntoEnv, enviadaEm, status
FROM mensagemenviada
ORDER BY idMensagemEnv DESC
LIMIT 5;


-- ============================================================
-- ETAPA 1: BACKUP
-- (executar via terminal ANTES de qualquer ALTER)
-- ============================================================

-- Via mysqldump (linha de comando, não SQL):
--
--   mysqldump -u [usuario] -p [banco] mensagem mensagemenviada \
--       > backup_mensagens_$(date +%Y%m%d_%H%M%S).sql
--
-- Verificar arquivo gerado:
--   wc -l backup_mensagens_*.sql      (deve ter linhas)
--   grep "rows" backup_mensagens_*.sql (deve listar contagem)


-- ============================================================
-- ETAPA 2: CONVERTER ENGINE — MyISAM → InnoDB
-- ============================================================
-- Impacto: table lock breve (~1s para 778 linhas). Fazer fora do horário.
-- Motivo: permite transações reais (os dois INSERTs em enviarMensagemAcao
--         só serão atômicos após InnoDB + begin/commit na Fase 4B).

ALTER TABLE mensagem        ENGINE = InnoDB;
ALTER TABLE mensagemenviada ENGINE = InnoDB;

-- Verificar:
SHOW TABLE STATUS LIKE 'mensagem';          -- Engine deve ser InnoDB
SHOW TABLE STATUS LIKE 'mensagemenviada';


-- ============================================================
-- ETAPA 3: CONVERTER CHARSET — utf8mb3_bin → utf8mb4_unicode_ci
-- ============================================================
-- Impacto: reconstrói todos os índices de texto, table lock durante conversão.
-- Motivo:
--   - utf8mb3 não suporta emojis/caracteres fora do BMP
--   - _bin é collation binária (case-sensitive) — inadequada para texto de mensagens
--   - utf8mb4_unicode_ci é compatível com o charset das demais tabelas do projeto
--
-- ⚠️  Atenção: utf8mb3_bin → utf8mb4_unicode_ci muda a semântica de comparação:
--     'Abc' = 'abc' será TRUE com unicode_ci.
--     Nenhuma query atual do PHP compara assunto/texto em WHERE, então risco é baixo.

ALTER TABLE mensagem
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE mensagemenviada
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Verificar:
SHOW CREATE TABLE mensagem;
SHOW CREATE TABLE mensagemenviada;


-- ============================================================
-- ETAPA 4: ADICIONAR ÍNDICES
-- ============================================================
-- No InnoDB os índices são criados online (sem lock de escrita em versões modernas).
-- Ordem: índices de alta prioridade primeiro (caixa de entrada é a mais usada).

-- mensagem — caixa de entrada
-- Consulta principal: WHERE destinatarioRec = :rm ORDER BY enviadaEm DESC
CREATE INDEX idx_msg_dest_data
    ON mensagem (destinatarioRec, enviadaEm);

-- mensagem — filtro de não lidas
-- Consulta: WHERE destinatarioRec = :rm AND status = 0
CREATE INDEX idx_msg_dest_status
    ON mensagem (destinatarioRec, status);

-- mensagem — lookup por remetente (raramente usado, mas útil para auditoria)
CREATE INDEX idx_msg_remetente_data
    ON mensagem (remetenteRec, enviadaEm);

-- mensagemenviada — caixa de saída
-- Consulta principal: WHERE remetenteEnv = :rm ORDER BY enviadaEm DESC
CREATE INDEX idx_env_remetente_data
    ON mensagemenviada (remetenteEnv, enviadaEm);

-- mensagemenviada — lookup por destinatário (útil para pesquisa futura)
CREATE INDEX idx_env_dest_data
    ON mensagemenviada (destinatarioEnv, enviadaEm);

-- Verificar índices criados:
SHOW INDEX FROM mensagem;
SHOW INDEX FROM mensagemenviada;

-- Analisar impacto com EXPLAIN:
EXPLAIN SELECT * FROM mensagem WHERE destinatarioRec = 1 ORDER BY enviadaEm DESC;
EXPLAIN SELECT * FROM mensagemenviada WHERE remetenteEnv = 1 ORDER BY enviadaEm DESC;


-- ============================================================
-- ETAPA 5: ADICIONAR COLUNAS DE CONTROLE (OPCIONAL — Fase 4B)
-- ============================================================
-- Estas colunas preparam exclusão lógica e auditoria futura.
-- Adicioná-las agora é seguro (operação aditiva, sem impacto no código existente).
-- O PHP só usará esses campos após implementação da Fase 4B.
--
-- Avaliar com o time antes de executar esta etapa.

-- mensagem: exclusão lógica + arquivamento + auditoria
ALTER TABLE mensagem
    ADD COLUMN excluidaEm  DATETIME NULL DEFAULT NULL COMMENT 'NULL = ativa; preenchida = excluída logicamente',
    ADD COLUMN arquivadaEm DATETIME NULL DEFAULT NULL COMMENT 'NULL = não arquivada',
    ADD COLUMN atualizadoEm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP COMMENT 'Atualizado automaticamente pelo MySQL';

-- mensagemenviada: mesmas colunas
ALTER TABLE mensagemenviada
    ADD COLUMN excluidaEm  DATETIME NULL DEFAULT NULL COMMENT 'NULL = ativa; preenchida = excluída logicamente',
    ADD COLUMN arquivadaEm DATETIME NULL DEFAULT NULL COMMENT 'NULL = não arquivada',
    ADD COLUMN atualizadoEm TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP;

-- Índice para filtrar registros não excluídos (usado quando PHP implementar exclusão lógica)
CREATE INDEX idx_msg_dest_ativo
    ON mensagem (destinatarioRec, excluidaEm, enviadaEm);

CREATE INDEX idx_env_rem_ativo
    ON mensagemenviada (remetenteEnv, excluidaEm, enviadaEm);

-- Verificar:
SHOW CREATE TABLE mensagem;
SHOW CREATE TABLE mensagemenviada;


-- ============================================================
-- ETAPA 6: CHAVES ESTRANGEIRAS (OPCIONAL — depende de verificação de órfãos)
-- ============================================================
-- Só executar esta etapa se as queries de órfãos acima retornarem 0.
-- Se houver órfãos, tratar antes (decidir: excluir, reatribuir ou ignorar FK).
--
-- ATENÇÃO: ON DELETE RESTRICT impede exclusão de ministros com mensagens.
--          Avaliar se isso é desejado no contexto do projeto.

ALTER TABLE mensagem
    ADD CONSTRAINT fk_mensagem_remetente
        FOREIGN KEY (remetenteRec)   REFERENCES cadastroministro (rm) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_mensagem_destinatario
        FOREIGN KEY (destinatarioRec) REFERENCES cadastroministro (rm) ON DELETE RESTRICT;

ALTER TABLE mensagemenviada
    ADD CONSTRAINT fk_env_remetente
        FOREIGN KEY (remetenteEnv)   REFERENCES cadastroministro (rm) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_env_destinatario
        FOREIGN KEY (destinatarioEnv) REFERENCES cadastroministro (rm) ON DELETE RESTRICT;


-- ============================================================
-- VERIFICAÇÃO PÓS-MIGRAÇÃO
-- ============================================================

-- Contagens devem ser idênticas ao pré-migração
SELECT COUNT(*) AS total_mensagem       FROM mensagem;
SELECT COUNT(*) AS total_mensagemenviada FROM mensagemenviada;

-- Engine deve ser InnoDB
SHOW TABLE STATUS LIKE 'mensagem';
SHOW TABLE STATUS LIKE 'mensagemenviada';

-- Charset deve ser utf8mb4
SELECT
    TABLE_NAME,
    TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('mensagem', 'mensagemenviada');

-- Índices devem incluir os novos
SHOW INDEX FROM mensagem;
SHOW INDEX FROM mensagemenviada;

-- Testar query de caixa de entrada com EXPLAIN (deve usar índice, não full scan)
EXPLAIN SELECT * FROM mensagem WHERE destinatarioRec = 1 ORDER BY enviadaEm DESC;

-- Amostra dos mesmos 5 registros de antes — conteúdo deve ser idêntico
SELECT idMensagemRec, remetenteRec, destinatarioRec, assuntoRec, enviadaEm, status
FROM mensagem
ORDER BY idMensagemRec DESC
LIMIT 5;


-- ============================================================
-- ROLLBACK — em caso de problema
-- ============================================================
-- Executar apenas se a migração precisar ser revertida.
-- Ordem inversa da migração.

-- Remover FKs (se adicionadas)
ALTER TABLE mensagemenviada
    DROP FOREIGN KEY fk_env_destinatario,
    DROP FOREIGN KEY fk_env_remetente;

ALTER TABLE mensagem
    DROP FOREIGN KEY fk_mensagem_destinatario,
    DROP FOREIGN KEY fk_mensagem_remetente;

-- Remover colunas adicionadas
ALTER TABLE mensagemenviada
    DROP COLUMN excluidaEm,
    DROP COLUMN arquivadaEm,
    DROP COLUMN atualizadoEm;

ALTER TABLE mensagem
    DROP COLUMN excluidaEm,
    DROP COLUMN arquivadaEm,
    DROP COLUMN atualizadoEm;

-- Remover índices
DROP INDEX idx_env_rem_ativo     ON mensagemenviada;
DROP INDEX idx_env_dest_data     ON mensagemenviada;
DROP INDEX idx_env_remetente_data ON mensagemenviada;

DROP INDEX idx_msg_dest_ativo    ON mensagem;
DROP INDEX idx_msg_remetente_data ON mensagem;
DROP INDEX idx_msg_dest_status   ON mensagem;
DROP INDEX idx_msg_dest_data     ON mensagem;

-- Reverter charset (⚠️  dados utf8mb4-exclusivos serão perdidos se existirem)
ALTER TABLE mensagemenviada
    CONVERT TO CHARACTER SET utf8mb3 COLLATE utf8mb3_bin;

ALTER TABLE mensagem
    CONVERT TO CHARACTER SET utf8mb3 COLLATE utf8mb3_bin;

-- Reverter engine para MyISAM
ALTER TABLE mensagemenviada ENGINE = MyISAM;
ALTER TABLE mensagem        ENGINE = MyISAM;

-- Verificar rollback:
SHOW TABLE STATUS LIKE 'mensagem';
SHOW TABLE STATUS LIKE 'mensagemenviada';
