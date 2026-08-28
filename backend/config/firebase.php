<?php
/**
 * Firebase token verification via Google's public keys.
 * Validates RS256 JWT without requiring the Firebase Admin SDK.
 */
class FirebaseAuth {
    private const PROJECT_ID = 'rota-escolar-6085e';
    private const CERTS_URL  = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

    /**
     * Verify a Firebase ID token and return the decoded payload.
     * Returns null if invalid.
     */
    public static function verifyToken(string $token): ?array {
        error_log('FirebaseAuth: Starting token verification');
        
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            error_log('FirebaseAuth: Invalid token format - parts count = ' . count($parts));
            return null;
        }

        [$headerB64, $payloadB64, $sigB64] = $parts;
        error_log('FirebaseAuth: Token has 3 parts');

        // Decode payload
        $payload = json_decode(self::base64UrlDecode($payloadB64), true);
        if (!$payload) {
            error_log('FirebaseAuth: Failed to decode payload');
            return null;
        }
        error_log('FirebaseAuth: Payload decoded = ' . json_encode($payload));

        // Basic claim checks
        $now = time();
        if (($payload['exp'] ?? 0) < $now) {
            error_log('FirebaseAuth: Token expired. exp=' . ($payload['exp'] ?? 0) . ', now=' . $now);
            return null;
        }
        if (($payload['iat'] ?? 0) > $now + 300) {
            error_log('FirebaseAuth: Token from future. iat=' . ($payload['iat'] ?? 0) . ', now=' . $now);
            return null;
        }
        if (($payload['aud'] ?? '') !== self::PROJECT_ID) {
            error_log('FirebaseAuth: Invalid aud. expected=' . self::PROJECT_ID . ', got=' . ($payload['aud'] ?? ''));
            return null;
        }
        if (strpos($payload['iss'] ?? '', 'https://securetoken.google.com/') !== 0) {
            error_log('FirebaseAuth: Invalid iss. got=' . ($payload['iss'] ?? ''));
            return null;
        }
        if (empty($payload['sub'])) {
            error_log('FirebaseAuth: Empty sub');
            return null;
        }
        error_log('FirebaseAuth: All claims valid');

        // Signature verification
        $header = json_decode(self::base64UrlDecode($headerB64), true);
        $kid = $header['kid'] ?? null;
        if (!$kid) {
            error_log('FirebaseAuth: No kid in header');
            return null;
        }
        error_log('FirebaseAuth: kid = ' . $kid);

        $certs = self::getPublicKeys();
        if (empty($certs)) {
            error_log('FirebaseAuth: No certificates fetched');
            return null;
        }
        error_log('FirebaseAuth: Certs fetched, count = ' . count($certs));
        
        if (!isset($certs[$kid])) {
            error_log('FirebaseAuth: Kid not found in certs. kid=' . $kid . ', available kids=' . implode(',', array_keys($certs)));
            return null;
        }

        $pubKey = openssl_get_publickey($certs[$kid]);
        if (!$pubKey) {
            error_log('FirebaseAuth: Failed to get public key');
            return null;
        }

        $data      = "$headerB64.$payloadB64";
        $signature = self::base64UrlDecode($sigB64);
        $valid     = openssl_verify($data, $signature, $pubKey, OPENSSL_ALGO_SHA256);
        
        error_log('FirebaseAuth: Signature verification result = ' . $valid);

        return $valid === 1 ? $payload : null;
    }

    private static function getPublicKeys(): array {
        $cacheFile = sys_get_temp_dir() . '/firebase_certs.json';
        $cacheTime = 3600;

        if (file_exists($cacheFile) && (time() - filemtime($cacheFile)) < $cacheTime) {
            return json_decode(file_get_contents($cacheFile), true) ?? [];
        }

        $ctx  = stream_context_create(['http' => ['timeout' => 5]]);
        $data = @file_get_contents(self::CERTS_URL, false, $ctx);
        if (!$data) return [];

        file_put_contents($cacheFile, $data);
        return json_decode($data, true) ?? [];
    }

    private static function base64UrlDecode(string $input): string {
        $remainder = strlen($input) % 4;
        if ($remainder) $input .= str_repeat('=', 4 - $remainder);
        return base64_decode(strtr($input, '-_', '+/'));
    }
}
