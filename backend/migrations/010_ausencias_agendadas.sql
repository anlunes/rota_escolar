-- Migration 010: ausências agendadas pelo responsável
CREATE TABLE IF NOT EXISTS ausencias_agendadas (
    id             INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    aluno_id       INT UNSIGNED   NOT NULL,
    responsavel_id INT UNSIGNED   NOT NULL,
    data           DATE           NOT NULL,
    criado_em      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_ausencia (aluno_id, data),
    KEY idx_ausencia_data    (data),
    KEY idx_ausencia_aluno   (aluno_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
