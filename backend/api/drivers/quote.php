<?php
/**
 * GET /api/drivers/quote.php?motorista_id=X&aluno_id=Y
 *
 * Calcula o orçamento mensal estimado de transporte.
 *
 * Estratégia de cálculo de distância (em cascata):
 *   1. Google Maps Directions API — se billing ativo
 *   2. OpenRouteService — gratuito, roteamento real por estradas
 *   3. Haversine × 1.3 — fallback de último recurso
 *
 * Fórmula: (distância_ida + distância_volta) × preco_km × 22 dias úteis
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/google_maps.php';
require_once __DIR__ . '/../../config/openrouteservice.php';
require_once __DIR__ . '/../../middleware/auth_middleware.php';
require_once __DIR__ . '/../../helpers/response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') Response::methodNotAllowed();

AuthMiddleware::require();

$motoristaId = isset($_GET['motorista_id']) ? (int)$_GET['motorista_id'] : 0;
$alunoId     = isset($_GET['aluno_id'])     ? (int)$_GET['aluno_id']     : 0;

if ($motoristaId <= 0 || $alunoId <= 0) {
    Response::error('motorista_id e aluno_id são obrigatórios.', 400);
}

try {
    $pdo = Database::getInstance();

    // ── Preço/km do motorista ────────────────────────────────────────────────
    $mStmt = $pdo->prepare("
        SELECT m.preco_km, COALESCE(mu.nome, '') AS municipio_nome
        FROM motoristas m
        LEFT JOIN municipios mu ON mu.id = m.pref_municipio_id
        WHERE m.motorista_id = ? LIMIT 1
    ");
    $mStmt->execute([$motoristaId]);
    $motorista = $mStmt->fetch();
    if (!$motorista) Response::error('Motorista não encontrado.', 404);

    $precoKm = $motorista['preco_km'] !== null ? (float)$motorista['preco_km'] : null;
    if (!$precoKm || $precoKm <= 0) {
        Response::error('Este motorista ainda não informou o preço por km.', 422);
    }

    // ── Endereço do aluno e escola ───────────────────────────────────────────
    $aStmt = $pdo->prepare("
        SELECT
            a.aluno_id,
            a.nome                                AS aluno_nome,
            COALESCE(a.logradouro, '')            AS logradouro,
            COALESCE(a.numero_residencia, '')     AS numero,
            COALESCE(a.bairro_residencia, '')     AS bairro_aluno,
            COALESCE(a.cep_residencia, '')        AS cep,
            COALESCE(e.nome, '')                  AS escola_nome,
            COALESCE(e.logradouro, '')            AS escola_logradouro,
            COALESCE(e.bairro, '')                AS escola_bairro,
            COALESCE(e.municipio, '')             AS escola_municipio,
            e.lat                                 AS escola_lat,
            e.lon                                 AS escola_lon
        FROM alunos a
        LEFT JOIN escolas e ON e.escola_id = a.escola_id
        WHERE a.aluno_id = ?
        LIMIT 1
    ");
    $aStmt->execute([$alunoId]);
    $aluno = $aStmt->fetch();
    if (!$aluno) Response::error('Aluno não encontrado.', 404);

    if (empty(trim($aluno['logradouro'])) && empty(trim($aluno['cep']))) {
        Response::error('Endereço do aluno não cadastrado. Edite o cadastro do filho e preencha o endereço.', 422);
    }
    if (empty($aluno['escola_nome'])) {
        Response::error('Escola do aluno não cadastrada.', 422);
    }

    // Enriquece endereço do aluno via ViaCEP (gratuito, sem chave)
    $municipio = $motorista['municipio_nome'];
    $cepLimpo  = preg_replace('/\D/', '', $aluno['cep']);
    if (strlen($cepLimpo) === 8) {
        $viaCep = _httpGet('https://viacep.com.br/ws/' . $cepLimpo . '/json/');
        if (!empty($viaCep['localidade'])) {
            // Usa dados do ViaCEP (mais confiáveis que o que o usuário digitou)
            $logradouro = !empty($viaCep['logradouro']) ? $viaCep['logradouro'] : $aluno['logradouro'];
            $bairro     = !empty($viaCep['bairro'])     ? $viaCep['bairro']     : $aluno['bairro_aluno'];
            $cidade     = $viaCep['localidade'];
        } else {
            $logradouro = $aluno['logradouro'];
            $bairro     = $aluno['bairro_aluno'];
            $cidade     = $municipio;
        }
    } else {
        $logradouro = $aluno['logradouro'];
        $bairro     = $aluno['bairro_aluno'];
        $cidade     = $municipio;
    }

    // Monta string de busca para geocoder
    $origemTexto = trim(implode(', ', array_filter([
        $logradouro,
        !empty($aluno['numero']) ? 'nº ' . $aluno['numero'] : '',
        $bairro,
        $cidade,
    ])));

    $destinoTexto = trim(implode(', ', array_filter([
        $aluno['escola_nome'],
        $aluno['escola_logradouro'],
        $aluno['escola_bairro'],
        $aluno['escola_municipio'] ?: $cidade,
    ])));

    // ── Cálculo de distância ─────────────────────────────────────────────────
    $usouGoogleMaps    = false;
    $escolaTemCoords   = !empty($aluno['escola_lat']) && !empty($aluno['escola_lon']);

    $googleAtivo = defined('GOOGLE_MAPS_API_KEY') && GOOGLE_MAPS_API_KEY !== 'COLE_SUA_CHAVE_AQUI';

    if ($googleAtivo) {
        // Estratégia 1: Google Maps Directions API
        try {
            $distanciaIda   = _googleDistanciaKm($origemTexto, $destinoTexto);
            $distanciaVolta = _googleDistanciaKm($destinoTexto, $origemTexto);
            $usouGoogleMaps = true;
        } catch (RuntimeException $e) {
            error_log('[quote] Google Maps falhou (' . $e->getMessage() . '), usando ORS.');
            $googleAtivo = false;
        }
    }

    if (!$googleAtivo) {
        // Geocodifica origem (endereço do aluno) via ORS → CEP → Nominatim
        $coordOrigem = _orsGeocode($origemTexto);
        if (!$coordOrigem) $coordOrigem = _geocodePorCep($cepLimpo);
        if (!$coordOrigem) $coordOrigem = _geocodeNominatimCascata($origemTexto, $cidade ?? $municipio);

        // Coordenadas do destino: usa banco se disponível (precisão garantida),
        // senão geocodifica pelo texto — sujeito a erros para nomes de escola
        if ($escolaTemCoords) {
            $coordDestino = [(float)$aluno['escola_lat'], (float)$aluno['escola_lon']];
        } else {
            $coordDestino = _orsGeocode($destinoTexto);
            if (!$coordDestino) $coordDestino = _geocodeNominatimCascata($destinoTexto, $cidade ?? $municipio);
        }

        if (!$coordOrigem) {
            Response::error('Não foi possível localizar o endereço do aluno. Verifique se está completo.', 422);
        }
        if (!$coordDestino) {
            Response::error('Não foi possível localizar a escola. Verifique o endereço cadastrado.', 422);
        }

        // Estratégia 2: OpenRouteService (roteamento real, gratuito)
        $distanciaIda = _orsDistanciaKm($coordOrigem[1], $coordOrigem[0], $coordDestino[1], $coordDestino[0]);
        if ($distanciaIda !== null) {
            $distanciaVolta = _orsDistanciaKm($coordDestino[1], $coordDestino[0], $coordOrigem[1], $coordOrigem[0]);
            $distanciaVolta = $distanciaVolta ?? $distanciaIda;
        } else {
            // Estratégia 3: Haversine × 1.3 (último recurso)
            $distanciaReta  = _haversineKm($coordOrigem[0], $coordOrigem[1], $coordDestino[0], $coordDestino[1]);
            $distanciaIda   = round($distanciaReta * 1.3, 2);
            $distanciaVolta = $distanciaIda;
        }
    }

    $distanciaTotal  = $distanciaIda + $distanciaVolta;
    $diasUteis       = 22;
    $custoMensal     = round($distanciaTotal * $precoKm * $diasUteis, 2);

    Response::success([
        'aluno_nome'             => $aluno['aluno_nome'],
        'origem'                 => $origemTexto,
        'destino'                => $aluno['escola_nome'],
        'distancia_ida_km'       => round($distanciaIda, 2),
        'distancia_volta_km'     => round($distanciaVolta, 2),
        'distancia_total_km'     => round($distanciaTotal, 2),
        'preco_km'               => $precoKm,
        'dias_uteis'             => $diasUteis,
        'custo_mensal_estimado'  => $custoMensal,
        'metodo_calculo'         => $usouGoogleMaps ? 'google_maps' : 'openrouteservice',
    ]);

} catch (Throwable $e) {
    Response::error('Erro: ' . $e->getMessage(), 500);
}

// ── Google Maps Directions API ───────────────────────────────────────────────
function _googleDistanciaKm(string $origem, string $destino): float {
    $url = 'https://maps.googleapis.com/maps/api/directions/json?' . http_build_query([
        'origin'      => $origem . ', Brasil',
        'destination' => $destino . ', Brasil',
        'mode'        => 'driving',
        'language'    => 'pt-BR',
        'key'         => GOOGLE_MAPS_API_KEY,
    ]);
    $data = _httpGet($url);
    if (($data['status'] ?? '') !== 'OK') {
        throw new RuntimeException('Google Maps: ' . ($data['status'] ?? 'erro desconhecido'));
    }
    return ($data['routes'][0]['legs'][0]['distance']['value'] ?? 0) / 1000.0;
}

// ── Geocoding por CEP via Nominatim (mais confiável para endereços BR) ───────
function _geocodeNominatimEstruturado(string $logradouro, string $numero, string $bairro, string $cidade): ?array {
    if (empty($logradouro) || empty($cidade)) return null;
    $rua = trim($numero ? $numero . ' ' . $logradouro : $logradouro);
    $url = 'https://nominatim.openstreetmap.org/search?' . http_build_query([
        'street'  => $rua,
        'city'    => $cidade,
        'country' => 'Brasil',
        'format'  => 'json',
        'limit'   => 1,
    ]);
    $data = _httpGet($url, ['User-Agent: RotaEscolar/1.0 (contato@rotaescolar.app.br)']);
    if (empty($data) || !isset($data[0]['lat'])) return null;
    return [(float)$data[0]['lat'], (float)$data[0]['lon']];
}

// ── Geocoding por CEP (mais confiável que endereço por texto no Brasil) ───────
function _geocodePorCep(string $cep): ?array {
    $cepLimpo = preg_replace('/\D/', '', $cep);
    if (strlen($cepLimpo) !== 8) return null;
    // Formata como 12345-678 para o Nominatim
    $cepFormatado = substr($cepLimpo, 0, 5) . '-' . substr($cepLimpo, 5);
    $url = 'https://nominatim.openstreetmap.org/search?' . http_build_query([
        'postalcode' => $cepFormatado,
        'country'    => 'Brasil',
        'format'     => 'json',
        'limit'      => 1,
    ]);
    $data = _httpGet($url, ['User-Agent: RotaEscolar/1.0 (contato@rotaescolar.app.br)']);
    if (empty($data) || !isset($data[0]['lat'])) return null;
    return [(float)$data[0]['lat'], (float)$data[0]['lon']];
}

// ── Nominatim com fallback em cascata ───────────────────────────────────────
// Tenta: endereço completo + município → só município → falha
function _geocodeNominatimCascata(string $endereco, string $municipio): ?array {
    // 1. Endereço completo + município
    $tentativas = [];
    if (!empty($municipio)) {
        $tentativas[] = $endereco . ', ' . $municipio;
    }
    $tentativas[] = $endereco;
    // 2. Só o bairro/nome + município (primeira parte antes de vírgula)
    $primeiraParce = trim(explode(',', $endereco)[0]);
    if (!empty($municipio) && $primeiraParce !== $endereco) {
        $tentativas[] = $primeiraParce . ', ' . $municipio;
    }
    // 3. Só o município
    if (!empty($municipio)) {
        $tentativas[] = $municipio;
    }

    foreach ($tentativas as $t) {
        $coord = _geocodeNominatim($t);
        if ($coord) return $coord;
        usleep(300000); // respeita rate limit do Nominatim (1 req/s)
    }
    return null;
}

// ── Nominatim geocoder (OpenStreetMap) ──────────────────────────────────────
function _geocodeNominatim(string $endereco): ?array {
    $url = 'https://nominatim.openstreetmap.org/search?' . http_build_query([
        'q'              => $endereco . ', Brasil',
        'format'         => 'json',
        'limit'          => 1,
        'addressdetails' => 0,
    ]);
    $data = _httpGet($url, ['User-Agent: RotaEscolar/1.0 (contato@rotaescolar.app.br)']);
    if (empty($data) || !isset($data[0]['lat'])) return null;
    return [(float)$data[0]['lat'], (float)$data[0]['lon']];
}

// ── OpenRouteService Geocoding (Pelias) ──────────────────────────────────────
// Retorna [lat, lon] ou null
function _orsGeocode(string $texto): ?array {
    $url = 'https://api.openrouteservice.org/geocode/search?' . http_build_query([
        'api_key'          => ORS_API_KEY,
        'text'             => $texto . ', Brasil',
        'boundary.country' => 'BRA',
        'size'             => 1,
    ]);
    $data = _httpGet($url, ['User-Agent: RotaEscolar/1.0']);
    $coords = $data['features'][0]['geometry']['coordinates'] ?? null;
    if (!$coords) return null;
    // ORS retorna [lon, lat]
    return [(float)$coords[1], (float)$coords[0]];
}

// ── OpenRouteService (roteamento real gratuito) ───────────────────────────────
// lon1,lat1 → lon2,lat2  (ORS usa longitude primeiro)
function _orsDistanciaKm(float $lon1, float $lat1, float $lon2, float $lat2): ?float {
    $url = 'https://api.openrouteservice.org/v2/directions/driving-car?' . http_build_query([
        'api_key' => ORS_API_KEY,
        'start'   => "$lon1,$lat1",
        'end'     => "$lon2,$lat2",
    ]);
    $data = _httpGet($url, ['User-Agent: RotaEscolar/1.0']);
    $dist = $data['features'][0]['properties']['summary']['distance'] ?? null;
    if ($dist === null) return null;
    return round((float)$dist / 1000.0, 2);
}

// ── Haversine (distância em linha reta entre dois pontos GPS) ────────────────
function _haversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float {
    $R    = 6371.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a    = sin($dLat / 2) ** 2
          + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;
    return $R * 2 * atan2(sqrt($a), sqrt(1 - $a));
}

// ── HTTP GET genérico com cURL ───────────────────────────────────────────────
function _httpGet(string $url, array $headers = []): array {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    if ($headers) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    }
    $response = curl_exec($ch);
    curl_close($ch);
    return json_decode($response ?: '[]', true) ?? [];
}
