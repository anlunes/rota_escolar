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

$motoristaId = (int)($_GET['motorista_id'] ?? 0);
if (!$motoristaId) Response::error('motorista_id é obrigatório.');

try {
    $pdo = Database::getInstance();
    $stmt = $pdo->prepare("
        SELECT av.id, av.nota, av.comentario, av.mes_referencia,
               r.nome AS responsavel_name, av.created_at
        FROM avaliacoes av
        LEFT JOIN responsaveis r ON r.responsavel_id = av.responsavel_id
        WHERE av.motorista_id = ?
        ORDER BY av.created_at DESC
        LIMIT 50
    ");
    $stmt->execute([$motoristaId]);
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
