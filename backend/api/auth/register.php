<?php
ini_set('display_errors', '0');
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

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
    Response::error('BODY: ' . file_get_contents('php://input') . ' | uid=' . $uid . ' name=' . $name . ' email=' . $email);
}

$allowedRoles = ['responsavel', 'motorista', 'admin'];
if (!in_array($role, $allowedRoles, true)) {
    Response::error('Role inválido.');
}

try {
    $pdo = Database::getInstance();

    $stmt = $pdo->prepare('SELECT id FROM usuarios WHERE uid = ? OR email = ? LIMIT 1');
    $stmt->execute([$uid, $email]);
    $user = $stmt->fetch();

    if ($user) {
        $pdo->prepare('UPDATE usuarios SET uid=?, nome=?, email=?, telefone=?, role=?, updated_at=NOW() WHERE id=?')
            ->execute([$uid, $name, $email, $whatsapp, $role, $user['id']]);
        $usuarioId = $user['id'];
    } else {
        $pdo->prepare('INSERT INTO usuarios (uid, nome, email, telefone, role, created_at) VALUES (?,?,?,?,?,NOW())')
            ->execute([$uid, $name, $email, $whatsapp, $role]);
        $usuarioId = $pdo->lastInsertId();
    }

    if ($role === 'motorista') {
        $chk = $pdo->prepare('SELECT motorista_id FROM motoristas WHERE uid = ? OR email = ? LIMIT 1');
        $chk->execute([$uid, $email]);
        $existing = $chk->fetch();
        if ($existing) {
            $pdo->prepare('UPDATE motoristas SET uid=?, nome=?, email=?, telefone=?, updated_at=NOW() WHERE motorista_id=?')
                ->execute([$uid, $name, $email, $whatsapp, $existing['motorista_id']]);
        } else {
            $vanCode = 'VAN' . strtoupper(substr(md5($uid), 0, 6));
            $pdo->prepare('INSERT INTO motoristas (usuario_id, uid, nome, email, telefone, van_code, created_at) VALUES (?,?,?,?,?,?,NOW())')
                ->execute([$usuarioId, $uid, $name, $email, $whatsapp, $vanCode]);
        }
    }

    if ($role === 'responsavel') {
        $chk = $pdo->prepare('SELECT responsavel_id FROM responsaveis WHERE uid = ? OR email = ? LIMIT 1');
        $chk->execute([$uid, $email]);
        $existing = $chk->fetch();
        if ($existing) {
            $pdo->prepare('UPDATE responsaveis SET uid=?, nome=?, email=?, telefone=?, updated_at=NOW() WHERE responsavel_id=?')
                ->execute([$uid, $name, $email, $whatsapp, $existing['responsavel_id']]);
        } else {
            $pdo->prepare('INSERT INTO responsaveis (usuario_id, uid, nome, email, telefone, created_at) VALUES (?,?,?,?,?,NOW())')
                ->execute([$usuarioId, $uid, $name, $email, $whatsapp]);
        }
    }

    Response::success(['uid' => $uid, 'role' => $role], 'Usuário registrado.', 201);
} catch (PDOException $e) {
    Response::error('DB ERROR: ' . $e->getMessage(), 500);
} catch (Exception $e) {
    Response::error('EXCEPTION: ' . $e->getMessage(), 500);
} catch (Throwable $e) {
    Response::error('FATAL: ' . $e->getMessage(), 500);
}
