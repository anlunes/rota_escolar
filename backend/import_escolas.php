<?php
/**
 * Script de importação única de escolas do Rio de Janeiro.
 * 1. Coloque este arquivo em backend/
 * 2. Coloque o CSV em backend/escolas_rj.csv (UTF-8, separador vírgula)
 *    Colunas: Nome da Escola | CEP | Endereço | Nível de Ensino
 * 3. Acesse: https://rotaescolar.app.br/import_escolas.php?key=rota2026
 * 4. Após importar, DELETE este arquivo do servidor.
 */

// Chave simples de segurança
if (($_GET['key'] ?? '') !== 'rota2026') {
    http_response_code(403);
    die('Acesso negado.');
}

require_once __DIR__ . '/config/database.php';

$csvFile = __DIR__ . '/escolas_rj.csv';
if (!file_exists($csvFile)) {
    die('Arquivo escolas_rj.csv não encontrado em ' . $csvFile);
}

$pdo = Database::getInstance();

$handle = fopen($csvFile, 'r');
// Lê e descarta o header
$header = fgetcsv($handle, 0, ',');

$inserted = 0;
$skipped  = 0;
$errors   = [];

while (($row = fgetcsv($handle, 0, ',')) !== false) {
    if (count($row) < 3) { $skipped++; continue; }

    $nome     = trim($row[0]);
    $cepRaw   = trim($row[1]);
    $endereco = trim($row[2]);
    // $nivelEnsino = $row[3] → não mapeado (campo não existe na tabela)

    if (!$nome) { $skipped++; continue; }

    // Formata CEP: remove não-dígitos
    $cep = preg_replace('/\D/', '', $cepRaw);
    if (strlen($cep) === 8) {
        $cep = substr($cep, 0, 5) . '-' . substr($cep, 5);
    }

    // Parse do endereço: "Rua Dom Gerardo, 68 - Centro"
    // Split pelo último " - " para separar bairro
    $logradouro = '';
    $numero     = '';
    $bairro     = '';

    $dashPos = strrpos($endereco, ' - ');
    if ($dashPos !== false) {
        $bairro      = trim(substr($endereco, $dashPos + 3));
        $logNumero   = trim(substr($endereco, 0, $dashPos));
    } else {
        $logNumero = $endereco;
    }

    // Separa logradouro do número: split pela última vírgula
    $commaPos = strrpos($logNumero, ', ');
    if ($commaPos !== false) {
        $logradouro = trim(substr($logNumero, 0, $commaPos));
        $numero     = trim(substr($logNumero, $commaPos + 2));
        // Se o que ficou depois da vírgula não parece número, trata como parte do logradouro
        if (!preg_match('/^\d/', $numero)) {
            $logradouro = $logNumero;
            $numero     = '';
        }
    } else {
        $logradouro = $logNumero;
    }

    try {
        // Evita duplicatas por nome
        $chk = $pdo->prepare("SELECT escola_id FROM escolas WHERE LOWER(nome) = LOWER(?) LIMIT 1");
        $chk->execute([$nome]);
        if ($chk->fetchColumn()) { $skipped++; continue; }

        $stmt = $pdo->prepare("
            INSERT INTO escolas
                (nome, cep, logradouro, numero, bairro, municipio, estado, aprovado, status, created_at, updated_at)
            VALUES
                (?, ?, ?, ?, ?, 'Rio de Janeiro', 'RJ', 1, 'ativo', NOW(), NOW())
        ");
        $stmt->execute([$nome, $cep, $logradouro, $numero, $bairro]);
        $inserted++;
    } catch (Throwable $e) {
        $errors[] = "[$nome]: " . $e->getMessage();
    }
}

fclose($handle);

echo "<h2>Importação concluída</h2>";
echo "<p>Inseridas: <strong>$inserted</strong></p>";
echo "<p>Ignoradas (duplicatas/vazias): <strong>$skipped</strong></p>";
if ($errors) {
    echo "<p>Erros:</p><ul>";
    foreach ($errors as $err) echo "<li>$err</li>";
    echo "</ul>";
}
echo "<p style='color:red'><strong>Delete este arquivo do servidor agora!</strong></p>";
