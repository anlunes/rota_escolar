-- Migration 020: walletId da subconta Asaas do motorista (usado no split de pagamento)

ALTER TABLE motoristas
    ADD COLUMN asaas_wallet_id VARCHAR(100) NULL AFTER asaas_account_id;
