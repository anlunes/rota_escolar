<?php
/**
 * Firebase Admin SDK — autenticação via service account.
 * Gera access tokens e links administrativos sem depender do Admin SDK PHP.
 */
class FirebaseAdmin {
    private static ?string $cachedToken = null;
    private static int $tokenExpiry = 0;

    private static function base64UrlEncode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function loadServiceAccount(): array {
        $path = __DIR__ . '/service_account.json';
        if (!file_exists($path)) {
            throw new Exception('service_account.json não encontrado em backend/config/');
        }
        return json_decode(file_get_contents($path), true);
    }

    /**
     * Obtém (ou reutiliza) um access token OAuth2 via service account JWT.
     */
    public static function getAccessToken(): string {
        if (self::$cachedToken && time() < self::$tokenExpiry - 60) {
            return self::$cachedToken;
        }

        $sa  = self::loadServiceAccount();
        $now = time();

        $header  = self::base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $payload = self::base64UrlEncode(json_encode([
            'iss' => $sa['client_email'],
            'sub' => $sa['client_email'],
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
            'scope' => 'https://www.googleapis.com/auth/firebase https://www.googleapis.com/auth/cloud-platform',
        ]));

        $signingInput = "$header.$payload";
        openssl_sign($signingInput, $signature, $sa['private_key'], OPENSSL_ALGO_SHA256);
        $jwt = "$header.$payload." . self::base64UrlEncode($signature);

        $ch = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt_array($ch, [
            CURLOPT_POST            => true,
            CURLOPT_RETURNTRANSFER  => true,
            CURLOPT_TIMEOUT         => 10,
            CURLOPT_HTTPHEADER      => ['Content-Type: application/x-www-form-urlencoded'],
            CURLOPT_POSTFIELDS      => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => $jwt,
            ]),
        ]);
        $response = curl_exec($ch);
        curl_close($ch);

        $data = json_decode($response, true);
        if (empty($data['access_token'])) {
            throw new Exception('Falha ao obter access token: ' . $response);
        }

        self::$cachedToken = $data['access_token'];
        self::$tokenExpiry = $now + ($data['expires_in'] ?? 3600);

        return self::$cachedToken;
    }

    /**
     * Gera um link de verificação de e-mail sem enviar pelo Firebase.
     * Retorna a URL completa do link de verificação.
     */
    public static function generateEmailVerificationLink(string $email): string {
        $token     = self::getAccessToken();
        $sa        = self::loadServiceAccount();
        $projectId = $sa['project_id'];

        $ch = curl_init("https://identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:sendOobCode");
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                "Authorization: Bearer $token",
            ],
            CURLOPT_POSTFIELDS     => json_encode([
                'requestType'   => 'VERIFY_EMAIL',
                'email'         => $email,
                'returnOobLink' => true,
                'languageCode'  => 'pt-BR',
            ]),
        ]);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $data = json_decode($response, true);

        if ($httpCode !== 200 || empty($data['oobLink'])) {
            $msg = $data['error']['message'] ?? $response;
            error_log("[FirebaseAdmin] generateEmailVerificationLink error ($httpCode): $msg");
            throw new Exception($msg);
        }

        return $data['oobLink'];
    }

    /**
     * Gera um link de redefinição de senha sem enviar e-mail pelo Firebase.
     * Retorna a URL completa do link de reset.
     */
    public static function generatePasswordResetLink(string $email): string {
        $token     = self::getAccessToken();
        $sa        = self::loadServiceAccount();
        $projectId = $sa['project_id'];

        $ch = curl_init("https://identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:sendOobCode");
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                "Authorization: Bearer $token",
            ],
            CURLOPT_POSTFIELDS     => json_encode([
                'requestType'   => 'PASSWORD_RESET',
                'email'         => $email,
                'returnOobLink' => true,
                'languageCode'  => 'pt-BR',
            ]),
        ]);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $data = json_decode($response, true);

        if ($httpCode !== 200 || empty($data['oobLink'])) {
            $msg = $data['error']['message'] ?? $response;
            error_log("[FirebaseAdmin] generatePasswordResetLink error ($httpCode): $msg");
            throw new Exception($msg);
        }

        return $data['oobLink'];
    }

    /**
     * Atualiza a senha de um usuário diretamente via Admin SDK.
     */
    public static function updateUserPassword(string $uid, string $newPassword): void {
        $token = self::getAccessToken();

        // Endpoint correto para Identity Toolkit v1 com OAuth2 Bearer (admin)
        $ch = curl_init("https://identitytoolkit.googleapis.com/v1/accounts:update");
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                "Authorization: Bearer $token",
            ],
            CURLOPT_POSTFIELDS => json_encode([
                'localId'  => $uid,
                'password' => $newPassword,
            ]),
        ]);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $data = json_decode($response, true);
        error_log("[FirebaseAdmin] updateUserPassword HTTP $httpCode uid=$uid response=" . substr($response, 0, 300));

        if ($httpCode !== 200 || empty($data['localId'])) {
            $msg = $data['error']['message'] ?? "HTTP $httpCode: $response";
            throw new Exception($msg);
        }
    }
}
