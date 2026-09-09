-- ============================================================
-- Migration 027 - Tabela van_municipios para geração do VanCode
-- Controla o código sequencial de municípios (MUN) e o contador
-- de motoristas por município (SEQ) no formato UF+MUN(3)+SEQ(4).
-- Exemplo: RJ0010001 = Rio de Janeiro, município 001, 1º motorista
-- ============================================================

CREATE TABLE IF NOT EXISTS `van_municipios` (
    `id`           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `municipio_id` INT           NOT NULL,
    `uf`           CHAR(2)       NOT NULL,
    `seq`          SMALLINT      NOT NULL COMMENT 'Código sequencial do município (MUN, 3 dígitos)',
    `van_count`    SMALLINT      NOT NULL DEFAULT 1 COMMENT 'Contador de motoristas neste município (SEQ, 4 dígitos)',
    `created_at`   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_vm_municipio` (`municipio_id`),
    UNIQUE KEY `uq_vm_uf_seq`    (`uf`, `seq`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Zera van_codes antigos no formato VAN+hex (6 chars hex após "VAN")
-- para que recebam o novo formato na próxima vez que o motorista
-- salvar o endereço no perfil. Códigos já no novo formato são preservados.
UPDATE motoristas
SET van_code = NULL
WHERE van_code REGEXP '^VAN[0-9A-F]{6}$';
