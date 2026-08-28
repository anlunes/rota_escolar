<?php
/**
 * Script de diagnóstico - colar no terminal do servidor via SSH
 * Salve como /home/balcao2p/public_html/api.balcao2ponto0.com.br/api/diagnostico.php
 * Acesse: https://api.balcao2ponto0.com.br/api/diagnostico.php
 */

header('Content-Type: text/plain; charset=utf-8');

echo "=== DIAGNÓSTICO ROTA ESCOLAR ===\n\n";

// 1. Verifica se arquivos existem
$files = [
    'routes/index.php',
    'upload/foto.php',
    'upload/cnh.php',
    'students/index.php',
    'financial/index.php',
];

echo "1. ARQUIVOS EXISTEM:\n";
foreach ($files as $f) {
    $path = __DIR__ . '/' . $f;
    echo "  " . ($f) . ": " . (file_exists($path) ? 'SIM' : 'NÃO') . "\n";
}

// 2. Testa conexão com banco
echo "\n2. CONEXÃO COM BANCO:\n";
try {
    require_once __DIR__ . '/../config/database.php';
    $pdo = Database::getInstance();
    echo "  OK - Conectou\n";
    
    // Testa DESCRIBE das tabelas principais
    $tables = ['usuarios', 'motoristas', 'responsaveis', 'alunos', 'escolas', 'mensalidades', 'avaliacoes', 'rota_dias', 'rota_dia_alunos'];
    foreach ($tables as $t) {
        try {
            $stmt = $pdo->query("DESCRIBE $t");
            $cols = $stmt->fetchAll(PDO::FETCH_COLUMN);
            echo "  $t: " . implode(', ', array_slice($cols, 0, 5)) . "...\n";
        } catch (Exception $e) {
            echo "  $t: ERRO - " . $e->getMessage() . "\n";
        }
    }
} catch (Exception $e) {
    echo "  ERRO: " . $e->getMessage() . "\n";
}

// 3. Testa routes/index.php com dados simulados
echo "\n3. TESTE routes/index.php:\n";
try {
    require_once __DIR__ . '/../config/database.php';
    $pdo = Database::getInstance();
    
    // Busca motorista de teste
    $m = $pdo->query("SELECT motorista_id, uid FROM motoristas LIMIT 1")->fetch();
    if ($m) {
        echo "  Motorista encontrado: motorista_id=" . $m['motorista_id'] . ", uid=" . substr($m['uid'], 0, 10) . "...\n";
        
        // Testa query do routes/index.php
        $sql = "
            SELECT rda.id, rda.aluno_id, a.nome AS name, a.endereco AS address,
                   e.nome AS school, rda.status_atual, rda.vai_hoje, rda.talk_requested,
                   r.nome AS guardian_name, r.telefone AS guardian_whatsapp, 0 AS payment_paid, rda.ordem
            FROM rota_dias rd
            JOIN rota_dia_alunos rda ON rda.rota_dia_id = rd.id
            JOIN alunos a ON a.aluno_id = rda.aluno_id
            LEFT JOIN escolas e ON e.escola_id = a.escola_id
            LEFT JOIN responsaveis r ON r.responsavel_id = a.responsavel_id
            WHERE rd.motorista_id = ? AND rd.data_servico = ?
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$m['motorista_id'], date('Y-m-d')]);
        $data = $stmt->fetchAll();
        echo "  Query OK - " . count($data) . " registros encontrados\n";
    } else {
        echo "  Nenhum motorista encontrado\n";
    }
} catch (Exception $e) {
    echo "  ERRO: " . $e->getMessage() . "\n";
    echo "  TRACE: " . $e->getTraceAsString() . "\n";
}

// 4. Verifica diretório de uploads
echo "\n4. DIRETÓRIO UPLOADS:\n";
$uploadDir = __DIR__ . '/../uploads';
echo "  Existe: " . (is_dir($uploadDir) ? 'SIM' : 'NÃO') . "\n";
echo "  Escrita: " . (is_writable($uploadDir) ? 'SIM' : 'NÃO') . "\n";

// 5. Verifica extensões PHP
echo "\n5. EXTENSÕES PHP:\n";
echo "  GD: " . (extension_loaded('gd') ? 'SIM' : 'NÃO') . "\n";
echo "  PDO: " . (extension_loaded('pdo') ? 'SIM' : 'NÃO') . "\n";
echo "  PDO_MySQL: " . (extension_loaded('pdo_mysql') ? 'SIM' : 'NÃO') . "\n";

echo "\n=== FIM DO DIAGNÓSTICO ===\n";
