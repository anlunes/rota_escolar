-- Migration 023: flag para aceitar pagamentos em espécie por motorista
ALTER TABLE `motoristas`
    ADD COLUMN `aceita_dinheiro` TINYINT(1) NOT NULL DEFAULT 0
        COMMENT 'Motorista aceita receber mensalidades em dinheiro (default: não)'
    AFTER `asaas_customer_id`;
