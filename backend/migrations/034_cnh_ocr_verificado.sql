-- Migration 034: flag de verificação OCR da CNH em motoristas
-- cnh_ocr_verificado: 1 = CPF da CNH conferido via OCR, 0 = não verificado (foto ou OCR falhou)
-- Executar em: rotaescolar.app.br (Localweb)

ALTER TABLE motoristas
  ADD COLUMN cnh_ocr_verificado TINYINT(1) NOT NULL DEFAULT 0;
