-- Migration 004: tabela de log de resets de rota
-- Registra cada operação de reset feita pelo admin,
-- preservando o histórico mesmo quando os dados são zerados.

CREATE TABLE IF NOT EXISTS `rota_resets` (
    `id`           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `motorista_id` INT UNSIGNED    NULL COMMENT 'NULL = todos os motoristas',
    `data_servico` DATE            NOT NULL,
    `tipo`         ENUM('mysql','rtdb','ambos') NOT NULL DEFAULT 'ambos',
    `alunos_afetados` INT UNSIGNED NOT NULL DEFAULT 0,
    `admin_user`   VARCHAR(100)    NOT NULL DEFAULT 'admin',
    `reset_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_motorista_data` (`motorista_id`, `data_servico`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
