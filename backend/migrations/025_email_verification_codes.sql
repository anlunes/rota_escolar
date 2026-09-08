-- Migration 025: tabela de códigos de verificação de e-mail (6 dígitos)
-- Mesma estrutura de password_reset_codes

CREATE TABLE IF NOT EXISTS email_verification_codes (
    id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email      VARCHAR(255) NOT NULL,
    code       CHAR(6)      NOT NULL,
    expires_at DATETIME     NOT NULL,
    created_at DATETIME     NOT NULL DEFAULT NOW(),
    INDEX idx_email (email),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
