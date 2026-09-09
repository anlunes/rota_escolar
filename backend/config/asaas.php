<?php
/**
 * Configuração Asaas — gateway de pagamento
 * Documentação: https://docs.asaas.com
 *
 * Os segredos são lidos de backend/config/.env (não versionado).
 * Exemplo de conteúdo do .env:
 *   ASAAS_API_KEY=sua_chave_aqui
 *   ASAAS_WEBHOOK_TOKEN=seu_token_aqui
 */

$_envFile = __DIR__ . '/.env';
if (file_exists($_envFile)) {
    $vars = parse_ini_file($_envFile);
    foreach ($vars as $k => $v) {
        if (!defined($k)) putenv("$k=$v");
    }
}

define('ASAAS_API_KEY',       getenv('ASAAS_API_KEY')       ?: '');
define('ASAAS_BASE_URL',      'https://api.asaas.com/api/v3');
define('ASAAS_WEBHOOK_TOKEN', getenv('ASAAS_WEBHOOK_TOKEN') ?: '');
