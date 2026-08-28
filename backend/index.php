<?php
header('Content-Type: application/json');
echo json_encode([
    'app' => 'Rota Escolar API',
    'version' => '1.0.0',
    'status' => 'online',
    'timestamp' => date('c'),
]);
