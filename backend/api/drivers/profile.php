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

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

$driverId = (int)($_GET['id'] ?? 0);

try {
    $pdo = Database::getInstance();

    if ($driverId) {
        $stmt = $pdo->prepare("SELECT * FROM motoristas WHERE motorista_id = ? AND ativo = 1 LIMIT 1");
        $stmt->execute([$driverId]);
    } else {
        $stmt = $pdo->prepare("SELECT * FROM motoristas WHERE uid = ? LIMIT 1");
        $stmt->execute([$uid]);
    }

    $driver = $stmt->fetch();
    if (!$driver) Response::notFound('Motorista não encontrado.');

    // Bairros atendidos (nova estrutura)
    $b = $pdo->prepare("
        SELECT b.nome AS bairro, mu.nome AS municipio, e.uf AS estado
        FROM motorista_bairros mb
        JOIN bairros b ON b.id = mb.bairro_id
        JOIN municipios mu ON mu.id = b.municipio_id
        JOIN estados e ON e.id = mu.estado_id
        WHERE mb.motorista_id = ?
        ORDER BY e.uf, mu.nome, b.nome
    ");
    $b->execute([$driver['motorista_id']]);
    $driver['bairros'] = $b->fetchAll();

    // Escolas atendidas
    $e = $pdo->prepare("SELECT e.escola_id, e.nome FROM escolas_atendidas ea JOIN escolas e ON e.escola_id = ea.escola_id WHERE ea.motorista_id = ?");
    $e->execute([$driver['motorista_id']]);
    $driver['escolas'] = $e->fetchAll();

    // Avaliações
    $avg = $pdo->prepare("SELECT AVG(nota) AS rating, COUNT(*) AS count FROM avaliacoes WHERE motorista_id = ?");
    $avg->execute([$driver['motorista_id']]);
    $driver['avaliacoes'] = $avg->fetch();

    Response::success($driver);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
