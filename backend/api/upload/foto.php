<?php
/**
 * POST /api/upload/foto.php
 *
 * Endpoint genérico para upload de fotos do projeto.
 *
 * Campos multipart/form-data:
 *   referencia     motorista | aluno
 *   referencia_id  uid (motorista) ou aluno_id numérico (aluno)
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

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') Response::methodNotAllowed();

$payload = AuthMiddleware::require();
$uid     = $payload['sub'] ?? $payload['user_id'] ?? null;

$referencia    = trim($_POST['referencia']    ?? '');
$referencia_id = trim($_POST['referencia_id'] ?? '');
$tipo          = trim($_POST['tipo']          ?? '');

error_log("[upload/foto] referencia=$referencia, referencia_id=$referencia_id, tipo=$tipo");

$refs_validas  = ['motorista', 'aluno'];
$tipos_validos = ['perfil', 'cnh', 'crlv', 'autorizacao', 'app'];

if (!in_array($referencia, $refs_validas, true))  Response::error('Campo referencia inválido. Use: motorista ou aluno.');
if (empty($referencia_id))                        Response::error('Campo referencia_id é obrigatório.');
if (!in_array($tipo, $tipos_validos, true))       Response::error('Campo tipo inválido. Use: ' . implode(', ', $tipos_validos));

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

$arquivo     = $_FILES['arquivo'];
$tamanho_max = 10 * 1024 * 1024;

if ($arquivo['size'] > $tamanho_max) Response::error('Arquivo maior que 10 MB.');

$ext = strtolower(pathinfo($arquivo['name'], PATHINFO_EXTENSION));
if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'pdf'], true)) Response::error('Extensão inválida.');

$mime = mime_content_type($arquivo['tmp_name']);
if (!in_array($mime, ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'], true)) Response::error('Tipo de arquivo inválido.');

$base_dir = __DIR__ . '/../../uploads';
$dir_dest = $referencia === 'motorista'
    ? $base_dir . '/motoristas/' . $referencia_id
    : $base_dir . '/alunos/'     . $referencia_id;

if (!is_dir($dir_dest) && !mkdir($dir_dest, 0755, true)) Response::error('Não foi possível criar o diretório de upload.');

// --- Converte para WEBP ---
if ($mime === 'application/pdf') {
    if ($tipo === 'cnh') {
        $cropped_tmp = $dir_dest . '/' . $tipo . '_cropped.png';
        $cmd = "convert -density 150 " . escapeshellarg($arquivo['tmp_name']) . "[0] -quality 95 -crop 622x750+37+124 +repage " . escapeshellarg($cropped_tmp) . " 2>&1";
        shell_exec($cmd);
        if (!file_exists($cropped_tmp)) Response::error('Falha ao processar CNH.');
        $imagem_src = imagecreatefrompng($cropped_tmp);
        @unlink($cropped_tmp);
    } else {
        $png_tmp = $dir_dest . '/' . $tipo . '_tmp.png';
        shell_exec("convert -density 200 " . escapeshellarg($arquivo['tmp_name']) . "[0] -quality 90 " . escapeshellarg($png_tmp) . " 2>&1");
        if (!file_exists($png_tmp)) Response::error('Falha ao converter PDF para imagem.');
        $imagem_src = imagecreatefrompng($png_tmp);
        @unlink($png_tmp);
    }
} else {
    switch ($mime) {
        case 'image/jpeg':
            $oriented_tmp = $dir_dest . '/' . $tipo . '_oriented.png';
            if ($tipo === 'perfil') {
                $cmd = "convert " . escapeshellarg($arquivo['tmp_name']) . " -auto-orient -gravity Center -thumbnail 400x400^ -extent 400x400 " . escapeshellarg($oriented_tmp) . " 2>&1";
            } else {
                $cmd = "convert " . escapeshellarg($arquivo['tmp_name']) . " -auto-orient " . escapeshellarg($oriented_tmp) . " 2>&1";
            }
            shell_exec($cmd);
            $imagem_src = file_exists($oriented_tmp)
                ? imagecreatefrompng($oriented_tmp)
                : imagecreatefromjpeg($arquivo['tmp_name']);
            if (isset($oriented_tmp)) @unlink($oriented_tmp);
            break;
        case 'image/png':
            $imagem_src = imagecreatefrompng($arquivo['tmp_name']);
            if ($imagem_src) { imagepalettetotruecolor($imagem_src); imagealphablending($imagem_src, true); imagesavealpha($imagem_src, true); }
            break;
        case 'image/webp':
            $imagem_src = imagecreatefromwebp($arquivo['tmp_name']);
            break;
        default:
            $imagem_src = false;
    }
}

if (empty($imagem_src)) Response::error('Não foi possível processar a imagem.');

$arquivo_dest = $dir_dest . '/' . $tipo . '.webp';
$salvo = imagewebp($imagem_src, $arquivo_dest, 40);
imagedestroy($imagem_src);

if (!$salvo) Response::error('Falha ao salvar a imagem no servidor.');

$base_url   = 'https://rotaescolar.app.br/uploads';
$url_publica = $referencia === 'motorista'
    ? $base_url . '/motoristas/' . $referencia_id . '/' . $tipo . '.webp'
    : $base_url . '/alunos/'     . $referencia_id . '/' . $tipo . '.webp';

// --- Grava URL no banco ---
try {
    $pdo = Database::getInstance();

    if ($referencia === 'motorista') {
        $map = ['cnh' => 'cnh_url', 'crlv' => 'crlv_url', 'perfil' => 'foto_url', 'app' => 'seguro_url', 'autorizacao' => 'autorizacao_url'];
        $coluna = $map[$tipo] ?? null;
        if ($coluna) {
            $pdo->prepare("UPDATE motoristas SET $coluna = ?, updated_at = NOW() WHERE uid = ?")
                ->execute([$url_publica, $referencia_id]);
        }
    } elseif ($referencia === 'aluno' && $tipo === 'perfil' && is_numeric($referencia_id)) {
        $pdo->prepare("UPDATE alunos SET foto_url = ?, updated_at = NOW() WHERE aluno_id = ?")
            ->execute([$url_publica, (int)$referencia_id]);
    }
} catch (PDOException $e) {
    error_log('[upload/foto] DB error: ' . $e->getMessage());
}

Response::success(['url' => $url_publica, 'tipo' => $tipo]);
