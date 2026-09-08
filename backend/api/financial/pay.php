<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$body        = json_decode(file_get_contents('php://input'), true) ?? [];
$financialId = (int)($body['financial_id'] ?? 0);
$method      = trim($body['method'] ?? 'cash');

if (!$financialId) Response::error('financial_id é obrigatório.');

try {
    $pdo = Database::getInstance();

    // Verify motorista owns this record
    $chk = $pdo->prepare("
        SELECT m.id FROM mensalidades m
        JOIN alunos a ON a.aluno_id = m.aluno_id
        JOIN motoristas mt ON mt.motorista_id = a.motorista_id
        WHERE m.id = ? AND mt.uid = ?
    ");
    $chk->execute([$financialId, $uid]);
    if (!$chk->fetch()) Response::error('Registro não encontrado.', 404);

    $pdo->prepare("
        UPDATE mensalidades SET status='pago', forma_pagamento=?, data_pagamento=NOW(), updated_at=NOW()
        WHERE id=?
    ")->execute([$method, $financialId]);

    Response::success(['id' => $financialId], 'Pagamento registrado.');
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
