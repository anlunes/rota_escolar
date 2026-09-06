-- Migration 015: fila de solicitações de orçamento
-- Registra quando um responsável solicita orçamento mas o endereço ainda não tem coords precisas.
-- Admin confirma as coords no painel → próxima chamada ao quote.php calcula e entrega o resultado.
CREATE TABLE IF NOT EXISTS solicitacoes_orcamento (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    aluno_id      INT NOT NULL,
    motorista_id  INT NOT NULL,
    status        ENUM('pendente', 'pronto') NOT NULL DEFAULT 'pendente',
    created_at    DATETIME NOT NULL DEFAULT NOW(),
    updated_at    DATETIME NOT NULL DEFAULT NOW(),
    UNIQUE KEY uq_aluno_motorista (aluno_id, motorista_id),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
