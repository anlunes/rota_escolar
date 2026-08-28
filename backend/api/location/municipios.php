<?php
/**
 * GET /api/location/municipios.php?estado_id=X
 * Retorna municípios de um estado
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed();
}

$estadoId = (int)($_GET['estado_id'] ?? 0);
if (!$estadoId) Response::error('estado_id é obrigatório.', 400);

try {
    $pdo = Database::getInstance();
    $stmt = $pdo->prepare("SELECT id, nome, ibge FROM municipios WHERE estado_id = ? ORDER BY nome");
    $stmt->execute([$estadoId]);
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro ao buscar municípios.', 500);
}
