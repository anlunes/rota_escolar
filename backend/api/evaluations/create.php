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

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$body       = json_decode(file_get_contents('php://input'), true) ?? [];
$motoristaId= (int)($body['motorista_id'] ?? 0);
$nota       = (int)($body['nota']          ?? 0);
$comentario = trim($body['comentario']     ?? '');
$mes        = trim($body['mes']            ?? date('Y-m'));

if (!$motoristaId || $nota < 1 || $nota > 5) {
    Response::error('motorista_id e nota (1-5) são obrigatórios.');
}

try {
    $pdo = Database::getInstance();

    $rStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
    $rStmt->execute([$uid]);
    $responsavel = $rStmt->fetch();
    if (!$responsavel) Response::error('Responsável não encontrado.', 404);

    // Prevent duplicate rating for same month
    $dup = $pdo->prepare("
        SELECT avaliacao_id FROM avaliacoes
        WHERE responsavel_id = ? AND motorista_id = ? AND mes_referencia = ?
    ");
    $dup->execute([$responsavel['responsavel_id'], $motoristaId, $mes]);
    if ($dup->fetch()) Response::error('Você já avaliou este motorista neste mês.');

    $pdo->prepare("
        INSERT INTO avaliacoes (responsavel_id, motorista_id, nota, comentario, mes_referencia, created_at)
        VALUES (?,?,?,?,?,NOW())
    ")->execute([$responsavel['responsavel_id'], $motoristaId, $nota, $comentario, $mes]);

    Response::success(['nota' => $nota], 'Avaliação registrada.', 201);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
