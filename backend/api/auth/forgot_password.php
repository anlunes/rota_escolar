<?php
/**
 * POST /api/auth/forgot_password.php
 * Body JSON: { "email": "usuario@email.com" }
 *
 * Gera código de 6 dígitos, salva no banco com expiração de 10 min
 * e envia por e-mail pelo servidor de hospedagem.
 * Sempre retorna sucesso para não revelar se o e-mail existe.
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

if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::error('E-mail inválido.', 400);
}

try {
    $pdo = Database::getInstance();

    // Verifica se e-mail existe (sem revelar ao cliente)
    $stmt = $pdo->prepare("SELECT uid FROM usuarios WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user) {
        // Remove códigos anteriores deste e-mail
        $pdo->prepare("DELETE FROM password_reset_codes WHERE email = ?")->execute([$email]);

        // Gera código de 6 dígitos
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        // Salva no banco com expiração de 10 minutos
        $ins = $pdo->prepare(
            "INSERT INTO password_reset_codes (email, code, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))"
        );
        $ins->execute([$email, $code]);

        // Envia e-mail com o código
        $subject  = '=?UTF-8?B?' . base64_encode('Código de redefinição de senha — Rota Escolar') . '?=';
        $mensagem =
            "Olá!\n\n" .
            "Recebemos uma solicitação para redefinir a senha da sua conta no Rota Escolar.\n\n" .
            "Use o código abaixo no aplicativo para criar uma nova senha:\n\n" .
            "        $code\n\n" .
            "O código é válido por 10 minutos.\n\n" .
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
        error_log("[forgot_password] Código gerado. Email " . ($enviado ? 'enviado' : 'FALHOU') . " para $email");
    } else {
        error_log("[forgot_password] Email não encontrado: $email");
    }

    Response::success([], 'Se este e-mail estiver cadastrado, você receberá um código em breve.');

} catch (Exception $e) {
    error_log("[forgot_password] Erro: " . $e->getMessage());
    Response::error('Não foi possível processar a solicitação. Tente novamente.', 500);
}
