<?php
/**
 * POST /api/auth/forgot_password.php
 * Body JSON: { "email": "usuario@email.com" }
 *
 * Gera link de reset via Firebase Admin e envia pelo servidor de hospedagem.
 * Sempre retorna sucesso para não revelar se o e-mail existe.
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

$body  = json_decode(file_get_contents('php://input'), true) ?? [];
$email = trim($body['email'] ?? '');

if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::error('E-mail inválido.', 400);
}

try {
    // Verifica se e-mail existe no banco (sem revelar ao cliente)
    $pdo  = Database::getInstance();
    $stmt = $pdo->prepare("SELECT uid FROM usuarios WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user) {
        // Gera link via Firebase Admin (sem Firebase enviar o email)
        $resetLink = FirebaseAdmin::generatePasswordResetLink($email);

        // Envia pelo servidor de hospedagem
        $subject = '=?UTF-8?B?' . base64_encode('Redefinição de senha — Rota Escolar') . '?=';
        $mensagem =
            "Olá!\n\n" .
            "Recebemos uma solicitação para redefinir a senha da sua conta no Rota Escolar.\n\n" .
            "Clique no link abaixo para criar uma nova senha:\n\n" .
            $resetLink . "\n\n" .
            "O link expira em 1 hora.\n\n" .
            "Se você não solicitou a redefinição, ignore este e-mail — sua senha permanece a mesma.\n\n" .
            "Equipe Rota Escolar\n" .
            "https://rotaescolar.app.br";

        $headers = implode("\r\n", [
            'From: Rota Escolar <noreply@rotaescolar.app.br>',
            'Reply-To: noreply@rotaescolar.app.br',
            'MIME-Version: 1.0',
            'Content-Type: text/plain; charset=UTF-8',
        ]);

        $enviado = mail($email, $subject, $mensagem, $headers);
        error_log("[forgot_password] Email " . ($enviado ? 'enviado' : 'FALHOU') . " para $email");
    } else {
        error_log("[forgot_password] Email não encontrado: $email");
    }

    // Sempre retorna sucesso
    Response::success([], 'Se este e-mail estiver cadastrado, você receberá as instruções em breve.');

} catch (Exception $e) {
    error_log("[forgot_password] Erro: " . $e->getMessage());
    Response::error('Não foi possível processar a solicitação. Tente novamente.', 500);
}
