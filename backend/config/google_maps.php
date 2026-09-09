<?php
/**
 * Configuração da Google Maps Platform
 * Ative a Directions API no Google Cloud Console e cole a chave abaixo.
 * Documentação: https://developers.google.com/maps/documentation/directions
 *
 * A chave é lida de backend/config/.env (não versionado).
 * Exemplo: GOOGLE_MAPS_API_KEY=sua_chave_aqui
 */

$_envFile = __DIR__ . '/.env';
if (file_exists($_envFile)) {
    $vars = parse_ini_file($_envFile);
    foreach ($vars as $k => $v) {
        if (!defined($k)) putenv("$k=$v");
    }
}

define('GOOGLE_MAPS_API_KEY', getenv('GOOGLE_MAPS_API_KEY') ?: '');
