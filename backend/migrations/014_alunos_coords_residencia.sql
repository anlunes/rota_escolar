-- Migration 014: coordenadas da residência do aluno
-- Permite armazenar o ponto exato marcado pelo responsável no Google Maps,
-- melhorando a precisão do cálculo de rota (quote.php).
ALTER TABLE alunos
    ADD COLUMN lat_residencia  DECIMAL(10,8) NULL DEFAULT NULL
        COMMENT 'Latitude confirmada pelo responsável via Google Maps',
    ADD COLUMN lon_residencia  DECIMAL(11,8) NULL DEFAULT NULL
        COMMENT 'Longitude confirmada pelo responsável via Google Maps';
