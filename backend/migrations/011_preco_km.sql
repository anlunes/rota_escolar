-- Migration 011: preço por km do motorista (base para orçamento automático)
ALTER TABLE motoristas
  ADD COLUMN preco_km DECIMAL(5,2) DEFAULT NULL COMMENT 'Preço cobrado por km rodado (ida+volta)';
