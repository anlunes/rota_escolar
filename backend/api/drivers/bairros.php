<?php
/**
 * GET  /api/drivers/bairros.php  → lista bairros + preferência de localização do motorista
 * POST /api/drivers/bairros.php  → salva bairros + preferência de localização
 * Body JSON: { "bairro_ids": [1,2], "estado_id": 33, "municipio_id": 3304557 }
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

    $mStmt = $pdo->prepare("
        SELECT m.motorista_id, m.pref_estado_id, m.pref_municipio_id, m.van_code, m.whatsapp,
               m.vagas_van, m.preco_km, m.valor_servico,
               u.telefone
        FROM motoristas m
        LEFT JOIN usuarios u ON u.uid = m.uid
        WHERE m.uid = ? LIMIT 1
    ");
    $mStmt->execute([$uid]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);
    $motoristaId = $motorista['motorista_id'];

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $pdo->prepare("
            SELECT b.id, b.nome, b.municipio_id, b.municipio_nome
            FROM motorista_bairros mb
            JOIN bairros b ON b.id = mb.bairro_id
            WHERE mb.motorista_id = ?
            ORDER BY b.nome
        ");
        $stmt->execute([$motoristaId]);
        $bairros = $stmt->fetchAll();

        $turnosStmt = $pdo->prepare("
            SELECT
                COUNT(*) AS total,
                COUNT(CASE WHEN turno = 'manha' THEN 1 END) AS manha,
                COUNT(CASE WHEN turno = 'tarde' THEN 1 END) AS tarde
            FROM alunos WHERE motorista_id = ? AND ativo = 1
        ");
        $turnosStmt->execute([$motoristaId]);
        $turnos = $turnosStmt->fetch();

        $vagasVan    = (int)($motorista['vagas_van'] ?? 0);
        $alunosManha = (int)($turnos['manha'] ?? 0);
        $alunosTarde = (int)($turnos['tarde'] ?? 0);

        Response::success([
            'bairros'            => $bairros,
            'estado_id'          => $motorista['pref_estado_id'],
            'municipio_id'       => $motorista['pref_municipio_id'],
            'van_code'           => $motorista['van_code'],
            'whatsapp'           => $motorista['whatsapp'],
            'telefone_cadastro'  => $motorista['telefone'],
            'alunos_ativos'      => (int)($turnos['total'] ?? 0),
            'alunos_manha'       => $alunosManha,
            'alunos_tarde'       => $alunosTarde,
            'vagas_van'          => $vagasVan,
            'disponivel_manha'   => max(0, $vagasVan - $alunosManha),
            'disponivel_tarde'   => max(0, $vagasVan - $alunosTarde),
            'preco_km'           => $motorista['preco_km']      !== null ? (float)$motorista['preco_km']      : null,
            'valor_servico'      => $motorista['valor_servico'] !== null ? (float)$motorista['valor_servico'] : 0.0,
        ]);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body        = json_decode(file_get_contents('php://input'), true);
        $bairroIds   = $body['bairro_ids']   ?? [];
        $estadoId    = isset($body['estado_id'])    ? (int)$body['estado_id']    : null;
        $municipioId = isset($body['municipio_id']) ? (int)$body['municipio_id'] : null;
        $whatsapp      = isset($body['whatsapp'])      ? trim($body['whatsapp'])                  : null;
        $vagasVan      = isset($body['vagas_van'])    ? max(0, (int)$body['vagas_van'])          : null;
        $precoKm       = isset($body['preco_km'])     ? max(0, (float)$body['preco_km'])         : null;
        $valorServico  = isset($body['valor_servico']) ? max(0, (float)$body['valor_servico'])   : null;

        if (!is_array($bairroIds)) Response::error('bairro_ids deve ser um array.', 400);

        $pdo->beginTransaction();

        // Remove bairros antigos e insere novos
        $pdo->prepare("DELETE FROM motorista_bairros WHERE motorista_id = ?")->execute([$motoristaId]);
        $ins = $pdo->prepare("INSERT INTO motorista_bairros (motorista_id, bairro_id) VALUES (?, ?)");
        foreach ($bairroIds as $bid) {
            $ins->execute([$motoristaId, (int)$bid]);
        }

        // Salva preferência de localização, WhatsApp e capacidade da van
        $pdo->prepare("
            UPDATE motoristas SET
                pref_estado_id    = ?,
                pref_municipio_id = ?,
                whatsapp          = ?,
                vagas_van         = COALESCE(?, vagas_van),
                preco_km          = COALESCE(?, preco_km),
                valor_servico     = COALESCE(?, valor_servico)
            WHERE motorista_id    = ?
        ")->execute([$estadoId, $municipioId, $whatsapp, $vagasVan, $precoKm, $valorServico, $motoristaId]);

        $pdo->commit();

        // Gera van_code FORA da transação principal
        $vanCode = $motorista['van_code'];

        if (($vanCode === null || $vanCode === '') && $municipioId && $estadoId) {
            try {
                // Busca UF do estado
                $ufRow = $pdo->prepare("SELECT uf FROM estados WHERE id = ? LIMIT 1");
                $ufRow->execute([$estadoId]);
                $uf = $ufRow->fetchColumn() ?: 'BR';

                // Verifica se município já existe na tabela de controle
                $vmCheck = $pdo->prepare("SELECT id, seq, van_count FROM van_municipios WHERE municipio_id = ? LIMIT 1");
                $vmCheck->execute([$municipioId]);
                $vm = $vmCheck->fetch();

                if ($vm) {
                    // Município já existe: incrementa van_count
                    $novoCount = $vm['van_count'] + 1;
                    $pdo->prepare("UPDATE van_municipios SET van_count = ? WHERE id = ?")
                        ->execute([$novoCount, $vm['id']]);
                    $seq      = $vm['seq'];
                    $vanCount = $novoCount;
                } else {
                    // Município novo: pega próximo seq e insere
                    $maxSeq = $pdo->query("SELECT COALESCE(MAX(seq), 0) + 1 FROM van_municipios")->fetchColumn();
                    $pdo->prepare("INSERT INTO van_municipios (municipio_id, uf, seq, van_count) VALUES (?, ?, ?, 1)")
                        ->execute([$municipioId, $uf, $maxSeq]);
                    $seq      = $maxSeq;
                    $vanCount = 1;
                }

                $vanCode = $uf
                    . str_pad($seq,      3, '0', STR_PAD_LEFT)
                    . str_pad($vanCount, 3, '0', STR_PAD_LEFT);

                $pdo->prepare("UPDATE motoristas SET van_code = ? WHERE motorista_id = ?")
                    ->execute([$vanCode, $motoristaId]);

            } catch (PDOException $eVan) {
                error_log("[bairros/POST] Erro ao gerar van_code: " . $eVan->getMessage());
            }
        }

        Response::success(['van_code' => $vanCode], 'Perfil salvo com sucesso.');
    }

    Response::methodNotAllowed();

} catch (PDOException $e) {
    if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack();
    Response::error('Erro no banco de dados: ' . $e->getMessage(), 500);
}
