-- Migration 008: vagas por turno na van do motorista
ALTER TABLE motoristas
  ADD COLUMN vagas_manha TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN vagas_tarde TINYINT UNSIGNED NOT NULL DEFAULT 0;
