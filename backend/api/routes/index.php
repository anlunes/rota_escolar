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

date_default_timezone_set('America/Sao_Paulo');

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

    // Busca alunos vinculados ao motorista, com status do dia se existir
    $stmt = $pdo->prepare("
        SELECT
            a.aluno_id AS id,
            a.nome AS name,
            COALESCE(
                NULLIF(a.endereco, ''),
                NULLIF(TRIM(CONCAT_WS(', ',
                    NULLIF(COALESCE(a.logradouro, ''), ''),
                    NULLIF(CONCAT('nº ', COALESCE(a.numero_residencia, '')), 'nº '),
                    NULLIF(COALESCE(a.bairro_residencia, ''), '')
                )), ''),
                NULLIF(a.bairro_residencia, ''),
                ''
            ) AS address,
            COALESCE(e.nome, 'Sem escola') AS school,
            COALESCE(rda.status_atual, 'waiting_van') AS status_atual,
            CAST(COALESCE(rda.vai_hoje, 1) AS SIGNED) AS vai_hoje,
            CAST(COALESCE(rda.talk_requested, 0) AS SIGNED) AS talk_requested,
            COALESCE(r.nome, '') AS guardian_name,
            COALESCE(r.whatsapp, r.telefone, '') AS guardian_whatsapp,
            0 AS payment_paid,
            COALESCE(rda.ordem, 999) AS ordem,
            COALESCE(a.turno, '') AS turno,
            COALESCE(a.foto_url, '') AS foto_url
        FROM alunos a
        LEFT JOIN escolas e ON e.escola_id = a.escola_id
        LEFT JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
        LEFT JOIN rota_dias rd ON rd.motorista_id = ? AND rd.data_servico = ?
        LEFT JOIN rota_dia_alunos rda ON rda.aluno_id = a.aluno_id AND rda.rota_dia_id = rd.id
        WHERE a.motorista_id = ? AND a.ativo = 1
        ORDER BY rda.ordem ASC, a.nome ASC
    ");
    $stmt->execute([$motorista['motorista_id'], $date, $motorista['motorista_id']]);
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
