-- Migration 019: CPF, subconta Asaas e dados bancários do motorista

ALTER TABLE motoristas
    ADD COLUMN cpf                  VARCHAR(14)  NULL                    AFTER email,
    ADD COLUMN asaas_account_id     VARCHAR(100) NULL                    AFTER cpf,
    ADD COLUMN chave_pix            VARCHAR(100) NULL                    AFTER asaas_account_id,
    ADD COLUMN banco_codigo         VARCHAR(10)  NULL                    AFTER chave_pix,
    ADD COLUMN banco_agencia        VARCHAR(10)  NULL                    AFTER banco_codigo,
    ADD COLUMN banco_agencia_digito VARCHAR(2)   NULL                    AFTER banco_agencia,
    ADD COLUMN banco_conta          VARCHAR(30)  NULL                    AFTER banco_agencia_digito,
    ADD COLUMN banco_conta_digito   VARCHAR(2)   NULL                    AFTER banco_conta,
    ADD COLUMN banco_tipo           ENUM('corrente','poupanca') NULL     AFTER banco_conta_digito;
