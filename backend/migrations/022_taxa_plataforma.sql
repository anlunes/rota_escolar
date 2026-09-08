-- Migration 022: taxas da plataforma sobre pagamentos em dinheiro

CREATE TABLE IF NOT EXISTS `taxa_plataforma` (
    `id`               INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `motorista_id`     INT UNSIGNED   NOT NULL,
    `mensalidade_id`   INT UNSIGNED   NOT NULL,
    `mes`              TINYINT        NOT NULL COMMENT '1-12',
    `ano`              SMALLINT       NOT NULL,
    `valor_base`       DECIMAL(10,2)  NOT NULL COMMENT 'valor da mensalidade paga em dinheiro',
    `taxa`             DECIMAL(10,2)  NOT NULL COMMENT '2% do valor_base',
    `status`           ENUM('pendente','cobrado','pago') NOT NULL DEFAULT 'pendente',
    `asaas_payment_id` VARCHAR(100)   NULL,
    `created_at`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_taxa_mensalidade` (`mensalidade_id`),
    KEY `idx_taxa_motorista_mes`     (`motorista_id`, `mes`, `ano`),
    KEY `idx_taxa_status`            (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
