-- Migration 013: índices para autocomplete eficiente de escolas
-- FULLTEXT permite busca por palavra no nome (muito mais rápido que LIKE '%texto%')
-- Índice composto estado+municipio filtra o escopo antes da busca textual

ALTER TABLE `escolas`
    ADD FULLTEXT INDEX `idx_escola_nome_fulltext` (`nome`),
    ADD INDEX `idx_escola_estado_municipio` (`estado`, `municipio`);
