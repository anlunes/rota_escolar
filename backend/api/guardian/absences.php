<?php
/**
 * GET    /api/guardian/absences.php?aluno_id=X  → lista ausências futuras do aluno
 * POST   /api/guardian/absences.php             → agenda ausência { aluno_id, data: "YYYY-MM-DD" }
 * DELETE /api/guardian/absences.php             → cancela ausência { aluno_id, data: "YYYY-MM-DD" }
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$payload = AuthMiddleware::require();
$uid     = $payload['sub'] ?? $payload['user_id'] ?? null;

try {
    $pdo = Database::getInstance();

    // Busca responsavel_id pelo uid
    $rStmt = $pdo->prepare("SELECT responsavel_id AS id FROM responsaveis WHERE uid = ? LIMIT 1");
    $rStmt->execute([$uid]);
    $resp = $rStmt->fetch();
    if (!$resp) Response::error('Responsável não encontrado.', 404);
    $responsavelId = (int)$resp['id'];

    // ── GET ──────────────────────────────────────────────────────────────────
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $alunoId = isset($_GET['aluno_id']) ? (int)$_GET['aluno_id'] : 0;
        if ($alunoId <= 0) Response::error('aluno_id obrigatório.', 400);

        // Garante que o aluno pertence a este responsável
        $chk = $pdo->prepare("SELECT aluno_id FROM alunos WHERE aluno_id = ? AND responsavel_id = ? LIMIT 1");
        $chk->execute([$alunoId, $responsavelId]);
        if (!$chk->fetch()) Response::error('Aluno não encontrado.', 404);

        $stmt = $pdo->prepare("
            SELECT data
            FROM ausencias_agendadas
            WHERE aluno_id = ? AND data >= CURDATE()
            ORDER BY data ASC
        ");
        $stmt->execute([$alunoId]);
        $datas = $stmt->fetchAll(PDO::FETCH_COLUMN);

        Response::success($datas);
    }

    // ── POST ─────────────────────────────────────────────────────────────────
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body    = json_decode(file_get_contents('php://input'), true);
        $alunoId = isset($body['aluno_id']) ? (int)$body['aluno_id'] : 0;
        $data    = trim($body['data'] ?? '');

        if ($alunoId <= 0 || !$data) Response::error('aluno_id e data obrigatórios.', 400);
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $data)) Response::error('Formato de data inválido (YYYY-MM-DD).', 400);
        if ($data < date('Y-m-d')) Response::error('Não é possível agendar ausência para datas passadas.', 400);

        // Garante que o aluno pertence a este responsável
        $chk = $pdo->prepare("SELECT aluno_id FROM alunos WHERE aluno_id = ? AND responsavel_id = ? LIMIT 1");
        $chk->execute([$alunoId, $responsavelId]);
        if (!$chk->fetch()) Response::error('Aluno não encontrado.', 404);

        $stmt = $pdo->prepare("
            INSERT IGNORE INTO ausencias_agendadas (aluno_id, responsavel_id, data)
            VALUES (?, ?, ?)
        ");
        $stmt->execute([$alunoId, $responsavelId, $data]);

        Response::success(null, 'Ausência agendada.');
    }

    // ── DELETE ────────────────────────────────────────────────────────────────
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        $body    = json_decode(file_get_contents('php://input'), true);
        $alunoId = isset($body['aluno_id']) ? (int)$body['aluno_id'] : 0;
        $data    = trim($body['data'] ?? '');

        if ($alunoId <= 0 || !$data) Response::error('aluno_id e data obrigatórios.', 400);

        $stmt = $pdo->prepare("
            DELETE FROM ausencias_agendadas
            WHERE aluno_id = ? AND responsavel_id = ? AND data = ?
        ");
        $stmt->execute([$alunoId, $responsavelId, $data]);

        Response::success(null, 'Ausência cancelada.');
    }

    Response::methodNotAllowed();

} catch (PDOException $e) {
    Response::error('Erro no banco: ' . $e->getMessage(), 500);
}
