<?php
/**
 * POST /api/financial/generate.php
 *
 * Gera cobranças Asaas para todos os alunos ativos do motorista no mês informado.
 * Body: { mes: int, ano: int }
 *
 * Fluxo por aluno:
 *   1. Se mensalidade já existe com status pago/cancelado → pula
 *   2. Cria/recupera cliente Asaas do responsável
 *   3. Cria cobrança UNDEFINED (responsável escolhe PIX/boleto/cartão)
 *   4. Insere ou atualiza mensalidade com asaas_payment_id e link
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/asaas_helper.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')   Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$body = json_decode(file_get_contents('php://input'), true) ?? [];
$mes  = (int)($body['mes']  ?? date('n'));
$ano  = (int)($body['ano']  ?? date('Y'));

if ($mes < 1 || $mes > 12 || $ano < 2024) Response::error('Mês ou ano inválido.', 400);

try {
    $pdo = Database::getInstance();

    // Motorista logado
    $mStmt = $pdo->prepare("SELECT motorista_id, nome, valor_servico FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);

    $motoristaId  = (int)$motorista['motorista_id'];
    $valorServico = (float)($motorista['valor_servico'] ?? 0);

    if ($valorServico <= 0) {
        Response::error('Configure o valor mensal por aluno no seu perfil antes de gerar cobranças.', 422);
    }

    $vencimento = sprintf('%04d-%02d-25', $ano, $mes);
    $meses = ['','Janeiro','Fevereiro','Março','Abril','Maio','Junho',
              'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    $mesLabel = $meses[$mes] . '/' . $ano;

    // Alunos ativos com dados do responsável
    $aStmt = $pdo->prepare("
        SELECT
            a.aluno_id, a.nome AS aluno_nome, a.responsavel_id,
            r.nome              AS responsavel_nome,
            r.email             AS responsavel_email,
            COALESCE(r.whatsapp, r.telefone, '') AS responsavel_fone,
            r.asaas_customer_id
        FROM alunos a
        JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
        WHERE a.motorista_id = ? AND a.ativo = 1
    ");
    $aStmt->execute([$motoristaId]);
    $alunos = $aStmt->fetchAll();

    if (empty($alunos)) Response::error('Nenhum aluno ativo encontrado.', 422);

    $resultados = [];

    foreach ($alunos as $aluno) {
        $alunoId = (int)$aluno['aluno_id'];

        // Verifica se já existe mensalidade
        $exStmt = $pdo->prepare("SELECT id, status FROM mensalidades WHERE aluno_id = ? AND mes = ? AND ano = ? LIMIT 1");
        $exStmt->execute([$alunoId, $mes, $ano]);
        $men = $exStmt->fetch();

        if ($men && in_array($men['status'], ['pago', 'cancelado'])) {
            $resultados[] = [
                'aluno_id'   => $alunoId,
                'aluno_nome' => $aluno['aluno_nome'],
                'resultado'  => 'ja_processado',
                'status'     => $men['status'],
            ];
            continue;
        }

        try {
            // 1. Cria/recupera cliente Asaas
            $customerId = asaas_get_or_create_customer(
                $pdo,
                (int)$aluno['responsavel_id'],
                $aluno['responsavel_nome'],
                $aluno['responsavel_email'],
                $aluno['responsavel_fone']
            );

            // 2. Cria cobrança
            $payment = asaas_create_payment(
                $customerId,
                $valorServico,
                $vencimento,
                "Transporte escolar – {$aluno['aluno_nome']} – $mesLabel"
            );

            // 3. Insere ou atualiza mensalidade
            if ($men) {
                $pdo->prepare("
                    UPDATE mensalidades
                    SET valor = ?, data_vencimento = ?,
                        asaas_customer_id = ?, asaas_payment_id = ?, asaas_payment_link = ?,
                        status = 'pendente', updated_at = NOW()
                    WHERE id = ?
                ")->execute([$valorServico, $vencimento, $customerId, $payment['id'], $payment['invoiceUrl'], $men['id']]);
                $mensalidadeId = $men['id'];
            } else {
                $ins = $pdo->prepare("
                    INSERT INTO mensalidades
                        (aluno_id, motorista_id, responsavel_id, mes, ano, valor, status,
                         data_vencimento, asaas_customer_id, asaas_payment_id, asaas_payment_link)
                    VALUES (?, ?, ?, ?, ?, ?, 'pendente', ?, ?, ?, ?)
                ");
                $ins->execute([
                    $alunoId, $motoristaId, (int)$aluno['responsavel_id'],
                    $mes, $ano, $valorServico, $vencimento,
                    $customerId, $payment['id'], $payment['invoiceUrl'],
                ]);
                $mensalidadeId = (int)$pdo->lastInsertId();
            }

            $resultados[] = [
                'aluno_id'      => $alunoId,
                'aluno_nome'    => $aluno['aluno_nome'],
                'mensalidade_id'=> $mensalidadeId,
                'resultado'     => 'gerado',
                'link'          => $payment['invoiceUrl'],
            ];

        } catch (Throwable $e) {
            $resultados[] = [
                'aluno_id'   => $alunoId,
                'aluno_nome' => $aluno['aluno_nome'],
                'resultado'  => 'erro',
                'erro'       => $e->getMessage(),
            ];
        }
    }

    $gerados = count(array_filter($resultados, fn($r) => $r['resultado'] === 'gerado'));
    Response::success($resultados, "Cobranças processadas: $gerados gerada(s).");

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
