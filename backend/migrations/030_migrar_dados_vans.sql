-- ============================================================
-- Migration 030 - Migrar dados de motoristas → vans
--
-- Cria uma linha em `vans` para cada motorista que já possui
-- dados de veículo (placa, CRLV, modelo) ou van_code.
-- Motoristas sem nenhum dado de veículo NÃO geram linha em vans —
-- a linha será criada quando salvarem a localização no perfil.
--
-- EXECUTAR APÓS: migration 029_criar_vans.sql
-- ============================================================

INSERT INTO vans (
    motorista_id,
    van_code,
    veiculo_placa,
    veiculo_modelo,
    crlv_url,
    crlv_exercicio,
    vagas_van,
    seguro_url,
    autorizacao_url,
    created_at
)
SELECT
    motorista_id,
    van_code,
    veiculo_placa,
    veiculo_modelo,
    crlv_url,
    crlv_exercicio,
    vagas_van,
    seguro_url,
    autorizacao_url,
    NOW()
FROM motoristas
WHERE van_code        IS NOT NULL
   OR veiculo_placa   IS NOT NULL
   OR crlv_url        IS NOT NULL
   OR seguro_url      IS NOT NULL
   OR autorizacao_url IS NOT NULL;

-- Validação: exibe motoristas migrados vs. total
SELECT
    (SELECT COUNT(*) FROM vans)                   AS vans_criadas,
    (SELECT COUNT(*) FROM motoristas)             AS total_motoristas,
    (SELECT COUNT(*) FROM motoristas
     WHERE van_code IS NOT NULL
        OR veiculo_placa IS NOT NULL
        OR crlv_url IS NOT NULL)                  AS motoristas_com_dados_van;
