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

AuthMiddleware::require();

$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$name   = trim($body['name']   ?? '');
$cidade = trim($body['cidade'] ?? '');
$estado = trim($body['estado'] ?? '');
$cep    = trim($body['cep']    ?? '');

if (!$name) Response::error('name é obrigatório.');

try {
    $pdo = Database::getInstance();
    $ins = $pdo->prepare(
        "INSERT INTO escolas (nome, cidade, estado, cep, aprovado, created_at) VALUES (?,?,?,?,0,NOW())"
    );
    $ins->execute([$name, $cidade, $estado, $cep]);
    Response::success(['id' => $pdo->lastInsertId(), 'name' => $name], 'Escola criada pendente de aprovação.', 201);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
