<?php
$host = 'localhost';
$user = 'balcao2p_user_eu';
$pass = 'Mysql26@';
$dbname = 'balcao2p_vanpro';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $results = [];
    
    // 1. SHOW TABLES
    $stmt = $pdo->query("SHOW TABLES");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    $results['SHOW TABLES'] = $tables;
    
    // 2. DESCRIBE financeiro
    $stmt = $pdo->query("DESCRIBE financeiro");
    $financeiro = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $results['DESCRIBE financeiro'] = $financeiro;
    
    // 3. DESCRIBE alunos
    $stmt = $pdo->query("DESCRIBE alunos");
    $alunos = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $results['DESCRIBE alunos'] = $alunos;
    
    // 4. DESCRIBE motoristas
    $stmt = $pdo->query("DESCRIBE motoristas");
    $motoristas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $results['DESCRIBE motoristas'] = $motoristas;
    
    // 5. DESCRIBE responsaveis
    $stmt = $pdo->query("DESCRIBE responsaveis");
    $responsaveis = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $results['DESCRIBE responsaveis'] = $responsaveis;
    
    echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
} catch (PDOException $e) {
    echo json_encode(['error' => $e->getMessage()]);
    exit(1);
}
?>
