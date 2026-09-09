-- Migration 033: Unicidade de CPF na tabela motoristas
-- Garante que nenhum CPF pode ser registrado em mais de uma conta de motorista.
-- Executar em: rotaescolar.app.br (Localweb)

ALTER TABLE motoristas
  ADD UNIQUE KEY uq_motoristas_cpf (cpf);
