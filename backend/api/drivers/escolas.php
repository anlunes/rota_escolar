<?php
/**
 * GET  /api/drivers/escolas.php  → lista escolas do motorista
 * POST /api/drivers/escolas.php  → salva escolas do motorista
 * Body JSON: { "escola_ids": [1, 2] }
 */

ob_start();
ini_set('display_errors', 0);

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/firebase.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

function jsonOk($data, $message = 'OK', $status = 200) {
    ob_end_clean();
    http_response_code($status);
    echo json_encode(['success' => true, 'message' => $message, 'data' => $data]);
    exit;
}

function jsonErr($message, $status = 400) {
    ob_end_clean();
    http_response_code($status);
    echo json_encode(['success' => false, 'message' => $message]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { ob_end_clean(); http_response_code(200); exit; }

$header = $_SERVER['HTTP_AUTHORIZATION']
    ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
    ?? (function_exists('apache_request_headers') ? (apache_request_headers()['Authorization'] ?? '') : '')
    ?? '';

if (empty($header) || strpos($header, 'Bearer ') !== 0) jsonErr('Token ausente.', 401);

$token   = substr($header, 7);
$payload = FirebaseAuth::verifyToken($token);
if (!$payload) jsonErr('Token inválido ou expirado.', 401);

$uid = $payload['sub'] ?? null;
if (!$uid) jsonErr('UID não encontrado no token.', 401);

try {
    $pdo = Database::getInstance();

    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) jsonErr('Motorista não encontrado.', 404);
    $motoristaId = $motorista['motorista_id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $pdo->prepare("
            SELECT e.escola_id AS id, e.nome, e.bairro_id, e.bairro_nome
            FROM escolas_atendidas ea
            JOIN escolas e ON e.escola_id = ea.escola_id
            WHERE ea.motorista_id = ?
            ORDER BY e.nome
        ");
        $stmt->execute([$motoristaId]);
        jsonOk($stmt->fetchAll());
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body      = json_decode(file_get_contents('php://input'), true);
        $escolaIds = $body['escola_ids'] ?? [];

        if (!is_array($escolaIds)) jsonErr('escola_ids deve ser um array.', 400);

        $pdo->beginTransaction();

        $pdo->prepare("DELETE FROM escolas_atendidas WHERE motorista_id = ?")->execute([$motoristaId]);

        $ins = $pdo->prepare("INSERT INTO escolas_atendidas (motorista_id, escola_id) VALUES (?, ?)");
        foreach ($escolaIds as $eid) {
            $ins->execute([$motoristaId, (int)$eid]);
        }

        $pdo->commit();
        jsonOk([], 'Escolas salvas com sucesso.');
    }

    jsonErr('Método não permitido.', 405);

} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack();
    jsonErr('Erro no banco de dados: ' . $e->getMessage(), 500);
}
