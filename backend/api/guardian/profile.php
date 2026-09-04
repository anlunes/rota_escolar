<?php
/**
 * GET  /api/guardian/profile.php  → retorna perfil do responsável (telefone, bairro)
 * POST /api/guardian/profile.php  → salva telefone e bairro_id
 * Body JSON: { "telefone": "21999999999", "bairro_id": 42 }
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

$payload = AuthMiddleware::require();
$uid = $payload['sub'] ?? $payload['user_id'] ?? null;

if (!$uid) Response::unauthorized();

try {
    $pdo = Database::getInstance();

    // ------------------------------------------------------------------
    // GET — retorna perfil atual
    // ------------------------------------------------------------------
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $pdo->prepare("
            SELECT u.telefone, u.bairro_id,
                   b.nome AS bairro_nome,
                   b.municipio_id
            FROM usuarios u
            LEFT JOIN bairros b ON b.id = u.bairro_id
            WHERE u.uid = ?
            LIMIT 1
        ");
        $stmt->execute([$uid]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$row) Response::notFound('Usuário não encontrado.');

        $hasPhone  = !empty(trim($row['telefone'] ?? ''));
        $hasBairro = !empty($row['bairro_id']);

        // Conta filhos ativos do responsável (via tabela responsaveis)
        $rStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
        $rStmt->execute([$uid]);
        $responsavel = $rStmt->fetch(PDO::FETCH_ASSOC);
        $hasFilho = false;
        if ($responsavel) {
            $fStmt = $pdo->prepare("SELECT COUNT(*) FROM alunos WHERE responsavel_id = ? AND ativo = 1");
            $fStmt->execute([$responsavel['responsavel_id']]);
            $hasFilho = ((int) $fStmt->fetchColumn()) > 0;
        }

        Response::success([
            'telefone'          => $row['telefone'] ?? '',
            'bairro_id'         => $row['bairro_id'] ? (int) $row['bairro_id'] : null,
            'bairro_nome'       => $row['bairro_nome'] ?? '',
            'municipio_id'      => $row['municipio_id'] ? (int) $row['municipio_id'] : null,
            'has_phone'         => $hasPhone,
            'has_bairro'        => $hasBairro,
            'has_filho'         => $hasFilho,
            'onboarding_complete' => $hasPhone && $hasBairro,
        ]);
    }

    // ------------------------------------------------------------------
    // POST — salva telefone e bairro_id
    // ------------------------------------------------------------------
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body     = json_decode(file_get_contents('php://input'), true) ?? [];
        $telefone = trim($body['telefone'] ?? '');
        $bairroId = isset($body['bairro_id']) ? (int) $body['bairro_id'] : null;

        if (empty($telefone)) Response::error('Telefone é obrigatório.');
        if (!$bairroId)       Response::error('Bairro é obrigatório.');

        // Valida que o bairro existe e está ativo
        $bStmt = $pdo->prepare("SELECT id FROM bairros WHERE id = ? AND status = 'ativo' LIMIT 1");
        $bStmt->execute([$bairroId]);
        if (!$bStmt->fetch()) Response::error('Bairro inválido ou ainda não aprovado.');

        $upd = $pdo->prepare("
            UPDATE usuarios
               SET telefone   = ?,
                   bairro_id  = ?,
                   updated_at = NOW()
             WHERE uid = ?
        ");
        $upd->execute([$telefone, $bairroId, $uid]);

        Response::success(['saved' => true], 'Perfil atualizado com sucesso.');
    }

    Response::methodNotAllowed();

} catch (Exception $e) {
    Response::error('Erro interno: ' . $e->getMessage(), 500);
}
