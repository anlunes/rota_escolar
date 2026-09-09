-- Migration 035: adiciona proprietario_id em vans
-- Identifica o gestor (dono da frota) que é dono da van.
-- Para motoristas comuns, proprietario_id fica NULL.
-- Executar em: rotaescolar.app.br (Localweb)

ALTER TABLE vans
  ADD COLUMN proprietario_id BIGINT UNSIGNED NULL DEFAULT NULL
    COMMENT 'motorista_id do gestor dono desta van (NULL = van do próprio motorista)',
  ADD CONSTRAINT fk_vans_proprietario
    FOREIGN KEY (proprietario_id) REFERENCES motoristas (motorista_id)
    ON DELETE SET NULL;
