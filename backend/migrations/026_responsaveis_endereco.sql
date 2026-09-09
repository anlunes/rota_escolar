-- Migration 026: endereço completo do responsável (via ViaCEP)
-- cpf já existe desde migration 018
-- bairro_nome substitui a FK bairro_id para o responsável

ALTER TABLE responsaveis
    ADD COLUMN cep         VARCHAR(9)   NULL AFTER cpf,
    ADD COLUMN logradouro  VARCHAR(150) NULL AFTER cep,
    ADD COLUMN numero      VARCHAR(20)  NULL AFTER logradouro,
    ADD COLUMN complemento VARCHAR(100) NULL AFTER numero,
    ADD COLUMN bairro_nome VARCHAR(100) NULL AFTER complemento,
    ADD COLUMN cidade      VARCHAR(100) NULL AFTER bairro_nome,
    ADD COLUMN estado_uf   VARCHAR(2)   NULL AFTER cidade;
