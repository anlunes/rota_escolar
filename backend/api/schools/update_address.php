<?php
/**
 * POST /api/schools/update_address.php
 *
 * Salva o endereço de uma escola informado pelo responsável.
 * A escola fica com status 'verificado' aguardando o admin confirmar as coords.
 *
 * Body JSON: { escola_id, logradouro, cep }
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')    Response::methodNotAllowed();

AuthMiddleware::require();

$body      = json_decode(file_get_contents('php://input'), true) ?? [];
$escolaId  = isset($body['escola_id'])  ? (int)$body['escola_id']       : 0;
$logradouro = trim($body['logradouro'] ?? '');
$cep        = trim($body['cep']        ?? '');

if ($escolaId <= 0 || empty($logradouro)) {
    Response::error('escola_id e logradouro são obrigatórios.', 400);
}

try {
    $pdo = Database::getInstance();

    // Só atualiza se a escola ainda não tem logradouro (não sobrescreve dado já verificado)
    $stmt = $pdo->prepare("
        UPDATE escolas
        SET logradouro = ?, cep = ?
        WHERE escola_id = ? AND (logradouro IS NULL OR logradouro = '')
    ");
    $stmt->execute([$logradouro, $cep, $escolaId]);

    Response::success(['updated' => $stmt->rowCount() > 0]);

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
