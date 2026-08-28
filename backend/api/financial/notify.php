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

$body    = json_decode(file_get_contents('php://input'), true) ?? [];
$alunoId = (int)($body['aluno_id'] ?? 0);

if (!$alunoId) Response::error('aluno_id é obrigatório.');

try {
    $pdo = Database::getInstance();

    // Get student and responsible contact
    $stmt = $pdo->prepare("
        SELECT a.nome AS student_name, r.nome AS resp_name, r.whatsapp
        FROM alunos a
        JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
        JOIN motoristas m ON m.motorista_id = a.motorista_id
        WHERE a.aluno_id = ? AND m.uid = ?
    ");
    $stmt->execute([$alunoId, $uid]);
    $data = $stmt->fetch();

    if (!$data) Response::error('Aluno não encontrado.', 404);

    // Log notification (real push via FCM would go here)
    $pdo->prepare("
        INSERT INTO notificacoes (tipo, aluno_id, mensagem, created_at)
        VALUES ('cobranca', ?, ?, NOW())
    ")->execute([$alunoId, "Aviso de cobrança enviado para {$data['resp_name']}"]);

    Response::success([
        'whatsapp' => $data['whatsapp'],
        'message'  => "Olá {$data['resp_name']}! Mensalidade do(a) {$data['student_name']} está em aberto.",
    ], 'Notificação enviada.');
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
