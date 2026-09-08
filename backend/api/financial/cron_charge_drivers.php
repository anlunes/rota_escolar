<?php
/**
 * GET /api/financial/cron_charge_drivers.php?key=SECRET
 *
 * Roda no dia 10 de cada mês via cron do servidor.
 * Para cada motorista com taxas pendentes do mês anterior,
 * gera UMA cobrança PIX consolidada no Asaas.
 *
 * Cron sugerido (cPanel): 0 8 10 * * /usr/bin/php /path/to/cron_charge_drivers.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../helpers/response.php';
require_once __DIR__ . '/../../helpers/asaas_helper.php';

header('Content-Type: application/json');

// Proteção por chave estática — mesma do webhook
$cronKey = getenv('CRON_SECRET') ?: 'rota2026cron';
if (($_GET['key'] ?? '') !== $cronKey) {
    http_response_code(403);
    echo json_encode(['error' => 'Forbidden']);
    exit;
}

// Mês de referência: mês anterior
$agora    = new DateTime();
$refDate  = (clone $agora)->modify('first day of last month');
$mesCob   = (int)$refDate->format('n');
$anoCob   = (int)$refDate->format('Y');

// Vencimento: dia 10 do mês atual
$vencimento = $agora->format('Y-m') . '-10';

try {
    $pdo = Database::getInstance();

    // Motoristas com taxas pendentes do mês anterior
    $stmt = $pdo->prepare("
        SELECT tp.motorista_id, SUM(tp.taxa) AS total_taxa
        FROM taxa_plataforma tp
        WHERE tp.mes = ? AND tp.ano = ? AND tp.status = 'pendente'
        GROUP BY tp.motorista_id
        HAVING total_taxa > 0
    ");
    $stmt->execute([$mesCob, $anoCob]);
    $motoristas = $stmt->fetchAll();

    $resultados = [];
    $meses = ['','Janeiro','Fevereiro','Março','Abril','Maio','Junho',
              'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    $mesLabel = $meses[$mesCob] . '/' . $anoCob;

    foreach ($motoristas as $row) {
        $motoristaId = (int)$row['motorista_id'];
        $totalTaxa   = round((float)$row['total_taxa'], 2);

        try {
            // Cria/recupera cliente Asaas do motorista
            $customerId = asaas_get_or_create_driver_customer($pdo, $motoristaId);

            // Cria cobrança UNDEFINED (motorista escolhe PIX/boleto)
            $payment = asaas_create_payment(
                $customerId,
                $totalTaxa,
                $vencimento,
                "Taxa plataforma Rota Escolar – $mesLabel (2% pagamentos em dinheiro)"
                // sem walletId — cobrança vai para a conta mãe
            );

            // Marca as taxas como cobradas
            $pdo->prepare("
                UPDATE taxa_plataforma
                SET status = 'cobrado', asaas_payment_id = ?
                WHERE motorista_id = ? AND mes = ? AND ano = ? AND status = 'pendente'
            ")->execute([$payment['id'], $motoristaId, $mesCob, $anoCob]);

            error_log("[cron_charge_drivers] OK motorista=$motoristaId taxa=R\$$totalTaxa payment={$payment['id']}");
            $resultados[] = [
                'motorista_id'  => $motoristaId,
                'total_taxa'    => $totalTaxa,
                'payment_id'    => $payment['id'],
                'resultado'     => 'cobrado',
            ];

        } catch (Throwable $e) {
            error_log("[cron_charge_drivers] ERRO motorista=$motoristaId: " . $e->getMessage());
            $resultados[] = [
                'motorista_id' => $motoristaId,
                'resultado'    => 'erro',
                'erro'         => $e->getMessage(),
            ];
        }
    }

    $cobrados = count(array_filter($resultados, fn($r) => $r['resultado'] === 'cobrado'));
    Response::success($resultados, "Taxas processadas: $cobrados motorista(s) cobrado(s).");

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}
