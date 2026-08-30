<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'] ?? $auth['user_id'] ?? '';

$body     = json_decode(file_get_contents('php://input'), true) ?? [];
$alunoId  = isset($body['aluno_id']) ? (int)$body['aluno_id'] : 0;
$status   = $body['status'] ?? '';

$validStatuses = ['waiting_van', 'to_school', 'at_school', 'to_home', 'at_home'];

if ($alunoId <= 0) Response::error('aluno_id obrigatório.', 422);
if (!in_array($status, $validStatuses, true)) Response::error('Status inválido.', 422);

try {
    $pdo = Database::getInstance();

    // 1. Localiza motorista
    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);
    $motoristaId = $motorista['motorista_id'];

    // 2. Verifica se o aluno pertence a este motorista
    $aStmt = $pdo->prepare("SELECT aluno_id FROM alunos WHERE aluno_id = ? AND motorista_id = ? AND ativo = 1 LIMIT 1");
    $aStmt->execute([$alunoId, $motoristaId]);
    if (!$aStmt->fetch()) Response::error('Aluno não encontrado na rota.', 404);

    $today = date('Y-m-d');

    // 3. Encontra ou cria rota_dias para hoje (usa periodo fixo 'manha_ida' como âncora de status diário)
    $rdStmt = $pdo->prepare("
        INSERT INTO rota_dias (motorista_id, data_servico, periodo, status)
        VALUES (?, ?, 'manha_ida', 'em_andamento')
        ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)
    ");
    $rdStmt->execute([$motoristaId, $today]);
    $rotaDiaId = $pdo->lastInsertId();

    if (!$rotaDiaId) {
        $findStmt = $pdo->prepare("SELECT id FROM rota_dias WHERE motorista_id = ? AND data_servico = ? AND periodo = 'manha_ida' LIMIT 1");
        $findStmt->execute([$motoristaId, $today]);
        $row = $findStmt->fetch();
        $rotaDiaId = $row ? $row['id'] : null;
    }

    if (!$rotaDiaId) Response::error('Não foi possível determinar a rota do dia.', 500);

    // 4. Campos de horário mapeados por status (PHP 7.4 compatível)
    if ($status === 'to_school') {
        $horarioField = 'horario_embarque';
    } elseif ($status === 'at_school') {
        $horarioField = 'horario_escola';
    } elseif ($status === 'to_home') {
        $horarioField = 'horario_volta';
    } elseif ($status === 'at_home') {
        $horarioField = 'horario_casa';
    } else {
        $horarioField = null;
    }

    // 5. Upsert em rota_dia_alunos
    if ($horarioField) {
        $upsertStmt = $pdo->prepare("
            INSERT INTO rota_dia_alunos (rota_dia_id, aluno_id, status_atual, $horarioField)
            VALUES (?, ?, ?, CURRENT_TIME())
            ON DUPLICATE KEY UPDATE status_atual = ?, $horarioField = CURRENT_TIME()
        ");
        $upsertStmt->execute([$rotaDiaId, $alunoId, $status, $status]);
    } else {
        $upsertStmt = $pdo->prepare("
            INSERT INTO rota_dia_alunos (rota_dia_id, aluno_id, status_atual)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE status_atual = ?
        ");
        $upsertStmt->execute([$rotaDiaId, $alunoId, $status, $status]);
    }

    Response::success(['aluno_id' => $alunoId, 'status' => $status]);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados: ' . $e->getMessage(), 500);
}
