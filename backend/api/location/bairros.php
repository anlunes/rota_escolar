<?php
/**
 * GET /api/location/bairros.php?municipio_id=X
 * Retorna bairros de um município
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed();
}

$municipioId = (int)($_GET['municipio_id'] ?? 0);
if (!$municipioId) Response::error('municipio_id é obrigatório.', 400);

try {
    $pdo = Database::getInstance();
    $stmt = $pdo->prepare("SELECT id, nome FROM bairros WHERE municipio_id = ? AND status = 'ativo' ORDER BY nome");
    $stmt->execute([$municipioId]);
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro ao buscar bairros.', 500);
}
