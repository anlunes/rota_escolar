<?php
class Response {
    private static function setCorsHeaders(): void {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    }

    public static function success($data, string $message = 'OK', int $status = 200): void {
        self::setCorsHeaders();
        http_response_code($status);
        header('Content-Type: application/json');
        echo json_encode([
            'success' => true,
            'message' => $message,
            'data'    => $data,
        ]);
        exit;
    }

    public static function error(string $message, int $status = 400, $errors = null): void {
        self::setCorsHeaders();
        http_response_code($status);
        header('Content-Type: application/json');
        $body = [
            'success' => false,
            'message' => $message,
        ];
        if ($errors !== null) $body['errors'] = $errors;
        echo json_encode($body);
        exit;
    }

    public static function unauthorized(string $message = 'Não autorizado.'): void {
        self::error($message, 401);
    }

    public static function notFound(string $message = 'Não encontrado.'): void {
        self::error($message, 404);
    }

    public static function methodNotAllowed(): void {
        self::error('Método não permitido.', 405);
    }
}
