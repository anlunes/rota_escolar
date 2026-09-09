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
        SELECT m.motorista_id, m.pref_estado_id, m.pref_municipio_id, m.whatsapp,
               m.preco_km, m.valor_servico,
               m.cpf, m.cep, m.logradouro, m.numero, m.complemento,
               m.bairro_nome, m.cidade, m.estado_uf,
               v.van_id, v.van_code, v.vagas_van,
               u.telefone
        FROM motoristas m
        LEFT JOIN vans v ON v.motorista_id = m.motorista_id
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
            'cpf'                => $motorista['cpf']        ?? '',
            'cep'                => $motorista['cep']        ?? '',
            'logradouro'         => $motorista['logradouro'] ?? '',
            'numero'             => $motorista['numero']     ?? '',
            'complemento'        => $motorista['complemento'] ?? '',
            'bairro_nome'        => $motorista['bairro_nome'] ?? '',
            'cidade'             => $motorista['cidade']     ?? '',
            'estado_uf'          => $motorista['estado_uf']  ?? '',
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

        // Dados pessoais / endereço residencial
        $cpf        = isset($body['cpf'])        ? preg_replace('/\D/', '', trim($body['cpf']))        : null;
        $cep        = isset($body['cep'])        ? preg_replace('/\D/', '', trim($body['cep']))        : null;
        $logradouro = isset($body['logradouro']) ? trim($body['logradouro']) ?: null                   : null;
        $numero     = isset($body['numero'])     ? trim($body['numero'])     ?: null                   : null;
        $complemento = isset($body['complemento']) ? trim($body['complemento']) ?: null                : null;
        $bairroNome = isset($body['bairro_nome']) ? trim($body['bairro_nome']) ?: null                 : null;
        $cidade     = isset($body['cidade'])     ? trim($body['cidade'])     ?: null                   : null;
        $estadoUf   = isset($body['estado_uf'])  ? strtoupper(trim($body['estado_uf'])) ?: null        : null;

        if ($cpf !== null && strlen($cpf) !== 11) $cpf = null; // descarta CPF malformado

        if (!is_array($bairroIds)) Response::error('bairro_ids deve ser um array.', 400);

        $pdo->beginTransaction();

        // Remove bairros antigos e insere novos
        $pdo->prepare("DELETE FROM motorista_bairros WHERE motorista_id = ?")->execute([$motoristaId]);
        $ins = $pdo->prepare("INSERT INTO motorista_bairros (motorista_id, bairro_id) VALUES (?, ?)");
        foreach ($bairroIds as $bid) {
            $ins->execute([$motoristaId, (int)$bid]);
        }

        // Salva preferência de localização, WhatsApp e dados pessoais do motorista
        $pdo->prepare("
            UPDATE motoristas SET
                pref_estado_id    = ?,
                pref_municipio_id = ?,
                whatsapp          = ?,
                preco_km          = COALESCE(?, preco_km),
                valor_servico     = COALESCE(?, valor_servico),
                cpf               = COALESCE(?, cpf),
                cep               = COALESCE(?, cep),
                logradouro        = COALESCE(?, logradouro),
                numero            = COALESCE(?, numero),
                complemento       = COALESCE(?, complemento),
                bairro_nome       = COALESCE(?, bairro_nome),
                cidade            = COALESCE(?, cidade),
                estado_uf         = COALESCE(?, estado_uf)
            WHERE motorista_id    = ?
        ")->execute([
            $estadoId, $municipioId, $whatsapp,
            $precoKm, $valorServico,
            $cpf, $cep, $logradouro, $numero, $complemento,
            $bairroNome, $cidade, $estadoUf,
            $motoristaId,
        ]);

        // Salva vagas_van na tabela vans (cria a linha se ainda não existir)
        $pdo->prepare("
            INSERT INTO vans (motorista_id, vagas_van)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE
                vagas_van  = VALUES(vagas_van),
                updated_at = NOW()
        ")->execute([$motoristaId, $vagasVan ?? 0]);

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

                // Formato: UF(2) + MUN(3) + SEQ(4) = 9 caracteres
                // Ex: RJ0010001 = RJ, município 001, 1º motorista
                $vanCode = $uf
                    . str_pad($seq,      3, '0', STR_PAD_LEFT)
                    . str_pad($vanCount, 4, '0', STR_PAD_LEFT);

                $pdo->prepare("UPDATE vans SET van_code = ?, updated_at = NOW() WHERE motorista_id = ?")
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
