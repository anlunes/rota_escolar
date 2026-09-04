<?php
// backend/api/students/go_today.php
// Persiste vai_hoje no último registro de rota_dia_alunos do aluno.

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

$auth = AuthMiddleware::require();
$uid  = $auth['sub'] ?? $auth['user_id'] ?? '';

$body    = json_decode(file_get_contents('php://input'), true) ?? [];
$id      = (int)($body['id']       ?? 0);
$vaiHoje = isset($body['vai_hoje']) ? (int)$body['vai_hoje'] : 1;

if (!$id) Response::error('id é obrigatório.');

try {
    $pdo = Database::getInstance();

    // Verifica que o aluno pertence ao responsável logado
    $chk = $pdo->prepare("
        SELECT a.aluno_id FROM alunos a
        JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
        WHERE a.aluno_id = ? AND r.uid = ?
    ");
    $chk->execute([$id, $uid]);
    if (!$chk->fetch()) Response::error('Aluno não encontrado ou sem permissão.', 403);

    // Atualiza o último registro de rota_dia_alunos para este aluno
    $pdo->prepare("
        UPDATE rota_dia_alunos
        SET vai_hoje = ?
        WHERE id = (
            SELECT id FROM (
                SELECT id FROM rota_dia_alunos
                WHERE aluno_id = ?
                ORDER BY id DESC
                LIMIT 1
            ) AS sub
        )
    ")->execute([$vaiHoje, $id]);

    Response::success(null, 'vai_hoje atualizado.');
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
