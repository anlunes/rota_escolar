-- Migration 012: coordenadas geográficas e status estendido em escolas
-- lat/lon: precisão de 5 casas decimais (~1 metro) é suficiente, usamos 7 por padrão
-- status expandido para refletir resultado do processo de verificação automática

ALTER TABLE `escolas`
    ADD COLUMN `lat`              DECIMAL(10, 7)  DEFAULT NULL AFTER `cep`,
    ADD COLUMN `lon`              DECIMAL(10, 7)  DEFAULT NULL AFTER `lat`,
    ADD COLUMN `geocode_fonte`    VARCHAR(50)     DEFAULT NULL AFTER `lon`,
    MODIFY COLUMN `status` ENUM(
        'pendente',        -- cadastrada pelo pai, aguardando verificação
        'verificado',      -- lat/lon encontrados automaticamente (Overpass/Nominatim)
        'nao_encontrado',  -- script não encontrou no OSM — revisão manual necessária
        'ativo',           -- aprovado pelo admin
        'rejeitada'        -- rejeitada pelo admin (não existe ou duplicada)
    ) NOT NULL DEFAULT 'pendente';
