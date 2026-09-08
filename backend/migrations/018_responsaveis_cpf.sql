-- Migration 018: adiciona coluna cpf na tabela responsaveis

ALTER TABLE responsaveis
    ADD COLUMN cpf VARCHAR(14) NULL AFTER asaas_customer_id;
