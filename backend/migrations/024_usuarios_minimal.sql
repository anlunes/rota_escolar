-- Migration 024: tornar usuarios tabela mínima de auth/routing
-- nome e telefone saem de usuarios e passam a viver só em motoristas/responsaveis
-- bairro_id passa a viver em responsaveis (antes ficava em usuarios)

-- usuarios.nome: passa a ser nullable (dados autoritativos ficam em motoristas/responsaveis)
ALTER TABLE usuarios
    MODIFY COLUMN nome VARCHAR(120) NULL DEFAULT NULL;

-- responsaveis: adiciona bairro_id (antes guardado em usuarios)
ALTER TABLE responsaveis
    ADD COLUMN bairro_id INT UNSIGNED NULL AFTER telefone;
