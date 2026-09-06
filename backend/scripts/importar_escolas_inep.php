<?php
/**
 * importar_escolas_inep.php
 * =========================
 * Importa escolas do Censo Escolar INEP 2025 para a tabela `escolas`.
 *
 * - Importa TODOS os estados do Brasil
 * - Ignora escolas já existentes (pelo código INEP)
 * - Marca todas como status = 'verificado' (existem no INEP, sem coordenadas)
 *
 * Uso via terminal:
 *   php importar_escolas_inep.php
 *   php importar_escolas_inep.php --dry-run
 */

require_once __DIR__ . '/../config/database.php';

$dryRun  = in_array('--dry-run', $argv ?? []);
$arquivo = __DIR__ . '/../tabelas_escolas/Escolas_RJ_2025_V2.csv';

if (!file_exists($arquivo)) {
    die("Arquivo não encontrado: {$arquivo}\n");
}

$pdo = Database::getInstance();

// Garante coluna inep_codigo
try {
    $pdo->exec("ALTER TABLE escolas ADD COLUMN inep_codigo BIGINT UNSIGNED DEFAULT NULL UNIQUE AFTER escola_id");
    echo "Coluna inep_codigo adicionada.\n";
} catch (PDOException $e) {
    // Já existe — ok
}

$handle = fopen($arquivo, 'r');
stream_filter_append($handle, 'convert.iconv.ISO-8859-1/UTF-8');
$cabecalho = fgetcsv($handle, 0, ';');
$idx       = array_flip(array_map('trim', $cabecalho));

$inseridos = 0;
$ignorados = 0;

echo "\n=== Importando escolas INEP 2025 — Brasil todo" . ($dryRun ? ' [DRY RUN]' : '') . " ===\n";

$stmt = $pdo->prepare("
    INSERT IGNORE INTO escolas (inep_codigo, nome, municipio, estado, status)
    VALUES (?, ?, ?, ?, 'verificado')
");

while (($row = fgetcsv($handle, 0, ';')) !== false) {
    $uf        = trim($row[$idx['SG_UF']]        ?? '');
    $nome      = trim($row[$idx['NO_ENTIDADE']]  ?? '');
    $municipio = trim($row[$idx['NO_MUNICIPIO']] ?? '');
    $inepCod   = trim($row[$idx['CO_ENTIDADE']]  ?? '');

    if (empty($nome) || empty($inepCod) || empty($uf)) {
        $ignorados++;
        continue;
    }

    $nome = mb_convert_case(mb_strtolower($nome), MB_CASE_TITLE, 'UTF-8');

    if (!$dryRun) {
        $stmt->execute([$inepCod, $nome, $municipio, $uf]);
        if ($stmt->rowCount() > 0) {
            $inseridos++;
        } else {
            $ignorados++;
        }
    } else {
        echo "  [{$uf}] [{$inepCod}] {$nome} / {$municipio}\n";
        $inseridos++;
        if ($inseridos >= 10) {
            echo "  ... (mostrando só 10 no dry-run)\n";
            break;
        }
    }
}

fclose($handle);

echo "\n=== Resultado ===\n";
echo "  Inseridas: {$inseridos}\n";
echo "  Ignoradas: {$ignorados} (já existiam)\n\n";

if ($dryRun) echo "[DRY RUN] Nada foi salvo no banco.\n\n";
