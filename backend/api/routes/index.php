<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers PRIMEIRO
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'] ?? $auth['user_id'] ?? '';

$period = $_GET['period'] ?? '';
$date   = $_GET['date']   ?? date('Y-m-d');

try {
    $pdo = Database::getInstance();

    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);

    $sql = "
        SELECT
            rda.id, rda.aluno_id AS aluno_id,
            a.nome AS name,
            a.endereco AS address,
            e.nome AS school,
            rda.status_atual,
            rda.vai_hoje,
            rda.talk_requested,
            r.nome AS guardian_name,
            r.telefone AS guardian_whatsapp,
            0 AS payment_paid,
            rda.ordem
        FROM rota_dias rd
        JOIN rota_dia_alunos rda ON rda.rota_dia_id = rd.id
        JOIN alunos a ON a.aluno_id = rda.aluno_id
        LEFT JOIN escolas e ON e.escola_id = a.escola_id
        LEFT JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
        WHERE rd.motorista_id = ?
        AND rd.data_servico = ?
    ";
    $params = [$motorista['motorista_id'], $date];

    if ($period) {
        $sql .= " AND rd.ciclo_escolar = ?";
        $params[] = $period;
    }

    $sql .= " ORDER BY rda.ordem ASC, a.nome ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    // Cast int fields
    foreach ($rows as &$row) {
        $row['vai_hoje']       = (int)$row['vai_hoje'];
        $row['talk_requested'] = (int)$row['talk_requested'];
        $row['payment_paid']   = (int)$row['payment_paid'];
        $row['ordem']          = (int)$row['ordem'];
    }

    Response::success($rows);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
