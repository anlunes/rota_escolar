<?php
/**
 * POST /api/location/bairros_create.php
 * Cria um novo bairro com status pendente (aguarda aprovação do admin).
 * Body JSON: { "nome": "Centro", "municipio_id": 3550308, "municipio_nome": "Rio de Janeiro" }
 */

ob_start();
ini_set('display_errors', 0);

require_once __DIR__ . '/../../config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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
if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonErr('Método não permitido.', 405);

$body        = json_decode(file_get_contents('php://input'), true);
$nome          = trim($body['nome'] ?? '');
$municipioId   = (int)($body['municipio_id'] ?? 0);
$municipioNome = trim($body['municipio_nome'] ?? '');

if (!$nome || !$municipioId) jsonErr('nome e municipio_id são obrigatórios.', 400);

try {
    $pdo = Database::getInstance();

    $check = $pdo->prepare("SELECT id, status FROM bairros WHERE municipio_id = ? AND LOWER(nome) = LOWER(?)");
    $check->execute([$municipioId, $nome]);
    $existing = $check->fetch();

    if ($existing) {
        jsonOk(['id' => (int)$existing['id'], 'status' => $existing['status']],
               $existing['status'] === 'ativo' ? 'Bairro já existe e está ativo.' : 'Bairro já enviado e aguarda aprovação.');
    }

    $stmt = $pdo->prepare("INSERT INTO bairros (nome, municipio_id, municipio_nome, status) VALUES (?, ?, ?, 'pendente')");
    $stmt->execute([$nome, $municipioId, $municipioNome ?: null]);

    jsonOk(['id' => (int)$pdo->lastInsertId(), 'status' => 'pendente'], 'Bairro enviado para aprovação.');

} catch (Throwable $e) {
    jsonErr('Erro ao cadastrar bairro: ' . $e->getMessage(), 500);
}
