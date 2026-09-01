<?php
/**
 * POST /api/auth/send_verification.php
 * Body JSON: { "email": "usuario@email.com" }
 *
 * Gera link de verificação via Firebase Admin e envia pelo servidor de hospedagem.
 * Chamado logo após o cadastro, antes de deslogar o usuário do Firebase.
 */

require_once __DIR__ . '/../../config/firebase_admin.php';
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
    $verificationLink = FirebaseAdmin::generateEmailVerificationLink($email);
    $verificationLink = preg_replace('/([&?])lang=[^&]*/i', '$1', $verificationLink);
    $verificationLink = rtrim($verificationLink, '?&');

    $subject = '=?UTF-8?B?' . base64_encode('Confirme seu e-mail — Rota Escolar') . '?=';
    $mensagem =
        "Olá, $nome!\n\n" .
        "Obrigado por se cadastrar no Rota Escolar.\n\n" .
        "Clique no link abaixo para confirmar seu e-mail e ativar sua conta:\n\n" .
        $verificationLink . "\n\n" .
        "O link expira em 24 horas.\n\n" .
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

    Response::success([], 'E-mail de verificação enviado.');

} catch (Exception $e) {
    error_log("[send_verification] Erro: " . $e->getMessage());
    Response::error('Não foi possível enviar o e-mail de verificação. Tente novamente.', 500);
}
