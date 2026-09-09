-- Migration 036: tabela van_pool
-- Define quais motoristas contratados podem usar qual van do gestor.
-- Se um motorista contratado está no pool de uma van, pode trocar sem aprovação.
-- Executar em: rotaescolar.app.br (Localweb)

CREATE TABLE van_pool (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  van_id          BIGINT UNSIGNED NOT NULL,
  motorista_id    BIGINT UNSIGNED NOT NULL COMMENT 'motorista contratado autorizado',
  autorizado_por  BIGINT UNSIGNED NOT NULL COMMENT 'motorista_id do gestor que autorizou',
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_van_motorista (van_id, motorista_id),
  CONSTRAINT fk_pool_van        FOREIGN KEY (van_id)         REFERENCES vans       (van_id)       ON DELETE CASCADE,
  CONSTRAINT fk_pool_motorista  FOREIGN KEY (motorista_id)   REFERENCES motoristas (motorista_id) ON DELETE CASCADE,
  CONSTRAINT fk_pool_autorizado FOREIGN KEY (autorizado_por) REFERENCES motoristas (motorista_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
