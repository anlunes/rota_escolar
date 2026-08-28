-- Migration 003: adiciona status em bairros e escolas
-- municipio_id em bairros passa a armazenar o código IBGE do município

ALTER TABLE `bairros`
    ADD COLUMN `status` ENUM('pendente', 'ativo') NOT NULL DEFAULT 'pendente' AFTER `nome`;

ALTER TABLE `escolas`
    ADD COLUMN `status` ENUM('pendente', 'ativo') NOT NULL DEFAULT 'pendente';
