<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

AuthMiddleware::require();

$bairro    = $_GET['bairro']    ?? '';
$municipio = $_GET['municipio'] ?? '';

try {
    $pdo = Database::getInstance();
    $sql = "
        SELECT DISTINCT
            m.motorista_id AS id, m.nome AS name, m.whatsapp,
            m.van_code, m.foto_url AS photo_url,
            AVG(av.nota) AS rating,
            COUNT(av.avaliacao_id) AS review_count
        FROM motoristas m
        LEFT JOIN avaliacoes av ON av.motorista_id = m.motorista_id
    ";
    $params = [];

    if ($bairro || $municipio) {
        $sql .= " JOIN motorista_bairros mb ON mb.motorista_id = m.motorista_id";
        $sql .= " JOIN bairros b ON b.id = mb.bairro_id";
        $sql .= " JOIN municipios mu ON mu.id = b.municipio_id";
        if ($bairro) {
            $sql .= " AND b.nome = ?"; $params[] = $bairro;
        }
        if ($municipio) {
            $sql .= " AND mu.nome = ?"; $params[] = $municipio;
        }
    }
    $sql .= " WHERE m.ativo = 1 GROUP BY m.motorista_id ORDER BY rating DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    Response::success($stmt->fetchAll());
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
