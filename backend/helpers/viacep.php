<?php
class ViaCep {
    private const BASE_URL = 'https://viacep.com.br/ws/';

    public static function lookup(string $cep): ?array {
        $cep  = preg_replace('/\D/', '', $cep);
        if (strlen($cep) !== 8) return null;

        $url  = self::BASE_URL . $cep . '/json/';
        $ctx  = stream_context_create(['http' => ['timeout' => 5]]);
        $data = @file_get_contents($url, false, $ctx);
        if (!$data) return null;

        $json = json_decode($data, true);
        if (!$json || isset($json['erro'])) return null;
        return $json;
    }
}
