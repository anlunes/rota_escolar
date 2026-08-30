<?php
/**
 * POST /api/location/escolas_create.php
 * Cria uma nova escola com status pendente (aguarda aprovação do admin).
 * Body JSON: { "nome": "E.E. João Silva", "bairro_nome": "Centro",
 *              "cep": "...", "endereco": "...", "cidade": "...", "estado": "..." }
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

$body = json_decode(file_get_contents('php://input'), true);

$nome      = trim($body['nome']       ?? '');
$bairro    = trim($body['bairro_nome'] ?? $body['bairro'] ?? '') ?: null;
$cep       = trim($body['cep']        ?? '') ?: null;
$logradouro = trim($body['endereco']  ?? $body['logradouro'] ?? '') ?: null;
$municipio = trim($body['cidade']     ?? $body['municipio'] ?? '') ?: null;
$estado    = trim($body['estado']     ?? '') ?: null;

if (!$nome) jsonErr('nome é obrigatório.', 400);

try {
    $pdo = Database::getInstance();

    // Verifica duplicata pelo nome (case-insensitive)
    $check = $pdo->prepare(
        "SELECT escola_id, status FROM escolas WHERE LOWER(nome) = LOWER(?) LIMIT 1"
    );
    $check->execute([$nome]);
    $existing = $check->fetch();

    if ($existing) {
        jsonOk(
            ['id' => (int)$existing['escola_id'], 'status' => $existing['status']],
            $existing['status'] === 'ativo'
                ? 'Escola já existe e está ativa.'
                : 'Escola já enviada e aguarda aprovação.'
        );
    }

    $stmt = $pdo->prepare(
        "INSERT INTO escolas (nome, bairro, logradouro, municipio, estado, cep, aprovado, status)
         VALUES (?, ?, ?, ?, ?, ?, 0, 'pendente')"
    );
    $stmt->execute([$nome, $bairro, $logradouro, $municipio, $estado, $cep]);

    jsonOk(
        ['id' => (int)$pdo->lastInsertId(), 'status' => 'pendente'],
        'Escola enviada para aprovação.'
    );

} catch (Throwable $e) {
    jsonErr('Erro ao cadastrar escola: ' . $e->getMessage(), 500);
}
