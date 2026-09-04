-- Migration 009: simplifica vagas da van para um único campo (capacidade total)
-- O sistema calcula disponível por turno subtraindo alunos ativos de cada turno

ALTER TABLE motoristas
  DROP COLUMN vagas_manha,
  DROP COLUMN vagas_tarde,
  ADD COLUMN vagas_van TINYINT UNSIGNED NOT NULL DEFAULT 0;
