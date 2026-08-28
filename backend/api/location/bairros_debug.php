<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$info = [
    'php_version' => PHP_VERSION,
    'timestamp'   => date('Y-m-d H:i:s'),
];

if (function_exists('opcache_reset')) {
    opcache_reset();
    $info['opcache_reset'] = true;
} else {
    $info['opcache_reset'] = false;
}

$bc = __DIR__ . '/bairros_create.php';
$rp = realpath(__DIR__ . '/../../helpers/response.php');

$info['bairros_create_exists'] = file_exists($bc);
$info['response_real_path']    = $rp ?: 'NAO_RESOLVIDO';

if (file_exists($bc)) {
    $info['bairros_create_mtime'] = date('Y-m-d H:i:s', filemtime($bc));
    $lines = file($bc);
    $info['bairros_create_total_lines']  = count($lines);
    $info['bairros_create_line1']        = isset($lines[0])  ? trim($lines[0])  : 'N/A';
    $info['bairros_create_line18']       = isset($lines[17]) ? trim($lines[17]) : 'N/A';
    $content = file_get_contents($bc);
    $info['bairros_create_has_jsonOk']   = strpos($content, 'function jsonOk')   !== false;
    $info['bairros_create_has_Response'] = strpos($content, 'Response::success') !== false;
}

if ($rp && file_exists($rp)) {
    $info['response_mtime'] = date('Y-m-d H:i:s', filemtime($rp));
    $lines = file($rp);
    $info['response_line9']  = isset($lines[8]) ? trim($lines[8]) : 'N/A';
    $content = file_get_contents($rp);
    $info['response_has_mixed_typehint'] = (bool) preg_match('/function\s+success\s*\(\s*mixed/', $content);
}

$candidates = [
    __DIR__ . '/response.php',
    __DIR__ . '/../response.php',
    __DIR__ . '/../../response.php',
    ($_SERVER['DOCUMENT_ROOT'] ?? '') . '/helpers/response.php',
];
$found = [];
foreach ($candidates as $c) {
    if (file_exists($c)) $found[] = realpath($c);
}
$info['other_response_candidates'] = $found;
$info['auto_prepend_file'] = ini_get('auto_prepend_file') ?: '(nenhum)';

echo json_encode($info, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
