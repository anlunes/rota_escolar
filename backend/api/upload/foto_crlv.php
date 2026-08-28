<?php
/**
 * POST /api/upload/foto_crlv.php
 *
 * Campos multipart/form-data:
 *   referencia     motorista | aluno
 *   referencia_id  uid (motorista) ou id numérico (aluno)
 *   tipo           crlv
 *   arquivo        arquivo de imagem (jpg, jpeg, png, webp, pdf) – máx 10 MB
 *
 * Retorna JSON { success, url, crlv_exercicio } ou { success: false, error }
 *
 * Pré-requisito banco:
 *   ALTER TABLE motoristas ADD COLUMN crlv_exercicio YEAR DEFAULT NULL;
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/firebase.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

define('OCR_SPACE_API_KEY', 'K88171630188957');

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed();
}

// Verifica token Firebase
$payload = AuthMiddleware::require();
$uid     = $payload['sub'] ?? $payload['user_id'] ?? null;

// --- Validação dos campos de texto ---
$referencia    = trim($_POST['referencia']    ?? '');
$referencia_id = trim($_POST['referencia_id'] ?? '');
$tipo          = 'crlv';

$refs_validas = ['motorista', 'aluno'];

if (!in_array($referencia, $refs_validas, true)) {
    Response::error('Campo referencia inválido. Use: motorista ou aluno.');
}
if (empty($referencia_id)) {
    Response::error('Campo referencia_id é obrigatório.');
}

// --- Validação do arquivo ---
if (!isset($_FILES['arquivo']) || $_FILES['arquivo']['error'] !== UPLOAD_ERR_OK) {
    $erros = [
        UPLOAD_ERR_INI_SIZE   => 'Arquivo excede o tamanho máximo do servidor.',
        UPLOAD_ERR_FORM_SIZE  => 'Arquivo excede o tamanho máximo do formulário.',
        UPLOAD_ERR_PARTIAL    => 'Upload incompleto.',
        UPLOAD_ERR_NO_FILE    => 'Nenhum arquivo enviado.',
        UPLOAD_ERR_NO_TMP_DIR => 'Pasta temporária não encontrada.',
        UPLOAD_ERR_CANT_WRITE => 'Falha ao gravar arquivo temporário.',
        UPLOAD_ERR_EXTENSION  => 'Upload bloqueado por extensão.',
    ];
    $codigo = $_FILES['arquivo']['error'] ?? UPLOAD_ERR_NO_FILE;
    Response::error($erros[$codigo] ?? 'Erro desconhecido no upload.');
}

$arquivo = $_FILES['arquivo'];
$tamanho_max = 10 * 1024 * 1024; // 10 MB

if ($arquivo['size'] > $tamanho_max) {
    Response::error('Arquivo maior que 10 MB.');
}

$ext = strtolower(pathinfo($arquivo['name'], PATHINFO_EXTENSION));
$exts_validas = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
if (!in_array($ext, $exts_validas, true)) {
    Response::error('Extensão inválida. Use: jpg, jpeg, png, webp ou pdf.');
}

$mime = mime_content_type($arquivo['tmp_name']);
$mimes_validos = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
if (!in_array($mime, $mimes_validos, true)) {
    Response::error('Tipo de arquivo inválido.');
}

// --- Determina o diretório de destino ---
$base_dir = __DIR__ . '/../../uploads';
$dir_dest = $referencia === 'motorista'
    ? $base_dir . '/motoristas/' . $referencia_id
    : $base_dir . '/alunos/'    . $referencia_id;

if (!is_dir($dir_dest)) {
    if (!mkdir($dir_dest, 0755, true)) {
        Response::error('Não foi possível criar o diretório de upload.');
    }
}

// --- OCR: extrai o ano do exercício ---
// Roda antes de comprimir — usa versão de alta qualidade para melhor leitura
$crlv_exercicio = null;

$crlv_exercicio  = null;
$veiculo_placa   = null;
$veiculo_modelo  = null;

$ocr_tmp = $dir_dest . '/crlv_ocr_tmp.png';
$ocr_ok  = false;

if ($mime === 'application/pdf') {
    // Renderiza a 200 DPI (alta resolução) só para o OCR
    $cmd = "convert -density 200 " . escapeshellarg($arquivo['tmp_name']) . "[0] -background white -flatten " . escapeshellarg($ocr_tmp) . " 2>&1";
    shell_exec($cmd);
    $ocr_ok = file_exists($ocr_tmp);
} else {
    // Para imagens, usa o arquivo original direto
    copy($arquivo['tmp_name'], $ocr_tmp);
    $ocr_ok = true;
}

if ($ocr_ok) {
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => 'https://api.ocr.space/parse/image',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => [
            'apikey'      => OCR_SPACE_API_KEY,
            'language'    => 'por',
            'isTable'     => 'false',
            'file'        => new CURLFile($ocr_tmp, 'image/png', 'crlv.png'),
        ],
        CURLOPT_TIMEOUT        => 30,
    ]);
    $ocr_response = curl_exec($ch);
    curl_close($ch);
    @unlink($ocr_tmp);

    if ($ocr_response) {
        $ocr_data = json_decode($ocr_response, true);
        $texto = $ocr_data['ParsedResults'][0]['ParsedText'] ?? '';
        error_log('[upload/foto_crlv] OCR texto: ' . substr($texto, 0, 500));

        // Exercício (ano do licenciamento)
        if (preg_match('/EXERC[IÍ]CIO\s*[:\-]?\s*(\d{4})/ui', $texto, $m)) {
            $crlv_exercicio = (int) $m[1];
            error_log("[upload/foto_crlv] Exercício extraído: $crlv_exercicio");
        } else {
            if (preg_match_all('/\b(20[2-3]\d)\b/', $texto, $anos)) {
                $crlv_exercicio = (int) max($anos[1]);
                error_log("[upload/foto_crlv] Exercício via fallback: $crlv_exercicio");
            }
        }

        // Placa (formato antigo ABC1234 ou Mercosul ABC1D23)
        if (preg_match('/\bPLACA\b.*?([A-Z]{3}[\d][A-Z0-9][\d]{2})\b/uis', $texto, $m)) {
            $veiculo_placa = strtoupper(trim($m[1]));
            error_log("[upload/foto_crlv] Placa extraída: $veiculo_placa");
        }

        // Marca / Modelo / Versão — pula a linha intermediária do campo CAT (***) e captura a próxima
        if (preg_match('/MARCA\s*\/\s*MODELO[^\n]*\n[^\n]*\n([A-Z][^\n]+)/ui', $texto, $m)) {
            $veiculo_modelo = trim($m[1]);
            error_log("[upload/foto_crlv] Modelo extraído: $veiculo_modelo");
        }
    }
} else {
    @unlink($ocr_tmp);
}

// --- Converte para WebP comprimido (150 DPI, quality 5) ---
if ($mime === 'application/pdf') {
    $cropped_tmp = $dir_dest . '/crlv_cropped.png';
    $cmd = "convert -density 150 " . escapeshellarg($arquivo['tmp_name']) . "[0] -background white -flatten -quality 95 -crop 585x855+15+22 +repage " . escapeshellarg($cropped_tmp) . " 2>&1";
    $output = shell_exec($cmd);
    error_log("[upload/foto_crlv] ImageMagick compress: $output");

    if (!file_exists($cropped_tmp)) {
        Response::error('Falha ao processar CRLV.');
    }

    $imagem_src = imagecreatefrompng($cropped_tmp);
    @unlink($cropped_tmp);
} else {
    switch ($mime) {
        case 'image/jpeg':
            $imagem_src = imagecreatefromjpeg($arquivo['tmp_name']);
            break;
        case 'image/png':
            $imagem_src = imagecreatefrompng($arquivo['tmp_name']);
            if ($imagem_src) {
                imagepalettetotruecolor($imagem_src);
                imagealphablending($imagem_src, true);
                imagesavealpha($imagem_src, true);
            }
            break;
        case 'image/webp':
            $imagem_src = imagecreatefromwebp($arquivo['tmp_name']);
            break;
    }
}

if ($imagem_src === false || $imagem_src === null) {
    Response::error('Não foi possível processar a imagem.');
}

$arquivo_dest = $dir_dest . '/crlv.webp';
$salvo = imagewebp($imagem_src, $arquivo_dest, 5);
imagedestroy($imagem_src);

if (!$salvo) {
    Response::error('Falha ao salvar a imagem no servidor.');
}

// --- Monta URL pública ---
$base_url   = 'https://rotaescolar.app.br/uploads';
$url_publica = $referencia === 'motorista'
    ? $base_url . '/motoristas/' . $referencia_id . '/crlv.webp'
    : $base_url . '/alunos/'    . $referencia_id . '/crlv.webp';

// --- Grava no banco ---
try {
    $pdo = Database::getInstance();

    if ($referencia === 'motorista') {
        $sets  = ['crlv_url = ?', 'updated_at = NOW()'];
        $params = [$url_publica];

        if ($crlv_exercicio !== null) { $sets[] = 'crlv_exercicio = ?';  $params[] = $crlv_exercicio; }
        if ($veiculo_placa  !== null) { $sets[] = 'veiculo_placa = ?';   $params[] = $veiculo_placa;  }
        if ($veiculo_modelo !== null) { $sets[] = 'veiculo_modelo = ?';  $params[] = $veiculo_modelo; }

        $params[] = $referencia_id;
        $stmt = $pdo->prepare("UPDATE motoristas SET " . implode(', ', $sets) . " WHERE uid = ?");
        $stmt->execute($params);
    }
} catch (PDOException $e) {
    error_log('[upload/foto_crlv] DB error: ' . $e->getMessage());
}

Response::success([
    'url'            => $url_publica,
    'tipo'           => $tipo,
    'crlv_exercicio' => $crlv_exercicio,
    'veiculo_placa'  => $veiculo_placa,
    'veiculo_modelo' => $veiculo_modelo,
]);
