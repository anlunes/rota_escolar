<?php
// backend/api/students/talk_request.php
// Persiste talk_requested / talk_acknowledged no último rota_dia_alunos do aluno.
//
// Actions:
//   request  — responsável quer falar (talk_requested=1, talk_acknowledged=0)
//   cancel   — responsável cancela   (talk_requested=0)
//   ack      — motorista confirma    (talk_acknowledged=1)

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método não permitido.']);
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

$auth   = AuthMiddleware::require();
$uid    = $auth['sub'] ?? $auth['user_id'] ?? '';

$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$id     = (int)($body['id']     ?? 0);
$action = $body['action'] ?? '';

if (!$id)     Response::error('id é obrigatório.');
if (!$action) Response::error('action é obrigatória.');

try {
    $pdo = Database::getInstance();

    if ($action === 'ack') {
        // Motorista confirma — verifica que o aluno é da rota dele
        $chk = $pdo->prepare("
            SELECT a.aluno_id FROM alunos a
            JOIN motoristas m ON m.motorista_id = a.motorista_id
            WHERE a.aluno_id = ? AND m.uid = ?
        ");
        $chk->execute([$id, $uid]);
        if (!$chk->fetch()) Response::error('Aluno não encontrado ou sem permissão.', 403);

        $pdo->prepare("
            UPDATE rota_dia_alunos
            SET talk_acknowledged = 1
            WHERE id = (
                SELECT id FROM (
                    SELECT id FROM rota_dia_alunos WHERE aluno_id = ? ORDER BY id DESC LIMIT 1
                ) AS sub
            )
        ")->execute([$id]);

    } elseif ($action === 'request' || $action === 'cancel') {
        // Responsável solicita ou cancela — verifica posse do aluno
        $chk = $pdo->prepare("
            SELECT a.aluno_id FROM alunos a
            JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
            WHERE a.aluno_id = ? AND r.uid = ?
        ");
        $chk->execute([$id, $uid]);
        if (!$chk->fetch()) Response::error('Aluno não encontrado ou sem permissão.', 403);

        $requested = $action === 'request' ? 1 : 0;
        $pdo->prepare("
            UPDATE rota_dia_alunos
            SET talk_requested    = ?,
                talk_acknowledged = 0
            WHERE id = (
                SELECT id FROM (
                    SELECT id FROM rota_dia_alunos WHERE aluno_id = ? ORDER BY id DESC LIMIT 1
                ) AS sub
            )
        ")->execute([$requested, $id]);

    } else {
        Response::error('action inválida.');
    }

    Response::success(null, 'talk_request atualizado.');
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
