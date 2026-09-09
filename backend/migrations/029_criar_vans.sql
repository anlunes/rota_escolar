-- ============================================================
-- Migration 029 - Tabela vans
--
-- Separa a identidade da van do motorista.
-- A van é a entidade permanente (tem o QR code colado).
-- O motorista é temporário — pode mudar de van ou ser substituído.
--
-- Relação: vans.motorista_id → motoristas.motorista_id
--   "Quem está dirigindo esta van agora?"
-- Para buscar a van de um motorista: SELECT * FROM vans WHERE motorista_id = ?
--
-- UNIQUE em motorista_id: um motorista dirige uma van por vez.
-- Pode ser relaxado no futuro para empresas com frota e motoristas rotativos.
-- ============================================================

CREATE TABLE IF NOT EXISTS `vans` (
    `van_id`          INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `motorista_id`    INT UNSIGNED   NOT NULL COMMENT 'Motorista atual que dirige esta van',
    `van_code`        VARCHAR(20)    DEFAULT NULL  COMMENT 'Gerado ao salvar localização no perfil (UF+MUN+SEQ)',
    `veiculo_placa`   VARCHAR(10)    DEFAULT NULL,
    `veiculo_modelo`  VARCHAR(150)   DEFAULT NULL,
    `crlv_url`        VARCHAR(500)   DEFAULT NULL,
    `crlv_exercicio`  YEAR(4)        DEFAULT NULL,
    `vagas_van`       TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Capacidade total de passageiros da van',
    `seguro_url`      VARCHAR(500)   DEFAULT NULL  COMMENT 'Apólice APP (seguro de passageiros)',
    `autorizacao_url` VARCHAR(500)   DEFAULT NULL  COMMENT 'Alvará municipal de transporte escolar',
    `ativo`           TINYINT(1)     NOT NULL DEFAULT 1,
    `created_at`      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`van_id`),
    UNIQUE KEY `uq_vans_van_code`   (`van_code`),
    UNIQUE KEY `uq_vans_motorista`  (`motorista_id`),
    KEY            `idx_vans_placa` (`veiculo_placa`),
    CONSTRAINT `fk_vans_motorista`
        FOREIGN KEY (`motorista_id`) REFERENCES `motoristas` (`motorista_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
