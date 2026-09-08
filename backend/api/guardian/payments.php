<?php
/**
 * GET /api/guardian/payments.php?mes=9&ano=2026
 *
 * Retorna as mensalidades do mês para os filhos do responsável logado.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET')    Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$mes = isset($_GET['mes']) ? (int)$_GET['mes'] : (int)date('n');
$ano = isset($_GET['ano']) ? (int)$_GET['ano'] : (int)date('Y');

try {
    $pdo = Database::getInstance();

    $stmt = $pdo->prepare("
        SELECT
            m.id,
            a.nome              AS aluno_nome,
            m.mes,
            m.ano,
            m.valor,
            m.status,
            m.forma_pagamento,
            m.data_vencimento,
            m.data_pagamento,
            m.asaas_payment_link
        FROM mensalidades m
        JOIN alunos a       ON a.aluno_id       = m.aluno_id
        JOIN responsaveis r ON r.responsavel_id = m.responsavel_id
        WHERE r.uid = ? AND m.mes = ? AND m.ano = ?
        ORDER BY a.nome
    ");
    $stmt->execute([$uid, $mes, $ano]);
    $rows = $stmt->fetchAll();

    Response::success([
        'mes'         => $mes,
        'ano'         => $ano,
        'mensalidades' => array_map(fn($m) => [
            'id'            => (int)$m['id'],
            'aluno_nome'    => $m['aluno_nome'],
            'mes'           => (int)$m['mes'],
            'ano'           => (int)$m['ano'],
            'valor'         => (float)$m['valor'],
            'status'        => $m['status'],
            'forma_pagamento' => $m['forma_pagamento'],
            'data_vencimento' => $m['data_vencimento'],
            'data_pagamento'  => $m['data_pagamento'],
            'link'          => $m['asaas_payment_link'],
        ], $rows),
    ]);

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
