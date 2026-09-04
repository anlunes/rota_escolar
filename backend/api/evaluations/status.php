<?php
/**
 * GET /api/evaluations/status.php
 * Retorna se o responsável precisa avaliar o motorista do filho neste mês.
 * Response: { needs_evaluation, motorista_id, mes }
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'] ?? $auth['user_id'] ?? null;
if (!$uid) Response::unauthorized();

try {
    $pdo = Database::getInstance();
    $mes = date('Y-m');

    // Busca responsavel_id
    $rStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
    $rStmt->execute([$uid]);
    $responsavel = $rStmt->fetch(PDO::FETCH_ASSOC);

    if (!$responsavel) {
        Response::success(['needs_evaluation' => false, 'motorista_id' => null, 'mes' => $mes]);
    }

    $responsavelId = (int) $responsavel['responsavel_id'];

    // Busca primeiro filho ativo com motorista vinculado
    $aStmt = $pdo->prepare("
        SELECT a.motorista_id FROM alunos a
        WHERE a.responsavel_id = ? AND a.ativo = 1 AND a.motorista_id IS NOT NULL
        LIMIT 1
    ");
    $aStmt->execute([$responsavelId]);
    $aluno = $aStmt->fetch(PDO::FETCH_ASSOC);

    if (!$aluno) {
        Response::success(['needs_evaluation' => false, 'motorista_id' => null, 'mes' => $mes]);
    }

    $motoristaId = (int) $aluno['motorista_id'];

    // Verifica se já avaliou este mês
    $evStmt = $pdo->prepare("
        SELECT avaliacao_id FROM avaliacoes
        WHERE responsavel_id = ? AND motorista_id = ? AND mes_referencia = ?
        LIMIT 1
    ");
    $evStmt->execute([$responsavelId, $motoristaId, $mes]);
    $jaAvaliou = (bool) $evStmt->fetch();

    Response::success([
        'needs_evaluation' => !$jaAvaliou,
        'motorista_id'     => $motoristaId,
        'mes'              => $mes,
    ]);

} catch (Exception $e) {
    Response::error('Erro interno: ' . $e->getMessage(), 500);
}
