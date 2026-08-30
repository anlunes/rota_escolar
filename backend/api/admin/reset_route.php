<?php
/**
 * POST /api/admin/reset_route.php
 * Zera o ciclo de rota de um motorista (ou todos) em uma data específica.
 *
 * Body JSON:
 *   { "data": "2026-08-30", "motorista_id": 3, "tipo": "ambos" }
 *   motorista_id = 0  → todos os motoristas
 *   tipo = "mysql" | "rtdb" | "ambos"
 *
 * O que faz:
 *   MySQL → UPDATE rota_dia_alunos: status_atual = 'waiting_van', horários = NULL
 *   RTDB  → DELETE studentsRealtime/{aluno_id} para os alunos afetados
 *   Log   → INSERT em rota_resets
 */

date_default_timezone_set('America/Sao_Paulo');

require_once __DIR__ . '/../../config/database.php';

// Tenta usar Database Secret (mais simples e confiável para RTDB REST)
$rtdbSecretFile = __DIR__ . '/../../config/rtdb_secret.php';
if (file_exists($rtdbSecretFile)) {
    require_once $rtdbSecretFile;
} else {
    // Fallback: OAuth2 via service account
    require_once __DIR__ . '/../../config/firebase_admin.php';
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método não permitido.']);
    exit;
}

// Autenticação simples — mesma sessão do admin
session_start();
$configPath = __DIR__ . '/../../admin/config.php';
if (file_exists($configPath)) require_once $configPath;

$sessionKey = defined('ADMIN_SESSION_KEY') ? ADMIN_SESSION_KEY : 'admin_logged_in';
if (empty($_SESSION[$sessionKey])) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Não autorizado.']);
    exit;
}

$body        = json_decode(file_get_contents('php://input'), true) ?? [];
$data        = $body['data']         ?? date('Y-m-d');
$motoristaId = isset($body['motorista_id']) ? (int)$body['motorista_id'] : 0; // 0 = todos
$tipo        = $body['tipo']         ?? 'ambos';
$adminUser   = $_SESSION[$sessionKey] ?? 'admin';

if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $data)) {
    echo json_encode(['success' => false, 'message' => 'Data inválida.']);
    exit;
}

try {
    $pdo = Database::getInstance();
    $alunosAfetados = 0;
    $alunoIds = [];

    // ── 1. Busca alunos afetados ─────────────────────────────────────────────
    if ($motoristaId > 0) {
        $stmt = $pdo->prepare("SELECT aluno_id FROM alunos WHERE motorista_id = ? AND ativo = 1");
        $stmt->execute([$motoristaId]);
    } else {
        $stmt = $pdo->query("SELECT aluno_id FROM alunos WHERE motorista_id IS NOT NULL AND ativo = 1");
    }
    $alunoIds = array_column($stmt->fetchAll(PDO::FETCH_ASSOC), 'aluno_id');
    $alunosAfetados = count($alunoIds);

    // ── 2. Reset MySQL ───────────────────────────────────────────────────────
    if (in_array($tipo, ['mysql', 'ambos'])) {
        if ($motoristaId > 0) {
            // Zera rota_dia_alunos via JOIN com rota_dias do motorista na data
            $pdo->prepare("
                UPDATE rota_dia_alunos rda
                INNER JOIN rota_dias rd ON rd.id = rda.rota_dia_id
                SET rda.status_atual      = 'waiting_van',
                    rda.horario_embarque  = NULL,
                    rda.horario_escola    = NULL,
                    rda.horario_volta     = NULL,
                    rda.horario_casa      = NULL
                WHERE rd.data_servico = ? AND rd.motorista_id = ?
            ")->execute([$data, $motoristaId]);
        } else {
            // Todos os motoristas
            $pdo->prepare("
                UPDATE rota_dia_alunos rda
                INNER JOIN rota_dias rd ON rd.id = rda.rota_dia_id
                SET rda.status_atual      = 'waiting_van',
                    rda.horario_embarque  = NULL,
                    rda.horario_escola    = NULL,
                    rda.horario_volta     = NULL,
                    rda.horario_casa      = NULL
                WHERE rd.data_servico = ?
            ")->execute([$data]);
        }
    }

    // ── 3. Reset RTDB ────────────────────────────────────────────────────────
    // Grava waiting_van no nó de cada aluno → stream onValue dispara no app.
    $rtdbErrors  = [];
    $rtdbDebug   = [];
    $authMethod  = 'none';

    if (in_array($tipo, ['rtdb', 'ambos']) && !empty($alunoIds)) {
        $dbUrl = 'https://rota-escolar-6085e-default-rtdb.firebaseio.com';
        $tsMs  = (int)(microtime(true) * 1000);

        // Autenticação: Database Secret (simples) ou OAuth2 (fallback)
        if (defined('RTDB_SECRET')) {
            $authParam  = '?auth=' . RTDB_SECRET;
            $authHeader = [];
            $authMethod = 'database_secret';
        } else {
            $token      = FirebaseAdmin::getAccessToken();
            $authParam  = '';
            $authHeader = ['Authorization: Bearer ' . $token];
            $authMethod = 'oauth2_bearer';
        }

        $resetPayload = json_encode([
            'currentStatus' => 'waiting_van',
            'motoristaUid'  => null,
            'ts'            => $tsMs,
        ]);

        foreach ($alunoIds as $alunoId) {
            $url = "$dbUrl/studentsRealtime/$alunoId.json$authParam";
            $ch  = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_CUSTOMREQUEST  => 'PUT',
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 10,
                CURLOPT_SSL_VERIFYPEER => false,
                CURLOPT_HTTPHEADER     => array_merge(
                    ['Content-Type: application/json'],
                    $authHeader
                ),
                CURLOPT_POSTFIELDS     => $resetPayload,
            ]);
            $res      = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlErr  = curl_error($ch);
            curl_close($ch);

            $rtdbDebug[] = [
                'aluno_id' => $alunoId,
                'http'     => $httpCode,
                'curl_err' => $curlErr ?: null,
                'response' => $res,
            ];

            if ($httpCode !== 200) {
                $rtdbErrors[] = "aluno $alunoId: HTTP $httpCode / curl: $curlErr / resp: $res";
            }
        }
    }

    // ── 4. Log do reset ──────────────────────────────────────────────────────
    $pdo->prepare("
        INSERT INTO rota_resets (motorista_id, data_servico, tipo, alunos_afetados, admin_user)
        VALUES (?, ?, ?, ?, ?)
    ")->execute([
        $motoristaId > 0 ? $motoristaId : null,
        $data,
        $tipo,
        $alunosAfetados,
        is_string($adminUser) ? $adminUser : 'admin',
    ]);

    echo json_encode([
        'success'            => true,
        'message'            => "Reset concluído. $alunosAfetados aluno(s) afetado(s).",
        'alunos_afetados'    => $alunosAfetados,
        'rtdb_auth_method'   => $authMethod,
        'rtdb_secret_path'   => $rtdbSecretFile,
        'rtdb_secret_found'  => file_exists($rtdbSecretFile),
        'rtdb_errors'        => $rtdbErrors,
        'rtdb_debug'         => $rtdbDebug,
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
