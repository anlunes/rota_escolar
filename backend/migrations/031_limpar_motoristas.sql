-- ============================================================
-- Migration 031 - Remover colunas de van da tabela motoristas
--
-- Após confirmar que a migration 030 migrou os dados corretamente,
-- remover as colunas que agora pertencem à tabela `vans`.
--
-- ATENÇÃO: executar SOMENTE após:
--   1. Rodar 030_migrar_dados_vans.sql e validar o resultado
--   2. Fazer backup do banco
--   3. Confirmar que o backend (Fase 2) já está apontando para `vans`
--
-- Verificação de segurança antes de executar:
--   SELECT motorista_id, van_code, veiculo_placa FROM motoristas
--   WHERE van_code IS NOT NULL OR veiculo_placa IS NOT NULL;
-- Se retornar linhas, confirme que todas estão também em `vans`.
-- ============================================================

ALTER TABLE motoristas
    DROP COLUMN van_code,
    DROP COLUMN veiculo_placa,
    DROP COLUMN veiculo_modelo,
    DROP COLUMN crlv_url,
    DROP COLUMN crlv_exercicio,
    DROP COLUMN vagas_van,
    DROP COLUMN seguro_url,
    DROP COLUMN autorizacao_url;
