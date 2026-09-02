-- Migration 005: tabela para códigos de redefinição de senha
CREATE TABLE IF NOT EXISTS password_reset_codes (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  email      VARCHAR(255) NOT NULL,
  code       CHAR(6)      NOT NULL,
  expires_at DATETIME     NOT NULL,
  used       TINYINT(1)   NOT NULL DEFAULT 0,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_code  (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
