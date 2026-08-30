<?php
/**
 * GET /api/location/escolas.php?q=nome   → busca escolas aprovadas por nome (autocomplete)
 * GET /api/location/escolas.php          → lista todas as escolas aprovadas
 */

ob_start();
ini_set('display_errors', 0);

require_once __DIR__ . '/../../config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

function jsonOk($data, $message = 'OK') {
    ob_end_clean();
    echo json_encode(['success' => true, 'message' => $message, 'data' => $data]);
    exit;
}
function jsonErr($message, $status = 400) {
    ob_end_clean();
    http_response_code($status);
    echo json_encode(['success' => false, 'message' => $message]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { ob_end_clean(); http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonErr('Método não permitido.', 405);

$q = trim($_GET['q'] ?? '');

try {
    $pdo = Database::getInstance();

    if ($q !== '') {
        // Busca por nome (mínimo 2 caracteres)
        if (mb_strlen($q) < 2) jsonOk([]);

        $stmt = $pdo->prepare("
            SELECT escola_id AS id, nome,
                   COALESCE(logradouro,'') AS logradouro,
                   COALESCE(numero,'')     AS numero,
                   COALESCE(bairro,'')     AS bairro,
                   COALESCE(municipio,'')  AS municipio,
                   COALESCE(estado,'')     AS estado,
                   COALESCE(cep,'')        AS cep
            FROM escolas
            WHERE aprovado = 1 AND nome LIKE ?
            ORDER BY nome
            LIMIT 20
        ");
        $stmt->execute(['%' . $q . '%']);
    } else {
        $stmt = $pdo->prepare("
            SELECT escola_id AS id, nome,
                   COALESCE(logradouro,'') AS logradouro,
                   COALESCE(numero,'')     AS numero,
                   COALESCE(bairro,'')     AS bairro,
                   COALESCE(municipio,'')  AS municipio,
                   COALESCE(estado,'')     AS estado,
                   COALESCE(cep,'')        AS cep
            FROM escolas
            WHERE aprovado = 1
            ORDER BY nome
            LIMIT 200
        ");
        $stmt->execute();
    }

    jsonOk($stmt->fetchAll());
} catch (Throwable $e) {
    jsonErr('Erro ao buscar escolas: ' . $e->getMessage(), 500);
}
