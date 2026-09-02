-- Migration 006: adiciona token de reset próprio na tabela password_reset_codes
ALTER TABLE password_reset_codes
  ADD COLUMN reset_token            CHAR(64)  DEFAULT NULL AFTER used,
  ADD COLUMN reset_token_expires_at DATETIME  DEFAULT NULL AFTER reset_token,
  ADD INDEX idx_reset_token (reset_token);
