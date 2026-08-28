<?php
require_once __DIR__ . '/../cors.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';
if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::methodNotAllowed();

$body = json_decode(file_get_contents('php://input'), true) ?? [];

$uid      = trim($body['uid']      ?? '');
$name     = trim($body['nome']     ?? $body['name']     ?? '');
$email    = trim($body['email']    ?? '');
$whatsapp = trim($body['telefone'] ?? $body['whatsapp'] ?? '');
$role     = trim($body['role']     ?? 'responsavel');

if (!$uid || !$name || !$email) {
    Response::error('Campos obrigatórios: uid, name, email.');
}

$allowedRoles = ['responsavel', 'motorista', 'admin'];
if (!in_array($role, $allowedRoles, true)) {
    Response::error('Role inválido.');
}

try {
    $pdo = Database::getInstance();

    // Check if user already exists
    $stmt = $pdo->prepare('SELECT usuario_id FROM usuarios WHERE uid = ? OR email = ? LIMIT 1');
    $stmt->execute([$uid, $email]);

    $user = $stmt->fetch();

    if ($user) {
        // Update existing
        $upd = $pdo->prepare('UPDATE usuarios SET nome=?, telefone=?, updated_at=NOW() WHERE uid=?');
        $upd->execute([$name, $whatsapp, $uid]);

        $usuarioId = $user['usuario_id'];
    } else {
        // Insert new
        $ins = $pdo->prepare(
            'INSERT INTO usuarios (uid, nome, email, telefone, role, created_at) VALUES (?,?,?,?,?,NOW())'
        );

        $ins->execute([$uid, $name, $email, $whatsapp, $role]);

        $usuarioId = $pdo->lastInsertId();
    }

    // If motorista, ensure motoristas record
    if ($role === 'motorista') {
        $chk = $pdo->prepare('SELECT motorista_id FROM motoristas WHERE uid = ? LIMIT 1');
        $chk->execute([$uid]);
        if (!$chk->fetch()) {
            $vanCode = 'VAN' . strtoupper(substr(md5($uid), 0, 6));
            $ins2 = $pdo->prepare(
                'INSERT INTO motoristas (usuario_id, uid, nome, email, telefone, van_code, created_at) VALUES (?,?,?,?,?,?,NOW())'
            );
            $ins2->execute([$usuarioId, $uid, $name, $email, $whatsapp, $vanCode]);
        }
    }

    // If responsavel, ensure responsaveis record
    if ($role === 'responsavel') {
        $chk = $pdo->prepare('SELECT responsavel_id FROM responsaveis WHERE uid = ? LIMIT 1');
        $chk->execute([$uid]);
        if (!$chk->fetch()) {
            $ins3 = $pdo->prepare(
                'INSERT INTO responsaveis (usuario_id, uid, nome, email, telefone, created_at) VALUES (?,?,?,?,?,NOW())'
            );
            $ins3->execute([$usuarioId, $uid, $name, $email, $whatsapp]);
        }
    }

    Response::success(['uid' => $uid, 'role' => $role], 'Usuário registrado.', 201);
} catch (PDOException $e) {
    Response::error('Erro no banco de dados: ' . $e->getMessage(), 500);
}
