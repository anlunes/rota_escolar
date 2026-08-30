<?php
// backend/api/students/index.php

// CORS headers PRIMEIRO (antes de qualquer autenticação)
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

$method = $_SERVER['REQUEST_METHOD'];
$auth_payload = AuthMiddleware::require();
$uid = $auth_payload['sub'] ?? $auth_payload['user_id'] ?? '';

try {
    $pdo = Database::getInstance();

    // ==========================================
    // GET — Listar alunos do responsável
    // ==========================================
    if ($method === 'GET') {
        error_log("Buscando responsável para UID: $uid");

        $respStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
        $respStmt->execute([$uid]);
        $responsavel = $respStmt->fetch(PDO::FETCH_ASSOC);

        if (!$responsavel) {
            error_log("Responsável não encontrado para UID: $uid");
            Response::error('Responsável não encontrado.', 404);
        }

        error_log("Responsável encontrado: " . $responsavel['responsavel_id']);

        $stmt = $pdo->prepare("
            SELECT
                a.aluno_id AS id,
                a.nome AS name,
                COALESCE(e.nome, 'Sem escola') AS school,
                a.escola_id,
                COALESCE(a.cep_residencia, '') AS residence_cep,
                COALESCE(a.logradouro, '') AS logradouro,
                COALESCE(a.numero_residencia, '') AS numero_residencia,
                COALESCE(a.complemento, '') AS complemento,
                COALESCE(a.bairro_residencia, '') AS bairro_residencia,
                COALESCE(a.ciclo_escolar, '') AS ciclo_escolar,
                COALESCE(a.turno, '') AS turno,
                COALESCE(a.data_nascimento, '') AS data_nascimento,
                COALESCE(a.van_code, '') AS van_code,
                COALESCE(rda.status_atual, 'waiting_van') AS status_atual,
                CAST(COALESCE(rda.vai_hoje, 1) AS SIGNED) AS vai_hoje,
                CAST(COALESCE(rda.talk_requested, 0) AS SIGNED) AS talk_requested,
                CAST(COALESCE(rda.talk_acknowledged, 0) AS SIGNED) AS talk_acknowledged,
                COALESCE(m.nome, '') AS driver_name,
                COALESCE(m.telefone, '') AS driver_whatsapp,
                CAST(COALESCE(a.ativo, 1) AS SIGNED) AS ativo
            FROM alunos a
            LEFT JOIN escolas e ON e.escola_id = a.escola_id
            LEFT JOIN motoristas m ON m.motorista_id = a.motorista_id
            LEFT JOIN rota_dia_alunos rda ON rda.aluno_id = a.aluno_id
            WHERE a.responsavel_id = ? AND a.ativo = 1
            ORDER BY a.nome
        ");

        error_log("EXECUTANDO QUERY ALUNOS");
        $stmt->execute([$responsavel['responsavel_id']]);
        $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
        error_log("ALUNOS ENCONTRADOS: " . count($data));

        Response::success($data);
    }

    // ==========================================
    // POST — Criar aluno + escola
    // ==========================================
    if ($method === 'POST') {
        $body            = json_decode(file_get_contents('php://input'), true) ?? [];

        // ── Reativar aluno ──
        if (($body['action'] ?? '') === 'reactivate') {
            $alunoId = (int)($body['id'] ?? 0);
            if (!$alunoId) Response::error('id é obrigatório.');
            $chk = $pdo->prepare("
                SELECT a.aluno_id FROM alunos a
                JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
                WHERE a.aluno_id = ? AND r.uid = ?
            ");
            $chk->execute([$alunoId, $uid]);
            if (!$chk->fetch()) Response::error('Aluno não encontrado ou sem permissão.', 403);
            $pdo->prepare("UPDATE alunos SET ativo = 1, updated_at = NOW() WHERE aluno_id = ?")
                ->execute([$alunoId]);
            Response::success(null, 'Aluno reativado.');
        }
        $name            = trim($body['name']               ?? '');
        $school          = trim($body['school']             ?? '');   // nome (fallback)
        $escolaIdInput   = isset($body['escola_id']) ? (int)$body['escola_id'] : null;
        $rcep            = trim($body['residence_cep']      ?? '');
        $van             = trim($body['van_code']           ?? '');
        $ciclo           = trim($body['ciclo_escolar']      ?? '');
        $turno           = trim($body['turno']              ?? '');
        $numero          = trim($body['numero_residencia']  ?? '');
        $complemento     = trim($body['complemento']        ?? '');
        $bairroRes       = trim($body['bairro_residencia']  ?? '');
        $dataNasc        = trim($body['data_nascimento']    ?? '');

        if (!$name) Response::error('Nome do aluno é obrigatório.');
        if (!$escolaIdInput && !$school) Response::error('Escola é obrigatória.');

        // Busca responsável
        $respStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
        $respStmt->execute([$uid]);
        $responsavel = $respStmt->fetch(PDO::FETCH_ASSOC);
        if (!$responsavel) Response::error('Responsável não encontrado.', 404);

        // Resolve escola_id
        if ($escolaIdInput) {
            $escolaId = $escolaIdInput;
        } else {
            // Fallback: busca/cria pelo nome
            $escStmt = $pdo->prepare("SELECT escola_id FROM escolas WHERE LOWER(nome) = LOWER(?) LIMIT 1");
            $escStmt->execute([$school]);
            $escola = $escStmt->fetch(PDO::FETCH_ASSOC);
            if (!empty($escola['escola_id'])) {
                $escolaId = $escola['escola_id'];
            } else {
                $pdo->prepare("
                    INSERT INTO escolas (nome, municipio, estado, administracao, status, aprovado, created_at, updated_at)
                    VALUES (?, '', '', 'municipal', 'pendente', 0, NOW(), NOW())
                ")->execute([$school]);
                $escolaId = (int)$pdo->lastInsertId();
            }
        }

        // Insere aluno com todos os campos
        $logradouro = trim($body['logradouro'] ?? '');

        $ins = $pdo->prepare("
            INSERT INTO alunos (
                responsavel_id, nome, escola_id, cep_residencia,
                logradouro, numero_residencia, complemento, bairro_residencia,
                ciclo_escolar, turno, van_code, data_nascimento,
                ativo, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(), NOW())
        ");
        $ins->execute([
            $responsavel['responsavel_id'],
            $name,
            $escolaId,
            $rcep ?: null,
            $logradouro ?: null,
            $numero ?: null,
            $complemento ?: null,
            $bairroRes ?: null,
            $ciclo ?: null,
            $turno ?: null,
            $van ?: null,
            $dataNasc ?: null,
        ]);

        $studentId = (int)$pdo->lastInsertId();

        // Retorna o aluno completo para o app atualizar o estado
        $stmt = $pdo->prepare("
            SELECT
                a.aluno_id AS id,
                a.nome AS name,
                COALESCE(e.nome, 'Sem escola') AS school,
                COALESCE(a.cep_residencia, '') AS residence_cep,
                COALESCE(a.ciclo_escolar, '') AS ciclo_escolar,
                'waiting_van' AS status_atual,
                1 AS vai_hoje,
                0 AS talk_requested,
                0 AS talk_acknowledged,
                '' AS driver_name,
                '' AS driver_whatsapp,
                1 AS ativo,
                0 AS payment_paid
            FROM alunos a
            LEFT JOIN escolas e ON e.escola_id = a.escola_id
            WHERE a.aluno_id = ?
        ");
        $stmt->execute([$studentId]);
        $aluno = $stmt->fetch();

        Response::success($aluno, 'Aluno criado.');
    }

    // ==========================================
    // DELETE — Desativar aluno (soft delete)
    // ==========================================
    if ($method === 'DELETE') {
        $body    = json_decode(file_get_contents('php://input'), true) ?? [];
        $alunoId = (int)($body['id'] ?? 0);
        if (!$alunoId) Response::error('id é obrigatório.');

        // Verifica que o aluno pertence ao responsável logado
        $chk = $pdo->prepare("
            SELECT a.aluno_id FROM alunos a
            JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
            WHERE a.aluno_id = ? AND r.uid = ?
        ");
        $chk->execute([$alunoId, $uid]);
        if (!$chk->fetch()) Response::error('Aluno não encontrado ou sem permissão.', 403);

        $pdo->prepare("UPDATE alunos SET ativo = 0, updated_at = NOW() WHERE aluno_id = ?")
            ->execute([$alunoId]);

        Response::success(null, 'Aluno removido.');
    }

    Response::error('Método não permitido.', 405);

} catch (Exception $e) {
    error_log("ERRO STUDENTS API: " . $e->getMessage());
    Response::error('Erro interno: ' . $e->getMessage(), 500);
}
