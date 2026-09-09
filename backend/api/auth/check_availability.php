<?php
/**
 * GET /api/auth/check_availability.php?whatsapp=11999999999
 *
 * Verifica se um número de WhatsApp já está cadastrado em usuarios.
 * Retorna { "available": true } ou { "available": false }.
 * Não requer autenticação (chamado antes do cadastro).
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') { http_response_code(405); echo json_encode(['error' => 'Method not allowed']); exit; }

require_once __DIR__ . '/../../config/database.php';

$whatsapp = preg_replace('/\D/', '', trim($_GET['whatsapp'] ?? ''));

if (strlen($whatsapp) < 10) {
    http_response_code(400);
    echo json_encode(['error' => 'whatsapp inválido']);
    exit;
}

try {
    $pdo = Database::getInstance();
    $stmt = $pdo->prepare('SELECT 1 FROM usuarios WHERE telefone = ? LIMIT 1');
    $stmt->execute([$whatsapp]);
    $exists = $stmt->fetchColumn() !== false;
    echo json_encode(['available' => !$exists]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Erro no banco de dados']);
}
