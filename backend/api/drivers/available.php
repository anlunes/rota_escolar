<?php
/**
 * GET /api/drivers/available.php
 * Lista motoristas disponíveis na região para o responsável.
 *
 * Query params (opcionais):
 *   municipio_id=3304557  → filtra por município
 *   bairro_id=12          → filtra por bairro específico
 *   min_rating=3.0        → nota mínima (default: sem filtro)
 *
 * Retorna por motorista:
 *   id, nome, foto_url, van_code, whatsapp
 *   docs_ok: { cnh, crlv, seguro }
 *   rating: { media, total }
 *   bairros: [{ id, nome }]
 *   alunos_ativos (para estimar vagas)
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

AuthMiddleware::require(); // qualquer usuário autenticado pode listar

$municipioId = isset($_GET['municipio_id']) ? (int)$_GET['municipio_id'] : 0;
$bairroId    = isset($_GET['bairro_id'])    ? (int)$_GET['bairro_id']    : 0;
$minRating   = isset($_GET['min_rating'])   ? (float)$_GET['min_rating'] : 0;

try {
    $pdo = Database::getInstance();

    // ── 1. Busca motoristas ativos ───────────────────────────────────────────
    $stmt = $pdo->query("
        SELECT
            m.motorista_id,
            m.nome,
            m.foto_url,
            m.van_code,
            m.whatsapp,
            CASE WHEN m.cnh_url         IS NOT NULL AND m.cnh_url         != '' THEN 1 ELSE 0 END AS doc_cnh,
            CASE WHEN m.crlv_url        IS NOT NULL AND m.crlv_url        != '' THEN 1 ELSE 0 END AS doc_crlv,
            CASE WHEN m.seguro_url      IS NOT NULL AND m.seguro_url      != '' THEN 1 ELSE 0 END AS doc_seguro,
            CASE WHEN m.autorizacao_url IS NOT NULL AND m.autorizacao_url != '' THEN 1 ELSE 0 END AS doc_autorizacao,
            COALESCE((SELECT COUNT(*) FROM alunos WHERE motorista_id = m.motorista_id AND ativo = 1), 0) AS alunos_ativos
        FROM motoristas m
        WHERE m.ativo = 1
        ORDER BY m.nome ASC
    ");
    $motoristas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // ── Rating: tenta buscar da tabela avaliacoes (pode não existir ainda) ───
    $hasAvaliacoes = false;
    try {
        $pdo->query("SELECT 1 FROM avaliacoes LIMIT 1");
        $hasAvaliacoes = true;
    } catch (Throwable $ignored) {}

    $ratingStmt = null;
    if ($hasAvaliacoes) {
        $ratingStmt = $pdo->prepare(
            "SELECT AVG(nota) AS media, COUNT(*) AS total FROM avaliacoes WHERE motorista_id = ?"
        );
    }

    // ── 2. Para cada motorista, busca bairros e escolas atendidas ───────────
    $bairrosStmt = $pdo->prepare("
        SELECT b.id, b.nome
        FROM motorista_bairros mb
        JOIN bairros b ON b.id = mb.bairro_id
        WHERE mb.motorista_id = ?
        ORDER BY b.nome
    ");

    $escolasStmt = $pdo->prepare("
        SELECT DISTINCT e.escola_id AS id, e.nome
        FROM alunos a
        JOIN escolas e ON e.escola_id = a.escola_id
        WHERE a.motorista_id = ? AND a.ativo = 1 AND a.escola_id IS NOT NULL
        ORDER BY e.nome
    ");

    foreach ($motoristas as &$m) {
        $bairrosStmt->execute([$m['motorista_id']]);
        $m['bairros'] = $bairrosStmt->fetchAll(PDO::FETCH_ASSOC);

        $escolasStmt->execute([$m['motorista_id']]);
        $m['escolas'] = $escolasStmt->fetchAll(PDO::FETCH_ASSOC);

        // Rating
        $ratingMedia = 0;
        $ratingTotal = 0;
        if ($ratingStmt) {
            $ratingStmt->execute([$m['motorista_id']]);
            $r = $ratingStmt->fetch(PDO::FETCH_ASSOC);
            $ratingMedia = round((float)($r['media'] ?? 0), 1);
            $ratingTotal = (int)($r['total'] ?? 0);
        }

        $m['id']           = (int)$m['motorista_id'];
        $m['rating_media'] = $ratingMedia;
        $m['rating_total'] = $ratingTotal;
        $m['alunos_ativos']= (int)$m['alunos_ativos'];
        $m['docs_ok'] = [
            'cnh'         => (bool)$m['doc_cnh'],
            'crlv'        => (bool)$m['doc_crlv'],
            'seguro'      => (bool)$m['doc_seguro'],
            'autorizacao' => (bool)$m['doc_autorizacao'],
        ];
        unset($m['motorista_id'], $m['doc_cnh'], $m['doc_crlv'], $m['doc_seguro'], $m['doc_autorizacao']);
    }
    unset($m);

    Response::success($motoristas);

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
