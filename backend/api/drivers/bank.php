<?php
/**
 * POST /api/drivers/bank.php
 *
 * Salva dados bancários / PIX do motorista logado.
 * Body JSON: { chave_pix, banco_codigo, banco_agencia, banco_agencia_digito,
 *              banco_conta, banco_conta_digito, banco_tipo }
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

$chavePix           = trim($body['chave_pix']            ?? '');
$bancoCodigo        = trim($body['banco_codigo']          ?? '');
$bancoAgencia       = trim($body['banco_agencia']         ?? '');
$bancoAgenciaDigito = trim($body['banco_agencia_digito']  ?? '');
$bancoConta         = trim($body['banco_conta']           ?? '');
$bancoContaDigito   = trim($body['banco_conta_digito']    ?? '');
$bancoTipo          = in_array($body['banco_tipo'] ?? '', ['corrente', 'poupanca'], true)
                        ? $body['banco_tipo']
                        : null;

// Pelo menos PIX ou conta bancária completa deve ser informada
$temPix  = $chavePix !== '';
$temConta = $bancoCodigo && $bancoAgencia && $bancoConta;

if (!$temPix && !$temConta) {
    Response::error('Informe uma chave PIX ou os dados bancários completos (banco, agência e conta).');
}

try {
    $pdo = Database::getInstance();

    $pdo->prepare("
        UPDATE motoristas
        SET chave_pix            = ?,
            banco_codigo         = ?,
            banco_agencia        = ?,
            banco_agencia_digito = ?,
            banco_conta          = ?,
            banco_conta_digito   = ?,
            banco_tipo           = ?,
            updated_at           = NOW()
        WHERE uid = ?
    ")->execute([
        $chavePix ?: null,
        $bancoCodigo ?: null,
        $bancoAgencia ?: null,
        $bancoAgenciaDigito ?: null,
        $bancoConta ?: null,
        $bancoContaDigito ?: null,
        $bancoTipo,
        $uid,
    ]);

    // Tenta criar subconta Asaas se ainda não existe
    $mStmt = $pdo->prepare("SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1");
    $mStmt->execute([$uid]);
    $motoristaId = (int)($mStmt->fetchColumn() ?: 0);
    if ($motoristaId) {
        asaas_get_or_create_subaccount($pdo, $motoristaId);
    }

    Response::success(['saved' => true], 'Dados bancários salvos com sucesso.');

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
