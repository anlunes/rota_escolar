-- Migration 037: tabela solicitacoes_troca
-- Motorista contratado sem pool definido solicita troca de van ao gestor.
-- Executar em: rotaescolar.app.br (Localweb)

CREATE TABLE solicitacoes_troca (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  motorista_id    BIGINT UNSIGNED NOT NULL COMMENT 'contratado que solicitou',
  van_id_destino  BIGINT UNSIGNED NOT NULL COMMENT 'van que o contratado quer usar',
  gestor_id       BIGINT UNSIGNED NOT NULL COMMENT 'gestor que receberá a solicitação',
  status          ENUM('pendente','aprovado','rejeitado') NOT NULL DEFAULT 'pendente',
  mensagem        TEXT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_troca_motorista FOREIGN KEY (motorista_id)   REFERENCES motoristas (motorista_id) ON DELETE CASCADE,
  CONSTRAINT fk_troca_van       FOREIGN KEY (van_id_destino)  REFERENCES vans       (van_id)       ON DELETE CASCADE,
  CONSTRAINT fk_troca_gestor    FOREIGN KEY (gestor_id)       REFERENCES motoristas (motorista_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
