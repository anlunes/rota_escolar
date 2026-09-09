-- Migration 032: Adiciona roles gestor e contratado ao ENUM de usuarios
-- Executar em: rotaescolar.app.br (Localweb)

ALTER TABLE usuarios
  MODIFY COLUMN role ENUM('responsavel', 'motorista', 'gestor', 'contratado', 'admin')
  NOT NULL DEFAULT 'responsavel';
