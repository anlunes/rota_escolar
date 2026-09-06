<?php
/**
 * POST /api/admin/confirm_residencia.php
 *
 * Chamado pelo painel admin para confirmar as coordenadas da residência de um aluno.
 * Salva lat/lon na tabela alunos — o próximo quote.php vai calcular e entregar o resultado.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')    Response::methodNotAllowed();

// Autenticação simples por sessão admin
session_start();
require_once __DIR__ . '/../../admin/config.php';
if (empty($_SESSION[ADMIN_SESSION_KEY])) {
    Response::unauthorized('Acesso restrito ao admin.');
}

$body    = json_decode(file_get_contents('php://input'), true) ?? [];
$id      = (int)($body['solicitacao_id'] ?? 0);
$lat     = isset($body['lat']) && is_numeric($body['lat']) ? (float)$body['lat'] : null;
$lon     = isset($body['lon']) && is_numeric($body['lon']) ? (float)$body['lon'] : null;

if (!$id || $lat === null || $lon === null) {
    Response::error('solicitacao_id, lat e lon são obrigatórios.');
}
if ($lat < -90 || $lat > 90 || $lon < -180 || $lon > 180) {
    Response::error('Coordenadas fora do intervalo válido.');
}

try {
    $pdo = Database::getInstance();

    // Busca aluno_id pela solicitação
    $stmt = $pdo->prepare("SELECT aluno_id FROM solicitacoes_orcamento WHERE id = ? AND status = 'pendente' LIMIT 1");
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    if (!$row) Response::error('Solicitação não encontrada ou já processada.', 404);

    $alunoId = (int)$row['aluno_id'];

    // Salva coords na tabela alunos
    $pdo->prepare("UPDATE alunos SET lat_residencia = ?, lon_residencia = ?, updated_at = NOW() WHERE aluno_id = ?")
        ->execute([$lat, $lon, $alunoId]);

    Response::success(
        ['aluno_id' => $alunoId, 'lat' => $lat, 'lon' => $lon],
        'Coordenadas salvas. O orçamento será calculado na próxima consulta do responsável.'
    );

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
