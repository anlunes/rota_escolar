<?php
/**
 * GET  /api/drivers/frota.php  → lista vans da frota do gestor
 * POST /api/drivers/frota.php  → adiciona van à frota do gestor
 *   Body: { "van_code": "001RJ0001" }  (opcional — identifica van existente)
 *         ou {}  (cria nova van para a frota)
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

try {
    $pdo = Database::getInstance();

    // Busca motorista e verifica role gestor
    $mStmt = $pdo->prepare("
        SELECT m.motorista_id, u.role
        FROM motoristas m
        JOIN usuarios u ON u.uid = m.uid
        WHERE m.uid = ? LIMIT 1
    ");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();

    if (!$motorista) Response::error('Motorista não encontrado.', 404);
    if ($motorista['role'] !== 'gestor') Response::error('Acesso restrito a gestores de frota.', 403);

    $gestorId = $motorista['motorista_id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $pdo->prepare("
            SELECT v.van_id, v.van_code, v.veiculo_placa, v.veiculo_modelo,
                   v.vagas_van, v.crlv_url, v.crlv_exercicio,
                   v.motorista_id AS motorista_atual_id,
                   u.nome AS motorista_atual_nome,
                   (SELECT COUNT(*) FROM van_pool vp WHERE vp.van_id = v.van_id) AS motoristas_pool
            FROM vans v
            LEFT JOIN motoristas m2 ON m2.motorista_id = v.motorista_id
            LEFT JOIN usuarios u    ON u.uid = m2.uid
            WHERE v.proprietario_id = ?
            ORDER BY v.van_id ASC
        ");
        $stmt->execute([$gestorId]);
        $vans = $stmt->fetchAll();

        Response::success(['vans' => $vans, 'total' => count($vans)]);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body   = json_decode(file_get_contents('php://input'), true) ?? [];
        $action = $body['action'] ?? 'add_van';

        if ($action === 'add_van') {
            // Cria nova van na frota do gestor
            $pdo->prepare("
                INSERT INTO vans (motorista_id, proprietario_id, vagas_van)
                VALUES (?, ?, 0)
            ")->execute([$gestorId, $gestorId]);

            $vanId = $pdo->lastInsertId();
            Response::success(['van_id' => $vanId], 'Van adicionada à frota.', 201);
        }

        if ($action === 'add_pool') {
            // Adiciona motorista contratado ao pool de uma van
            $vanId      = (int)($body['van_id']      ?? 0);
            $motoristaId = (int)($body['motorista_id'] ?? 0);
            if (!$vanId || !$motoristaId) Response::error('van_id e motorista_id são obrigatórios.', 400);

            // Verifica que a van pertence ao gestor
            $check = $pdo->prepare("SELECT van_id FROM vans WHERE van_id = ? AND proprietario_id = ? LIMIT 1");
            $check->execute([$vanId, $gestorId]);
            if (!$check->fetch()) Response::error('Van não pertence à sua frota.', 403);

            $pdo->prepare("
                INSERT IGNORE INTO van_pool (van_id, motorista_id, autorizado_por)
                VALUES (?, ?, ?)
            ")->execute([$vanId, $motoristaId, $gestorId]);

            Response::success([], 'Motorista adicionado ao pool.');
        }

        if ($action === 'remove_pool') {
            $vanId       = (int)($body['van_id']       ?? 0);
            $motoristaId = (int)($body['motorista_id'] ?? 0);
            $pdo->prepare("DELETE FROM van_pool WHERE van_id = ? AND motorista_id = ?")
                ->execute([$vanId, $motoristaId]);
            Response::success([], 'Motorista removido do pool.');
        }

        Response::error('Ação inválida.', 400);
    }

    Response::methodNotAllowed();

} catch (PDOException $e) {
    Response::error('Erro no banco de dados: ' . $e->getMessage(), 500);
}
