<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'PUT') Response::methodNotAllowed();

$auth = AuthMiddleware::require();
$uid  = $auth['sub'] ?? $auth['user_id'] ?? '';

$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$id     = (int)($body['id']           ?? 0);
$name   = trim($body['name']          ?? '');
$school = trim($body['school']        ?? '');
$rcep   = trim($body['residence_cep'] ?? '');
$ciclo  = trim($body['ciclo_escolar'] ?? '');

if (!$id) Response::error('id é obrigatório.');
if (!$school) Response::error('Escola é obrigatória.');

try {
    $pdo = Database::getInstance();

    // Verify ownership
    $chk = $pdo->prepare("
        SELECT a.aluno_id FROM alunos a
        JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
        WHERE a.aluno_id = ? AND r.uid = ?
    ");
    $chk->execute([$id, $uid]);
    if (!$chk->fetch()) Response::error('Aluno não encontrado ou sem permissão.', 403);

    // Buscar/criar escola
    $escStmt = $pdo->prepare("
        SELECT escola_id FROM escolas WHERE LOWER(nome) = LOWER(?) LIMIT 1
    ");
    $escStmt->execute([$school]);
    $escola = $escStmt->fetch(PDO::FETCH_ASSOC);

    if (!empty($escola['escola_id'])) {
        $escolaId = $escola['escola_id'];
    } else {
        $escolaId = time() . rand(100, 999);
        $createSchool = $pdo->prepare("
            INSERT INTO escolas (escola_id, nome, municipio, estado, administracao, status, created_at, updated_at)
            VALUES (?, ?, '', '', 'municipal', 'pendente', NOW(), NOW())
        ");
        $createSchool->execute([$escolaId, $school]);
    }

    $fields = [];
    $params = [];
    if ($name)   { $fields[] = 'nome = ?';          $params[] = $name; }
    if ($school) { $fields[] = 'escola_id = ?';     $params[] = $escolaId; }
    if ($rcep)   { $fields[] = 'cep_residencia = ?';$params[] = $rcep; }
    if ($ciclo)  { $fields[] = 'ciclo_escolar = ?'; $params[] = $ciclo; }
    $fields[] = 'updated_at = NOW()';
    $params[] = $id;

    $pdo->prepare('UPDATE alunos SET ' . implode(', ', $fields) . ' WHERE aluno_id = ?')
        ->execute($params);

    // Busca aluno atualizado para retornar completo
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
        WHERE a.aluno_id = ?
        LIMIT 1
    ");
    $stmt->execute([$id]);
    $aluno = $stmt->fetch(PDO::FETCH_ASSOC);

    Response::success($aluno, 'Aluno atualizado.');
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
