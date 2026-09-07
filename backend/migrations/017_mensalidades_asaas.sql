-- Migration 017: colunas Asaas em mensalidades + asaas_customer_id em responsaveis

ALTER TABLE mensalidades
    ADD COLUMN asaas_customer_id  VARCHAR(100) NULL AFTER observacao,
    ADD COLUMN asaas_payment_id   VARCHAR(100) NULL AFTER asaas_customer_id,
    ADD COLUMN asaas_payment_link VARCHAR(500) NULL AFTER asaas_payment_id,
    ADD UNIQUE KEY uq_men_aluno_mes_ano (aluno_id, mes, ano);

ALTER TABLE responsaveis
    ADD COLUMN asaas_customer_id VARCHAR(100) NULL AFTER whatsapp;
