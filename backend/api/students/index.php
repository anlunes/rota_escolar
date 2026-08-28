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
                COALESCE(a.cep_residencia, '') AS residence_cep,
                COALESCE(a.ciclo_escolar, '') AS ciclo_escolar,
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
            WHERE a.responsavel_id = ?
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
        $body   = json_decode(file_get_contents('php://input'), true) ?? [];
        $name   = trim($body['name']          ?? '');
        $school = trim($body['school']        ?? '');
        $rcep   = trim($body['residence_cep'] ?? '');
        $van    = trim($body['van_code']      ?? '');
        $ciclo  = trim($body['ciclo_escolar'] ?? '');

        if (!$name || !$school) Response::error('Nome e escola são obrigatórios.');

        // Busca responsável
        $respStmt = $pdo->prepare("SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1");
        $respStmt->execute([$uid]);
        $responsavel = $respStmt->fetch(PDO::FETCH_ASSOC);

        if (!$responsavel) Response::error('Responsável não encontrado.', 404);

        // Busca/cria escola
        $escStmt = $pdo->prepare("SELECT escola_id FROM escolas WHERE LOWER(nome) = LOWER(?) LIMIT 1");
        $escStmt->execute([$school]);
        $escola = $escStmt->fetch(PDO::FETCH_ASSOC);

        if (!empty($escola['escola_id'])) {
            $escolaId = $escola['escola_id'];
        } else {
            // Gera escola_id único (timestamp + random)
            $escolaId = time() . rand(100, 999);
            $createSchool = $pdo->prepare("
                INSERT INTO escolas (escola_id, nome, municipio, estado, administracao, status, created_at, updated_at)
                VALUES (?, ?, '', '', 'municipal', 'pendente', NOW(), NOW())
            ");
            $createSchool->execute([$escolaId, $school]);
        }

        // Insere aluno
        $ins = $pdo->prepare("
            INSERT INTO alunos (
                responsavel_id, nome, escola_id, cep_residencia,
                ciclo_escolar, van_code, ativo, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 1, NOW(), NOW())
        ");
        $ins->execute([
            $responsavel['responsavel_id'], $name, $escolaId, $rcep, $ciclo, $van ?: null
        ]);

        $studentId = $pdo->lastInsertId();
        Response::success(['id' => $studentId, 'escola_id' => $escolaId], 'Aluno criado.');
    }

    Response::error('Método não permitido.', 405);

} catch (Exception $e) {
    error_log("ERRO STUDENTS API: " . $e->getMessage());
    Response::error('Erro interno: ' . $e->getMessage(), 500);
}
