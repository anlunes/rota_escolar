<?php
/**
 * POST /api/auth/verify_email.php
 * Body JSON: { "email": "usuario@email.com", "code": "123456" }
 *
 * Valida o código de 6 dígitos enviado no cadastro.
 * Se correto, marca o e-mail como verificado no Firebase Auth via Admin SDK.
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
$code  = trim($body['code']  ?? '');

if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::error('E-mail inválido.', 400);
}
if (!$code || strlen($code) !== 6 || !ctype_digit($code)) {
    Response::error('Código inválido.', 400);
}

try {
    $pdo = Database::getInstance();

    // Valida código
    $stmt = $pdo->prepare(
        "SELECT id FROM email_verification_codes
         WHERE email = ? AND code = ? AND expires_at > NOW()
         LIMIT 1"
    );
    $stmt->execute([$email, $code]);
    $row = $stmt->fetch();

    if (!$row) {
        Response::error('Código inválido ou expirado. Solicite um novo código.', 422);
    }

    // Busca uid — primeiro no banco, fallback no Firebase Admin
    $uid = null;
    $userStmt = $pdo->prepare("SELECT uid FROM usuarios WHERE email = ? LIMIT 1");
    $userStmt->execute([$email]);
    $user = $userStmt->fetch();
    if ($user && !empty($user['uid'])) {
        $uid = $user['uid'];
    } else {
        $uid = FirebaseAdmin::getUserUidByEmail($email);
    }

    if (!$uid) {
        Response::error('Usuário não encontrado.', 404);
    }

    // Marca e-mail como verificado no Firebase Auth
    FirebaseAdmin::markEmailVerified($uid);

    // Remove o código usado
    $pdo->prepare("DELETE FROM email_verification_codes WHERE id = ?")->execute([$row['id']]);

    error_log("[verify_email] E-mail verificado para $email (uid={$user['uid']})");

    Response::success([], 'E-mail verificado com sucesso. Faça login para continuar.');

} catch (Exception $e) {
    error_log("[verify_email] Erro: " . $e->getMessage());
    Response::error('Não foi possível verificar o e-mail. Tente novamente.', 500);
}
