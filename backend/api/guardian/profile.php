<?php
/**
 * GET  /api/guardian/profile.php  → retorna perfil do responsável
 * POST /api/guardian/profile.php  → salva CPF + endereço completo
 * Body JSON: { cpf, cep, logradouro, numero, complemento, bairro_nome, cidade, estado_uf }
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
            SELECT r.responsavel_id, r.cpf, r.cep, r.logradouro, r.numero,
                   r.complemento, r.bairro_nome, r.cidade, r.estado_uf
            FROM responsaveis r
            WHERE r.uid = ?
            LIMIT 1
        ");
        $stmt->execute([$uid]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$row) Response::notFound('Responsável não encontrado.');

        $hasCpf = !empty(trim($row['cpf'] ?? ''));
        $hasCep = !empty(trim($row['cep'] ?? ''));

        $hasFilho = false;
        if ($row['responsavel_id']) {
            $fStmt = $pdo->prepare("SELECT COUNT(*) FROM alunos WHERE responsavel_id = ? AND ativo = 1");
            $fStmt->execute([$row['responsavel_id']]);
            $hasFilho = ((int) $fStmt->fetchColumn()) > 0;
        }

        Response::success([
            'cpf'               => $row['cpf']        ?? '',
            'cep'               => $row['cep']        ?? '',
            'logradouro'        => $row['logradouro'] ?? '',
            'numero'            => $row['numero']     ?? '',
            'complemento'       => $row['complemento'] ?? '',
            'bairro_nome'       => $row['bairro_nome'] ?? '',
            'cidade'            => $row['cidade']     ?? '',
            'estado_uf'         => $row['estado_uf']  ?? '',
            'has_cpf'           => $hasCpf,
            'has_cep'           => $hasCep,
            'has_filho'         => $hasFilho,
            'onboarding_complete' => $hasCpf && $hasCep,
        ]);
    }

    // ------------------------------------------------------------------
    // POST — salva CPF + endereço
    // ------------------------------------------------------------------
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $body = json_decode(file_get_contents('php://input'), true) ?? [];

        $cpf        = trim($body['cpf']        ?? '');
        $cep        = trim($body['cep']        ?? '');
        $logradouro = trim($body['logradouro'] ?? '');
        $numero     = trim($body['numero']     ?? '');
        $complemento = trim($body['complemento'] ?? '');
        $bairroNome = trim($body['bairro_nome'] ?? '');
        $cidade     = trim($body['cidade']     ?? '');
        $estadoUf   = trim($body['estado_uf']  ?? '');

        if (empty($cpf))        Response::error('CPF é obrigatório.');
        if (empty($cep))        Response::error('CEP é obrigatório.');
        if (empty($numero))     Response::error('Número é obrigatório.');

        // Normaliza CPF e CEP (remove máscara)
        $cpfDigits = preg_replace('/\D/', '', $cpf);
        $cepDigits = preg_replace('/\D/', '', $cep);

        if (strlen($cpfDigits) !== 11) Response::error('CPF inválido.');
        if (strlen($cepDigits) !== 8)  Response::error('CEP inválido.');

        // Tenta UPDATE primeiro
        $upd = $pdo->prepare("
            UPDATE responsaveis
               SET cpf         = ?,
                   cep         = ?,
                   logradouro  = ?,
                   numero      = ?,
                   complemento = ?,
                   bairro_nome = ?,
                   cidade      = ?,
                   estado_uf   = ?,
                   updated_at  = NOW()
             WHERE uid = ?
        ");
        $upd->execute([
            $cpfDigits,
            $cepDigits,
            $logradouro ?: null,
            $numero,
            $complemento ?: null,
            $bairroNome ?: null,
            $cidade ?: null,
            $estadoUf ?: null,
            $uid,
        ]);

        // Se não encontrou o registro (register.php falhou antes), cria agora
        if ($upd->rowCount() === 0) {
            // Busca dados básicos do usuário para criar o registro
            $uStmt = $pdo->prepare("SELECT id, nome, email, telefone FROM usuarios WHERE uid = ? LIMIT 1");
            $uStmt->execute([$uid]);
            $uRow = $uStmt->fetch(PDO::FETCH_ASSOC);

            if (!$uRow) Response::error('Usuário não encontrado.', 404);

            $pdo->prepare("
                INSERT INTO responsaveis
                    (usuario_id, uid, nome, email, telefone, whatsapp,
                     cpf, cep, logradouro, numero, complemento, bairro_nome, cidade, estado_uf, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
            ")->execute([
                $uRow['id'], $uid, $uRow['nome'], $uRow['email'],
                $uRow['telefone'], $uRow['telefone'],
                $cpfDigits, $cepDigits,
                $logradouro ?: null, $numero, $complemento ?: null,
                $bairroNome ?: null, $cidade ?: null, $estadoUf ?: null,
            ]);
        }

        Response::success(['saved' => true], 'Perfil atualizado com sucesso.');
    }

    Response::methodNotAllowed();

} catch (Exception $e) {
    Response::error('Erro interno: ' . $e->getMessage(), 500);
}
