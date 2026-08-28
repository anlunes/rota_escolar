<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

// CORS headers
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') exit;

$auth = AuthMiddleware::require();
$uid  = $auth['sub'];

function fallbackName(array $auth): string {
    if (!empty($auth['name'])) return $auth['name'];
    $email = $auth['email'] ?? 'usuario';
    return current(explode('@', $email));
}

try {
    $pdo  = Database::getInstance();
    $stmt = $pdo->prepare('SELECT uid, nome, email, telefone, role FROM usuarios WHERE uid = ? LIMIT 1');
    $stmt->execute([$uid]);
    $user = $stmt->fetch();

    // Fallback: auto-provisiona usuário se não existir no banco
    if (!$user) {
        $name  = fallbackName($auth);
        $email = ($auth['email'] ?? '');
        $role  = 'guardian';
        $pdo->prepare(
            'INSERT INTO usuarios (uid, nome, email, telefone, role, created_at) VALUES (?,?,?,?,?,NOW())'
        )->execute([$uid, $name, $email, '', $role]);
        $user = [
            'uid'       => $uid,
            'nome'      => $name,
            'email'     => $email,
            'telefone'  => '',
            'role'      => $role,
        ];
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        Response::success($user);
    }

    if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        $body     = json_decode(file_get_contents('php://input'), true) ?? [];
        $name     = trim($body['name']     ?? $user['nome']);
        $whatsapp = trim($body['whatsapp'] ?? $user['telefone']);

        $pdo->prepare('UPDATE usuarios SET nome=?, telefone=?, updated_at=NOW() WHERE uid=?')
            ->execute([$name, $whatsapp, $uid]);

        Response::success(array_merge($user, ['nome' => $name, 'telefone' => $whatsapp]));
    }

    Response::methodNotAllowed();
} catch (PDOException $e) {
    Response::error('Erro no banco de dados.', 500);
}
