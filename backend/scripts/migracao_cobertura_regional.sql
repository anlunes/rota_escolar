-- ============================================================
-- REFATORACAO: COBERTURA REGIONAL DOS MOTORISTAS
-- ============================================================

CREATE TABLE IF NOT EXISTS estados (
    id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    uf CHAR(2) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    UNIQUE KEY uk_estados_uf (uf),
    KEY idx_estados_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS municipios (
    id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    estado_id INT(10) UNSIGNED NOT NULL,
    nome VARCHAR(100) NOT NULL,
    ibge INT(7) UNSIGNED DEFAULT NULL,
    UNIQUE KEY uk_municipios_ibge (ibge),
    KEY idx_municipios_estado (estado_id),
    KEY idx_municipios_nome (nome),
    CONSTRAINT fk_municipios_estado FOREIGN KEY (estado_id) REFERENCES estados(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bairros (
    id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    municipio_id INT(10) UNSIGNED NOT NULL,
    nome VARCHAR(100) NOT NULL,
    UNIQUE KEY uk_bairros_municipio_nome (municipio_id, nome),
    KEY idx_bairros_nome (nome),
    CONSTRAINT fk_bairros_municipio FOREIGN KEY (municipio_id) REFERENCES municipios(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS motorista_bairros (
    id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    motorista_id INT(10) UNSIGNED NOT NULL,
    bairro_id INT(10) UNSIGNED NOT NULL,
    UNIQUE KEY uk_motorista_bairro (motorista_id, bairro_id),
    KEY idx_motorista_bairros_motorista (motorista_id),
    KEY idx_motorista_bairros_bairro (bairro_id),
    CONSTRAINT fk_mb_motorista FOREIGN KEY (motorista_id) REFERENCES motoristas(motorista_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mb_bairro FOREIGN KEY (bairro_id) REFERENCES bairros(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Remover colunas obsoletas (executar manualmente se ainda existirem)
-- ALTER TABLE motoristas DROP COLUMN atend_municipio;
-- ALTER TABLE motoristas DROP COLUMN atend_uf;
-- ALTER TABLE motoristas DROP COLUMN cpf;
-- ALTER TABLE motoristas DROP COLUMN docs_verificados;
-- ALTER TABLE motoristas DROP COLUMN tem_seguro_app;
-- ALTER TABLE motoristas DROP COLUMN usuario_id;

-- Seed estados
INSERT INTO estados (uf, nome) VALUES
('AC', 'Acre'), ('AL', 'Alagoas'), ('AP', 'Amapa'), ('AM', 'Amazonas'),
('BA', 'Bahia'), ('CE', 'Ceara'), ('DF', 'Distrito Federal'), ('ES', 'Espirito Santo'),
('GO', 'Goias'), ('MA', 'Maranhao'), ('MT', 'Mato Grosso'), ('MS', 'Mato Grosso do Sul'),
('MG', 'Minas Gerais'), ('PA', 'Para'), ('PB', 'Paraiba'), ('PR', 'Parana'),
('PE', 'Pernambuco'), ('PI', 'Piaui'), ('RJ', 'Rio de Janeiro'), ('RN', 'Rio Grande do Norte'),
('RS', 'Rio Grande do Sul'), ('RO', 'Rondonia'), ('RR', 'Roraima'), ('SC', 'Santa Catarina'),
('SP', 'Sao Paulo'), ('SE', 'Sergipe'), ('TO', 'Tocantins');

-- Indices adicionais
CREATE INDEX idx_mb_bairro_motorista ON motorista_bairros(bairro_id, motorista_id);
CREATE INDEX idx_mb_motorista_bairro ON motorista_bairros(motorista_id, bairro_id);
CREATE INDEX idx_bairros_municipio_lookup ON bairros(municipio_id, nome);
