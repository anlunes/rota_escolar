<?php
/**
 * POST /api/auth/send_verification.php
 * Body JSON: { "email": "usuario@email.com", "nome": "Nome" }
 *
 * Gera código de 6 dígitos, salva no banco com expiração de 10 min
 * e envia por e-mail pelo servidor de hospedagem.
 * Não depende do Firebase Admin SDK — funciona igual ao forgot_password.
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
$nome  = trim($body['nome']  ?? 'usuário');

if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::error('E-mail inválido.', 400);
}

try {
    $pdo = Database::getInstance();

    // Remove códigos anteriores deste e-mail
    $pdo->prepare("DELETE FROM email_verification_codes WHERE email = ?")->execute([$email]);

    // Gera código de 6 dígitos
    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

    // Salva no banco com expiração de 10 minutos
    $pdo->prepare(
        "INSERT INTO email_verification_codes (email, code, expires_at, created_at)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE), NOW())"
    )->execute([$email, $code]);

    // Envia e-mail com o código
    $subject  = '=?UTF-8?B?' . base64_encode('Código de verificação — Rota Escolar') . '?=';
    $mensagem =
        "Olá, $nome!\n\n" .
        "Obrigado por se cadastrar no Rota Escolar.\n\n" .
        "Use o código abaixo no aplicativo para confirmar seu e-mail e ativar sua conta:\n\n" .
        "        $code\n\n" .
        "O código é válido por 10 minutos.\n\n" .
        "Se você não criou uma conta, ignore este e-mail.\n\n" .
        "Equipe Rota Escolar\n" .
        "https://rotaescolar.app.br";

    $headers = implode("\r\n", [
        'From: Rota Escolar <noreply@rotaescolar.app.br>',
        'Reply-To: noreply@rotaescolar.app.br',
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
    ]);

    $enviado = mail($email, $subject, $mensagem, $headers);
    error_log("[send_verification] Email " . ($enviado ? 'enviado' : 'FALHOU') . " para $email");

    Response::success([], 'Código de verificação enviado.');

} catch (Exception $e) {
    error_log("[send_verification] Erro: " . $e->getMessage());
    Response::error('Não foi possível enviar o código. Tente novamente.', 500);
}
