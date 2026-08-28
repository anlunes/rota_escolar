<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

AuthMiddleware::require();

$cidade = $_GET['cidade'] ?? '';

try {
    $pdo = Database::getInstance();
    $sql = "SELECT id, nome AS name, cidade, estado, cep, aprovado AS approved
            FROM escolas WHERE aprovado = 1";
    $params = [];

    if ($cidade) {
        $sql .= ' AND cidade = ?';
        $params[] = $cidade;
    }
    $sql .= ' ORDER BY nome';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
