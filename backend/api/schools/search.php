<?php
/**
 * GET /api/schools/search.php?q=cruzeiro&estado=RJ&municipio=Rio+de+Janeiro
 *
 * Autocomplete de escolas para o cadastro de alunos.
 * Retorna até 10 escolas que correspondem à busca.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET')     Response::methodNotAllowed();

$q         = trim($_GET['q']         ?? '');
$estado    = strtoupper(trim($_GET['estado']    ?? ''));
$municipio = trim($_GET['municipio'] ?? '');

if (mb_strlen($q) < 2) {
    Response::success(['escolas' => []]);
}

try {
    $pdo = Database::getInstance();

    // Busca FULLTEXT por nome dentro do estado (obrigatório) e município (opcional)
    // Fallback para LIKE se FULLTEXT não retornar resultados (ex: termo muito curto)
    $params = [];
    $where  = ["(status = 'verificado' OR status = 'ativo')"];

    if ($estado) {
        $where[]  = 'estado = ?';
        $params[] = $estado;
    }
    if ($municipio) {
        $where[]  = 'municipio = ?';
        $params[] = $municipio;
    }

    $whereStr = implode(' AND ', $where);

    // Tenta FULLTEXT primeiro
    $stmt = $pdo->prepare("
        SELECT escola_id, nome, municipio, estado, status, lat, lon, logradouro,
               MATCH(nome) AGAINST (? IN BOOLEAN MODE) AS relevancia,
               IF(estado = 'RJ', 1, 0) AS preferencia_rj
        FROM escolas
        WHERE {$whereStr}
          AND MATCH(nome) AGAINST (? IN BOOLEAN MODE)
        ORDER BY preferencia_rj DESC, relevancia DESC, nome ASC
        LIMIT 10
    ");
    $stmt->execute(array_merge([$q . '*'], $params, [$q . '*']));
    $escolas = $stmt->fetchAll();

    // Fallback LIKE se FULLTEXT não achou nada
    if (empty($escolas)) {
        $likeParams = array_merge(['%' . $q . '%'], $params);
        $stmt = $pdo->prepare("
            SELECT escola_id, nome, municipio, estado, status, lat, lon, logradouro
            FROM escolas
            WHERE nome LIKE ?
              AND {$whereStr}
            ORDER BY IF(estado = 'RJ', 0, 1), nome ASC
            LIMIT 10
        ");
        $stmt->execute($likeParams);
        $escolas = $stmt->fetchAll();
    }

    Response::success([
        'escolas' => array_map(fn($e) => [
            'escola_id'      => (int)$e['escola_id'],
            'nome'           => $e['nome'],
            'municipio'      => $e['municipio'],
            'estado'         => $e['estado'],
            'status'         => $e['status'],
            'logradouro'     => $e['logradouro'] ?? '',
            'tem_coords'     => !empty($e['lat']) && !empty($e['lon']),
            'tem_logradouro' => !empty($e['logradouro']),
        ], $escolas),
    ]);

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
