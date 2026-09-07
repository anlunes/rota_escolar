<?php
/**
 * POST /api/financial/webhook.php
 *
 * Recebe notificações do Asaas e atualiza o status das mensalidades.
 * Configurar em: Asaas → Configurações → Notificações → URL do webhook
 *
 * Eventos tratados:
 *   PAYMENT_RECEIVED / PAYMENT_CONFIRMED → pago via Asaas
 *   PAYMENT_OVERDUE                      → atrasado
 *   PAYMENT_DELETED / PAYMENT_REFUNDED   → cancelado
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');

// Asaas pode enviar OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST')   { http_response_code(405); exit; }

$raw     = file_get_contents('php://input');
$payload = json_decode($raw, true);

$event     = $payload['event']        ?? '';
$paymentId = $payload['payment']['id'] ?? '';

// Ignora eventos sem ID de pagamento
if (!$paymentId) { http_response_code(200); echo json_encode(['ok' => true]); exit; }

try {
    $pdo = Database::getInstance();

    if (in_array($event, ['PAYMENT_RECEIVED', 'PAYMENT_CONFIRMED'])) {
        $pdo->prepare("
            UPDATE mensalidades
            SET status = 'pago', forma_pagamento = 'asaas',
                data_pagamento = CURDATE(), updated_at = NOW()
            WHERE asaas_payment_id = ? AND status != 'pago'
        ")->execute([$paymentId]);

    } elseif ($event === 'PAYMENT_OVERDUE') {
        $pdo->prepare("
            UPDATE mensalidades
            SET status = 'atrasado', updated_at = NOW()
            WHERE asaas_payment_id = ? AND status = 'pendente'
        ")->execute([$paymentId]);

    } elseif (in_array($event, ['PAYMENT_DELETED', 'PAYMENT_REFUNDED'])) {
        $pdo->prepare("
            UPDATE mensalidades
            SET status = 'cancelado', updated_at = NOW()
            WHERE asaas_payment_id = ? AND status != 'pago'
        ")->execute([$paymentId]);
    }

    // Sempre responde 200 para o Asaas parar de reenviar
    http_response_code(200);
    echo json_encode(['received' => true, 'event' => $event]);

} catch (Throwable $e) {
    error_log('[webhook/asaas] ' . $e->getMessage());
    http_response_code(200); // ainda 200 para não reenviar
    echo json_encode(['received' => true]);
}
