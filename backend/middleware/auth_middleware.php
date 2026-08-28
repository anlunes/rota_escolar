<?php
require_once __DIR__ . '/../config/firebase.php';
require_once __DIR__ . '/../helpers/response.php';

class AuthMiddleware {
    private static ?array $currentUser = null;

    public static function require(): array {
        try {
            $headers = apache_request_headers();

            $header =
                $_SERVER['HTTP_AUTHORIZATION']
                ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
                ?? ($headers['Authorization'] ?? '')
                ?? '';
            error_log('AuthMiddleware: Authorization header = ' . substr($header, 0, 50) . '...');
                        
            if (empty($header)) {
                error_log('AuthMiddleware: Authorization header is EMPTY');
                Response::unauthorized('Token de autorização ausente.');
            }
            
            if (strpos($header, 'Bearer ') !== 0) {
                error_log('AuthMiddleware: Header does not start with "Bearer ": ' . $header);
                Response::unauthorized('Token de autorização ausente.');
            }

            $token = substr($header, 7);
            
            // DEBUG: log token details
            error_log('AuthMiddleware: token length = ' . strlen($token));
            error_log('AuthMiddleware: token prefix = ' . substr($token, 0, 20));
            
            $payload = FirebaseAuth::verifyToken($token);

            if (!$payload) {
                error_log('AuthMiddleware: Token verification returned null');
                Response::unauthorized('Token inválido ou expirado.');
            }

            error_log('AuthMiddleware: Token verified successfully, payload = ' . json_encode($payload));
            self::$currentUser = $payload;
            return $payload;
        } catch (Exception $e) {
            error_log('AuthMiddleware error: ' . $e->getMessage());
            error_log('AuthMiddleware stack: ' . $e->getTraceAsString());
            Response::error('Auth middleware error: ' . $e->getMessage(), 500);
        }
    }

    public static function currentUser(): ?array {
        return self::$currentUser;
    }
}
