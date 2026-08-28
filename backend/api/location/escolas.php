<?php
/**
 * GET /api/location/escolas.php?bairro_id=X
 * Retorna escolas aprovadas de um bairro
 */

ob_start();
ini_set('display_errors', 0);

require_once __DIR__ . '/../../config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

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
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonErr('Método não permitido.', 405);

$bairroId = (int)($_GET['bairro_id'] ?? 0);
if (!$bairroId) jsonErr('bairro_id é obrigatório.', 400);

try {
    $pdo = Database::getInstance();
    $stmt = $pdo->prepare(
        "SELECT escola_id AS id, nome, bairro_id, bairro_nome
         FROM escolas
         WHERE bairro_id = ? AND status = 'ativo'
         ORDER BY nome"
    );
    $stmt->execute([$bairroId]);
    jsonOk($stmt->fetchAll());
} catch (Throwable $e) {
    jsonErr('Erro ao buscar escolas: ' . $e->getMessage(), 500);
}
