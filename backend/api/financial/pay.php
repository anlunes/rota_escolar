<?php
/**
 * POST /api/financial/pay.php
 *
 * Registra pagamento em dinheiro de uma mensalidade.
 * Body: { mensalidade_id: int }
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')   Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$body          = json_decode(file_get_contents('php://input'), true) ?? [];
$mensalidadeId = (int)($body['mensalidade_id'] ?? $body['financial_id'] ?? 0);

if (!$mensalidadeId) Response::error('mensalidade_id é obrigatório.');

try {
    $pdo = Database::getInstance();

    // Garante que a mensalidade pertence a este motorista
    $chk = $pdo->prepare("
        SELECT m.id, m.status FROM mensalidades m
        JOIN motoristas mt ON mt.motorista_id = m.motorista_id
        WHERE m.id = ? AND mt.uid = ?
        LIMIT 1
    ");
    $chk->execute([$mensalidadeId, $uid]);
    $men = $chk->fetch();

    if (!$men)                        Response::error('Mensalidade não encontrada.', 404);
    if ($men['status'] === 'pago')    Response::error('Esta mensalidade já foi paga.');

    $pdo->prepare("
        UPDATE mensalidades
        SET status = 'pago', forma_pagamento = 'dinheiro',
            data_pagamento = CURDATE(), updated_at = NOW()
        WHERE id = ?
    ")->execute([$mensalidadeId]);

    Response::success(['id' => $mensalidadeId], 'Pagamento em dinheiro registrado.');

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
