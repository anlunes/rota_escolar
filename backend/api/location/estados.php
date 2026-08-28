<?php
/**
 * GET /api/location/estados.php
 * Retorna lista de estados brasileiros
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed();
}

try {
    $pdo = Database::getInstance();
    $stmt = $pdo->query("SELECT id, uf, nome FROM estados ORDER BY nome");
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro ao buscar estados.', 500);
}
