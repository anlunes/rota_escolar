<?php
/**
 * POST /api/auth/verify_reset_code.php
 * Body JSON: { "email": "usuario@email.com", "code": "123456" }
 *
 * Valida o código de 6 dígitos. Se correto, gera um token seguro
 * e retorna o link para nossa página de reset própria.
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::methodNotAllowed();

$body  = json_decode(file_get_contents('php://input'), true) ?? [];
$email = trim($body['email'] ?? '');
$code  = trim($body['code']  ?? '');

if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::error('E-mail inválido.', 400);
}
if (!$code || strlen($code) !== 6 || !ctype_digit($code)) {
    Response::error('Código inválido.', 400);
}

try {
    $pdo = Database::getInstance();

    $stmt = $pdo->prepare(
        "SELECT id FROM password_reset_codes
         WHERE email = ? AND code = ? AND used = 0 AND expires_at > NOW()
         LIMIT 1"
    );
    $stmt->execute([$email, $code]);
    $row = $stmt->fetch();

    if (!$row) {
        Response::error('Código inválido ou expirado. Solicite um novo código.', 422);
    }

    // Gera token seguro de 64 chars (válido por 1 hora)
    $token = bin2hex(random_bytes(32));

    // Salva token na linha existente (reutilizamos a tabela)
    $pdo->prepare(
        "UPDATE password_reset_codes
         SET used = 1, reset_token = ?, reset_token_expires_at = DATE_ADD(NOW(), INTERVAL 1 HOUR)
         WHERE id = ?"
    )->execute([$token, $row['id']]);

    $resetLink = 'https://rotaescolar.app.br/reset-senha.html?token=' . $token;

    error_log("[verify_reset_code] Código validado para $email — token gerado");

    Response::success(['reset_link' => $resetLink], 'Código validado com sucesso.');

} catch (Exception $e) {
    error_log("[verify_reset_code] Erro: " . $e->getMessage());
    Response::error('Não foi possível validar o código. Tente novamente.', 500);
}
