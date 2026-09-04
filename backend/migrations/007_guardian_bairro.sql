-- Migration 007: coluna bairro_id na tabela usuarios
-- Permite ao responsável informar seu bairro no onboarding.

ALTER TABLE `usuarios`
    ADD COLUMN `bairro_id` INT UNSIGNED DEFAULT NULL AFTER `telefone`;
