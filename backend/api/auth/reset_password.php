<?php
/**
 * POST /api/auth/reset_password.php
 * Body JSON: { "token": "...", "password": "novasenha" }
 *
 * Valida o token de reset, atualiza a senha no Firebase via Admin SDK
 * e envia e-mail de confirmação.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/firebase_admin.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::methodNotAllowed();

$body     = json_decode(file_get_contents('php://input'), true) ?? [];
$token    = trim($body['token']    ?? '');
$password = $body['password'] ?? '';

if (!$token || strlen($token) !== 64) {
    Response::error('Token inválido.', 400);
}
if (!$password || strlen($password) < 6) {
    Response::error('A senha deve ter pelo menos 6 caracteres.', 400);
}

try {
    $pdo = Database::getInstance();

    // Busca token válido (sem JOIN para evitar conflito de collation entre tabelas)
    $stmt = $pdo->prepare(
        "SELECT id, email FROM password_reset_codes
         WHERE BINARY reset_token = ?
           AND reset_token_expires_at > NOW()
         LIMIT 1"
    );
    $stmt->execute([$token]);
    $prc = $stmt->fetch();

    if (!$prc) {
        Response::error('Link expirado ou inválido. Solicite uma nova redefinição.', 422);
    }

    // Busca UID na tabela de usuários
    $stmt2 = $pdo->prepare("SELECT uid FROM usuarios WHERE email = ? LIMIT 1");
    $stmt2->execute([$prc['email']]);
    $user = $stmt2->fetch();

    if (!$user) {
        Response::error('Usuário não encontrado.', 404);
    }

    $row = ['id' => $prc['id'], 'email' => $prc['email'], 'uid' => $user['uid']];

    // Atualiza senha no Firebase via Admin SDK
    FirebaseAdmin::updateUserPassword($row['uid'], $password);

    // Invalida o token
    $pdo->prepare(
        "UPDATE password_reset_codes SET reset_token = NULL, reset_token_expires_at = NULL WHERE id = ?"
    )->execute([$row['id']]);

    // Envia e-mail de confirmação
    $email   = $row['email'];
    $subject = '=?UTF-8?B?' . base64_encode('Sua senha foi alterada — Rota Escolar') . '?=';
    $mensagem =
        "Olá!\n\n" .
        "Sua senha no Rota Escolar foi alterada com sucesso.\n\n" .
        "Se você não realizou essa alteração, entre em contato imediatamente respondendo este e-mail.\n\n" .
        "Equipe Rota Escolar\n" .
        "https://rotaescolar.app.br";

    $headers = implode("\r\n", [
        'From: Rota Escolar <noreply@rotaescolar.app.br>',
        'Reply-To: noreply@rotaescolar.app.br',
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
    ]);

    mail($email, $subject, $mensagem, $headers);
    error_log("[reset_password] Senha atualizada para $email");

    Response::success([], 'Senha alterada com sucesso!');

} catch (Exception $e) {
    error_log("[reset_password] Erro: " . $e->getMessage());
    // DEBUG TEMPORÁRIO — remover após identificar o erro
    Response::error('DEBUG: ' . $e->getMessage(), 500);
}
