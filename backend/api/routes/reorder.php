<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'PUT') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$body       = json_decode(file_get_contents('php://input'), true) ?? [];
$orderedIds = $body['ordered_ids'] ?? [];
$period     = trim($body['period'] ?? '');
$date       = trim($body['date']   ?? date('Y-m-d'));

if (empty($orderedIds)) Response::error('ordered_ids é obrigatório.');

try {
    $pdo = Database::getInstance();

    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);

    $pdo->beginTransaction();
    foreach ($orderedIds as $ordem => $alunoId) {
        $pdo->prepare("
            UPDATE rota_dia_alunos rda
            JOIN rota_dias rd ON rd.id = rda.rota_dia_id
            SET rda.ordem = ?
            WHERE rda.aluno_id = ?
            AND rd.motorista_id = ?
            AND rd.data_servico = ?
        ")->execute([$ordem + 1, $alunoId, $motorista['motorista_id'], $date]);
    }
    $pdo->commit();

    Response::success(null, 'Ordem atualizada.');
} catch (PDOException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    Response::error('Erro no banco de dados.', 500);
}
