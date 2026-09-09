-- Migration 028: endereço residencial do motorista (para fins de cobrança)
-- CPF já existe desde migration 019
-- estado_uf aqui é a UF da residência (vem do CEP), diferente de pref_estado_id (área de atendimento)

ALTER TABLE motoristas
    ADD COLUMN cep         VARCHAR(9)   NULL AFTER cpf,
    ADD COLUMN logradouro  VARCHAR(150) NULL AFTER cep,
    ADD COLUMN numero      VARCHAR(20)  NULL AFTER logradouro,
    ADD COLUMN complemento VARCHAR(100) NULL AFTER numero,
    ADD COLUMN bairro_nome VARCHAR(100) NULL AFTER complemento,
    ADD COLUMN cidade      VARCHAR(100) NULL AFTER bairro_nome,
    ADD COLUMN estado_uf   VARCHAR(2)   NULL AFTER cidade;
