<?php
/**
 * POST /api/upload/foto.php
 *
 * Campos multipart/form-data:
 *   referencia     motorista | aluno
 *   referencia_id  uid (motorista) ou id numérico (aluno)
 *   tipo           perfil | cnh | crlv | autorizacao | app
 *   arquivo        arquivo de imagem (jpg, jpeg, png, webp, pdf) – máx 10 MB
 *
 * Retorna JSON { success, url } ou { success: false, error }
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/firebase.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

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
$tipo          = trim($_POST['tipo']          ?? '');

error_log("[upload/foto] referencia=$referencia, referencia_id=$referencia_id, tipo=$tipo");
error_log("[upload/foto] FILES=" . json_encode(array_keys($_FILES)));
error_log("[upload/foto] POST=" . json_encode($_POST));

$refs_validas = ['motorista', 'aluno'];
$tipos_validos = ['perfil', 'cnh', 'crlv', 'autorizacao', 'app'];

if (!in_array($referencia, $refs_validas, true)) {
    Response::error('Campo referencia inválido. Use: motorista ou aluno.');
}
if (empty($referencia_id)) {
    Response::error('Campo referencia_id é obrigatório.');
}
if (!in_array($tipo, $tipos_validos, true)) {
    Response::error('Campo tipo inválido. Use: ' . implode(', ', $tipos_validos));
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
    error_log("[upload/foto] UPLOAD ERROR code=$codigo");
    Response::error($erros[$codigo] ?? 'Erro desconhecido no upload.');
}

$arquivo = $_FILES['arquivo'];
$tamanho_max = 10 * 1024 * 1024; // 10 MB

error_log("[upload/foto] arquivo: name={$arquivo['name']}, size={$arquivo['size']}, type={$arquivo['type']}, tmp={$arquivo['tmp_name']}");

if ($arquivo['size'] > $tamanho_max) {
    Response::error('Arquivo maior que 10 MB.');
}

// Verifica extensão e MIME
$ext = strtolower(pathinfo($arquivo['name'], PATHINFO_EXTENSION));
$exts_validas = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
if (!in_array($ext, $exts_validas, true)) {
    error_log("[upload/foto] extensao invalida: $ext");
    Response::error('Extensão inválida. Use: jpg, jpeg, png, webp ou pdf.');
}

$mime = mime_content_type($arquivo['tmp_name']);
$mimes_validos = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
error_log("[upload/foto] mime detectado: $mime");
if (!in_array($mime, $mimes_validos, true)) {
    error_log("[upload/foto] mime invalido: $mime");
    Response::error('Tipo de arquivo inválido.');
}

// --- Determina o diretório de destino ---
$base_dir = __DIR__ . '/../../uploads';

if ($referencia === 'motorista') {
    $dir_dest = $base_dir . '/motoristas/' . $referencia_id;
} else {
    $dir_dest = $base_dir . '/alunos/' . $referencia_id;
}

if (!is_dir($dir_dest)) {
    if (!mkdir($dir_dest, 0755, true)) {
        Response::error('Não foi possível criar o diretório de upload.');
    }
}

// --- Converte para WEBP usando GD/ImageMagick ---
if ($mime === 'application/pdf') {
    if ($tipo === 'cnh') {
        // CNH: renderiza PDF a 200 DPI e crop único (frente+verso, sem MRZ)
        $cropped_tmp = $dir_dest . '/' . $tipo . '_cropped.png';
        $cmd = "convert -density 150 " . escapeshellarg($arquivo['tmp_name']) . "[0] -quality 95 -crop 622x750+37+124 +repage " . escapeshellarg($cropped_tmp) . " 2>&1";
        $output = shell_exec($cmd);
        error_log("[upload/foto] ImageMagick CNH: $output");

        if (!file_exists($cropped_tmp)) {
            Response::error('Falha ao processar CNH.');
        }

        $imagem_src = imagecreatefrompng($cropped_tmp);
        @unlink($cropped_tmp);
    } else {
        // PDF genérico: converte primeira página inteira
        $png_tmp = $dir_dest . '/' . $tipo . '_tmp.png';
        $cmd = "convert -density 200 " . escapeshellarg($arquivo['tmp_name']) . "[0] -quality 90 " . escapeshellarg($png_tmp) . " 2>&1";
        shell_exec($cmd);

        if (!file_exists($png_tmp)) {
            Response::error('Falha ao converter PDF para imagem.');
        }

        $imagem_src = imagecreatefrompng($png_tmp);
        @unlink($png_tmp);
    }
} else {
    // Imagem: carrega direto
    switch ($mime) {
        case 'image/jpeg':
            $oriented_tmp = $dir_dest . '/' . $tipo . '_oriented.png';
            if ($tipo === 'perfil') {
                // Foto de perfil: corrige orientação + crop quadrado centralizado 400x400
                $cmd = "convert " . escapeshellarg($arquivo['tmp_name']) . " -auto-orient -gravity Center -thumbnail 400x400^ -extent 400x400 " . escapeshellarg($oriented_tmp) . " 2>&1";
            } else {
                // Demais imagens: só corrige orientação
                $cmd = "convert " . escapeshellarg($arquivo['tmp_name']) . " -auto-orient " . escapeshellarg($oriented_tmp) . " 2>&1";
            }
            shell_exec($cmd);
            if (file_exists($oriented_tmp)) {
                $imagem_src = imagecreatefrompng($oriented_tmp);
                @unlink($oriented_tmp);
            } else {
                $imagem_src = imagecreatefromjpeg($arquivo['tmp_name']);
            }
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

$arquivo_dest = $dir_dest . '/' . $tipo . '.webp';
$salvo = imagewebp($imagem_src, $arquivo_dest, 40);
imagedestroy($imagem_src);

if (!$salvo) {
    Response::error('Falha ao salvar a imagem no servidor.');
}

// --- Monta URL pública ---
$base_url = 'https://rotaescolar.app.br/uploads';
if ($referencia === 'motorista') {
    $url_publica = $base_url . '/motoristas/' . $referencia_id . '/' . $tipo . '.webp';
} else {
    $url_publica = $base_url . '/alunos/' . $referencia_id . '/' . $tipo . '.webp';
}

// --- Grava URL no banco ---
try {
    $pdo = Database::getInstance();

    if ($referencia === 'motorista') {
        $coluna = null;
        switch ($tipo) {
            case 'cnh':        $coluna = 'cnh_url';          break;
            case 'crlv':       $coluna = 'crlv_url';         break;
            case 'perfil':     $coluna = 'foto_url';         break;
            case 'app':        $coluna = 'seguro_url';       break;
            case 'autorizacao': $coluna = 'autorizacao_url'; break;
        }
        if ($coluna) {
            $stmt = $pdo->prepare("UPDATE motoristas SET $coluna = ?, updated_at = NOW() WHERE uid = ?");
            $stmt->execute([$url_publica, $referencia_id]);
        }
    }
} catch (PDOException $e) {
    error_log('[upload/foto] DB error: ' . $e->getMessage());
}

Response::success([
    'url'  => $url_publica,
    'tipo' => $tipo,
]);
