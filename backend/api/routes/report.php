<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
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

$days = isset($_GET['days']) ? max(1, min(90, (int)$_GET['days'])) : 14;

try {
    $pdo = Database::getInstance();

    // Busca responsavel_id pelo uid
    $rStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
    $rStmt->execute([$uid]);
    $responsavel = $rStmt->fetch();
    if (!$responsavel) Response::error('Responsável não encontrado.', 404);

    $responsavelId = $responsavel['responsavel_id'];

    // Busca histórico dos últimos N dias para todos os alunos do responsável
    $stmt = $pdo->prepare("
        SELECT
            a.aluno_id,
            a.nome AS nome,
            rd.data_servico,
            DATE_FORMAT(rda.horario_embarque, '%H:%i') AS horario_embarque,
            DATE_FORMAT(rda.horario_escola,   '%H:%i') AS horario_escola,
            DATE_FORMAT(rda.horario_volta,    '%H:%i') AS horario_volta,
            DATE_FORMAT(rda.horario_casa,     '%H:%i') AS horario_casa
        FROM alunos a
        INNER JOIN rota_dia_alunos rda ON rda.aluno_id = a.aluno_id
        INNER JOIN rota_dias rd        ON rd.id = rda.rota_dia_id
        WHERE a.responsavel_id = ?
          AND rd.data_servico >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
          AND rd.data_servico <= CURDATE()
        ORDER BY rd.data_servico DESC, a.nome ASC
    ");
    $stmt->execute([$responsavelId, $days]);
    $rows = $stmt->fetchAll();

    // Agrupa por data → alunos
    $byDate = [];
    foreach ($rows as $row) {
        $date = $row['data_servico'];
        if (!isset($byDate[$date])) {
            $byDate[$date] = ['date' => $date, 'students' => []];
        }
        $byDate[$date]['students'][] = [
            'aluno_id'         => (string)$row['aluno_id'],
            'nome'             => $row['nome'],
            'horario_embarque' => $row['horario_embarque'] ?? '--:--',
            'horario_escola'   => $row['horario_escola']   ?? '--:--',
            'horario_volta'    => $row['horario_volta']    ?? '--:--',
            'horario_casa'     => $row['horario_casa']     ?? '--:--',
        ];
    }

    Response::success(array_values($byDate));

} catch (Exception $e) {
    Response::error('Erro interno: ' . $e->getMessage(), 500);
}
