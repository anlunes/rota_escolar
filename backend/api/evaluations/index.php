<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$pdo  = Database::getInstance();

// Com motorista_id → responsável consultando motorista
// Sem motorista_id → motorista vendo as próprias avaliações
$motoristaIdParam = (int)($_GET['motorista_id'] ?? 0);

if ($motoristaIdParam > 0) {
    $motoristaId = $motoristaIdParam;
} else {
    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$auth['sub']]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);
    $motoristaId = (int)$motorista['motorista_id'];
}

try {
    $aggStmt = $pdo->prepare("
        SELECT COUNT(*) AS total, AVG(nota) AS media
        FROM avaliacoes
        WHERE motorista_id = ?
    ");
    $aggStmt->execute([$motoristaId]);
    $agg = $aggStmt->fetch();

    $listStmt = $pdo->prepare("
        SELECT nota, comentario, mes_referencia
        FROM avaliacoes
        WHERE motorista_id = ?
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $listStmt->execute([$motoristaId]);
    $avaliacoes = $listStmt->fetchAll();

    Response::success([
        'media'      => $agg['total'] > 0 ? round((float)$agg['media'], 2) : null,
        'total'      => (int)$agg['total'],
        'avaliacoes' => $avaliacoes,
    ]);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
