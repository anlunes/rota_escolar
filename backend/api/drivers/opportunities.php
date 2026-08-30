<?php
/**
 * GET  /api/drivers/opportunities.php
 *   → lista alunos com van_code do motorista e motorista_id IS NULL (candidaturas pendentes)
 *
 * POST /api/drivers/opportunities.php
 *   Body: { "action": "accept"|"decline", "aluno_id": N }
 *   accept  → UPDATE alunos SET motorista_id = ? (vincula o aluno)
 *   decline → sem alteração no banco (aluno continua disponível para outros)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

$payload = AuthMiddleware::require();
$uid = $payload['sub'] ?? $payload['user_id'] ?? null;

try {
    $pdo = Database::getInstance();

    $mStmt = $pdo->prepare("SELECT motorista_id, van_code FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);

    $motoristaId = $motorista['motorista_id'];
    $vanCode     = $motorista['van_code'];

    // ── GET ──────────────────────────────────────────────────────────────────
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        if (!$vanCode) {
            Response::success([], 'VanCode não definido, sem oportunidades.');
        }

        $stmt = $pdo->prepare("
            SELECT
                a.aluno_id,
                a.nome           AS student_name,
                COALESCE(e.nome, 'Sem escola') AS school,
                COALESCE(a.endereco, a.cep_residencia, '') AS address,
                COALESCE(a.ciclo_escolar, '') AS period,
                r.nome           AS guardian_name,
                COALESCE(r.whatsapp, r.telefone, '') AS guardian_whatsapp
            FROM alunos a
            JOIN  responsaveis r ON r.responsavel_id = a.responsavel_id
            LEFT JOIN escolas  e ON e.escola_id      = a.escola_id
            WHERE a.van_code = ? AND a.motorista_id IS NULL AND a.ativo = 1
            ORDER BY a.created_at DESC
        ");
        $stmt->execute([$vanCode]);
        $rows = $stmt->fetchAll();

        Response::success($rows);
    }

    // ── POST ─────────────────────────────────────────────────────────────────
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body    = json_decode(file_get_contents('php://input'), true) ?? [];
        $action  = trim($body['action']   ?? '');
        $alunoId = (int)($body['aluno_id'] ?? 0);

        if (!$alunoId)                              Response::error('aluno_id é obrigatório.', 400);
        if (!in_array($action, ['accept','decline'])) Response::error('action inválida.', 400);
        if (!$vanCode)                              Response::error('Motorista sem VanCode.', 400);

        // Garante que o aluno pertence a este van_code e ainda não tem motorista
        $chk = $pdo->prepare("
            SELECT aluno_id FROM alunos
            WHERE aluno_id = ? AND van_code = ? AND motorista_id IS NULL
            LIMIT 1
        ");
        $chk->execute([$alunoId, $vanCode]);
        if (!$chk->fetch()) Response::error('Aluno não encontrado ou já vinculado.', 404);

        if ($action === 'accept') {
            $pdo->prepare("UPDATE alunos SET motorista_id = ?, updated_at = NOW() WHERE aluno_id = ?")
                ->execute([$motoristaId, $alunoId]);
            Response::success(null, 'Aluno aceito com sucesso.');
        }

        // decline: apenas confirma (aluno continua disponível para outros motoristas)
        Response::success(null, 'Candidatura recusada.');
    }

    Response::methodNotAllowed();

} catch (PDOException $e) {
    Response::error('Erro no banco de dados: ' . $e->getMessage(), 500);
}
