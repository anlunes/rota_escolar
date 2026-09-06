-- Migration 016: valor de serviço mensal por aluno (definido pelo motorista)
ALTER TABLE motoristas
    ADD COLUMN valor_servico DECIMAL(8,2) NOT NULL DEFAULT 0.00;
