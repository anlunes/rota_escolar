<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$alunoId = (int)($_GET['aluno_id'] ?? 0);

try {
    $pdo = Database::getInstance();

    // Determine if motorista or responsavel
    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();

    if ($motorista) {
        $sql = "
            SELECT m.id, a.nome AS student_name, m.mes AS month, m.ano AS year,
                   m.valor AS amount, m.status, m.forma_pagamento AS payment_method,
                   m.data_vencimento AS due_date, m.data_pagamento AS payment_date,
                   m.observacao AS observation
            FROM mensalidades m
            JOIN alunos a ON a.aluno_id = m.aluno_id
            WHERE a.motorista_id = ?
        ";
        $params = [$motorista['motorista_id']];
    } else {
        $rStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
        $rStmt->execute([$uid]);
        $responsavel = $rStmt->fetch();
        if (!$responsavel) Response::error('Usuário não encontrado.', 404);

        $sql = "
            SELECT m.id, a.nome AS student_name, m.mes AS month, m.ano AS year,
                   m.valor AS amount, m.status, m.forma_pagamento AS payment_method,
                   m.data_vencimento AS due_date, m.data_pagamento AS payment_date,
                   m.observacao AS observation
            FROM mensalidades m
            JOIN alunos a ON a.aluno_id = m.aluno_id
            WHERE a.responsavel_id = ?
        ";
        $params = [$responsavel['responsavel_id']];
    }

    if ($alunoId) { $sql .= ' AND m.aluno_id = ?'; $params[] = $alunoId; }
    $sql .= ' ORDER BY m.ano DESC, m.mes DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro no banco de dados: ' . $e->getMessage(), 500);
}
