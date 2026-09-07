<?php
/**
 * GET /api/financial/index.php?mes=9&ano=2026
 *
 * Lista mensalidades do motorista logado para o mês/ano informado.
 * Padrão: mês e ano atuais.
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

if ($mes < 1 || $mes > 12 || $ano < 2024) Response::error('Mês ou ano inválido.', 400);

try {
    $pdo = Database::getInstance();

    $mStmt = $pdo->prepare("SELECT motorista_id, valor_servico FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);

    $motoristaId  = (int)$motorista['motorista_id'];
    $valorServico = (float)($motorista['valor_servico'] ?? 0);

    // Mensalidades do mês
    $stmt = $pdo->prepare("
        SELECT
            m.id,
            m.aluno_id,
            a.nome                              AS aluno_nome,
            r.nome                              AS responsavel_nome,
            COALESCE(r.whatsapp, r.telefone,'') AS responsavel_whatsapp,
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
        WHERE m.motorista_id = ? AND m.mes = ? AND m.ano = ?
        ORDER BY a.nome
    ");
    $stmt->execute([$motoristaId, $mes, $ano]);
    $mensalidades = $stmt->fetchAll();

    // Quantos alunos ativos ainda não têm cobrança neste mês
    $semCobranca = $pdo->prepare("
        SELECT COUNT(*) FROM alunos
        WHERE motorista_id = ? AND ativo = 1
          AND aluno_id NOT IN (
              SELECT aluno_id FROM mensalidades
              WHERE motorista_id = ? AND mes = ? AND ano = ?
          )
    ");
    $semCobranca->execute([$motoristaId, $motoristaId, $mes, $ano]);
    $pendentesGeracao = (int)$semCobranca->fetchColumn();

    Response::success([
        'mes'               => $mes,
        'ano'               => $ano,
        'valor_servico'     => $valorServico,
        'pendentes_geracao' => $pendentesGeracao,
        'mensalidades'      => array_map(fn($m) => [
            'id'                   => (int)$m['id'],
            'aluno_id'             => (int)$m['aluno_id'],
            'aluno_nome'           => $m['aluno_nome'],
            'responsavel_nome'     => $m['responsavel_nome'],
            'responsavel_whatsapp' => $m['responsavel_whatsapp'],
            'mes'                  => (int)$m['mes'],
            'ano'                  => (int)$m['ano'],
            'valor'                => (float)$m['valor'],
            'status'               => $m['status'],
            'forma_pagamento'      => $m['forma_pagamento'],
            'data_vencimento'      => $m['data_vencimento'],
            'data_pagamento'       => $m['data_pagamento'],
            'asaas_link'           => $m['asaas_payment_link'],
        ], $mensalidades),
    ]);

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
