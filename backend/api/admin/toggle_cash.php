<?php
/**
 * POST /api/admin/toggle_cash.php
 *
 * Ativa/desativa o aceite de pagamento em dinheiro para um motorista.
 * Protegido pela mesma sessão de admin do painel.
 * Body JSON: { motorista_id: int, aceita_dinheiro: bool }
 */

session_start();
require_once __DIR__ . '/../../admin/config.php';
require_once __DIR__ . '/../../config/database.php';

header('Content-Type: application/json');

if (empty($_SESSION[ADMIN_SESSION_KEY])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Não autorizado.']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método não permitido.']);
    exit;
}

$body         = json_decode(file_get_contents('php://input'), true) ?? [];
$motoristaId  = (int)($body['motorista_id']   ?? 0);
$aceitaVal    = isset($body['aceita_dinheiro']) ? (int)(bool)$body['aceita_dinheiro'] : null;

if (!$motoristaId || $aceitaVal === null) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Parâmetros inválidos.']);
    exit;
}

try {
    $pdo = Database::getInstance();
    $pdo->prepare("UPDATE motoristas SET aceita_dinheiro = ? WHERE motorista_id = ?")
        ->execute([$aceitaVal, $motoristaId]);

    echo json_encode([
        'success'          => true,
        'motorista_id'     => $motoristaId,
        'aceita_dinheiro'  => (bool)$aceitaVal,
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
