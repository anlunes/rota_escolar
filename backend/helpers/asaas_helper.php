<?php
/**
 * Helper Asaas — funções reutilizáveis para a API do gateway
 */

require_once __DIR__ . '/../config/asaas.php';

// ── HTTP request genérico ────────────────────────────────────────────────────

function asaas_request(string $method, string $endpoint, array $data = []): array
{
    $url = ASAAS_BASE_URL . $endpoint;
    $ch  = curl_init($url);

    $headers = [
        'Content-Type: application/json',
        'access_token: ' . ASAAS_API_KEY,
        'User-Agent: RotaEscolar/1.0',
    ];

    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    } elseif ($method === 'GET' && $data) {
        $url .= '?' . http_build_query($data);
        curl_setopt($ch, CURLOPT_URL, $url);
    }

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $result               = json_decode($response ?: '{}', true) ?? [];
    $result['_http_code'] = $httpCode;
    return $result;
}

function asaas_post(string $endpoint, array $data): array
{
    return asaas_request('POST', $endpoint, $data);
}

function asaas_get(string $endpoint, array $params = []): array
{
    return asaas_request('GET', $endpoint, $params);
}

// ── Clientes ─────────────────────────────────────────────────────────────────

/**
 * Cria (ou recupera do banco) o cliente Asaas do responsável.
 * Persiste asaas_customer_id em responsaveis para não criar duplicatas.
 */
function asaas_get_or_create_customer(
    PDO    $pdo,
    int    $responsavelId,
    string $nome,
    string $email,
    string $telefone = '',
    string $cpf      = ''
): string {
    // Verifica se já existe no banco
    $stmt = $pdo->prepare("SELECT asaas_customer_id FROM responsaveis WHERE responsavel_id = ? AND asaas_customer_id IS NOT NULL LIMIT 1");
    $stmt->execute([$responsavelId]);
    $existing = $stmt->fetchColumn();
    if ($existing) return $existing;

    // Cria no Asaas
    $payload = ['name' => $nome, 'email' => $email, 'notificationDisabled' => false];
    $fone = preg_replace('/\D/', '', $telefone);
    if (strlen($fone) >= 10) $payload['mobilePhone'] = $fone;
    $cpfLimpo = preg_replace('/\D/', '', $cpf);
    if (strlen($cpfLimpo) === 11) $payload['cpfCnpj'] = $cpfLimpo;

    $result     = asaas_post('/customers', $payload);
    $customerId = $result['id'] ?? null;

    if (!$customerId) {
        $erro = $result['errors'][0]['description'] ?? json_encode($result);
        throw new RuntimeException("Falha ao criar cliente Asaas: $erro");
    }

    // Persiste
    $pdo->prepare("UPDATE responsaveis SET asaas_customer_id = ? WHERE responsavel_id = ?")
        ->execute([$customerId, $responsavelId]);

    return $customerId;
}

// ── Pagamentos ───────────────────────────────────────────────────────────────

/**
 * Cria uma cobrança Asaas com tipo UNDEFINED (responsável escolhe PIX/boleto/cartão).
 * Retorna ['id' => ..., 'invoiceUrl' => ...] ou lança exceção.
 */
function asaas_create_payment(
    string $customerId,
    float  $valor,
    string $vencimento, // YYYY-MM-DD
    string $descricao
): array {
    $result = asaas_post('/payments', [
        'customer'    => $customerId,
        'billingType' => 'UNDEFINED',
        'value'       => round($valor, 2),
        'dueDate'     => $vencimento,
        'description' => $descricao,
    ]);

    if (empty($result['id'])) {
        $erro = $result['errors'][0]['description'] ?? json_encode($result);
        throw new RuntimeException("Falha ao criar cobrança Asaas: $erro");
    }

    return [
        'id'         => $result['id'],
        'invoiceUrl' => $result['invoiceUrl'] ?? null,
        'status'     => $result['status']     ?? 'PENDING',
    ];
}
