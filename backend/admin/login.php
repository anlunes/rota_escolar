<?php
session_start();
require_once __DIR__ . '/config.php';

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $user = trim($_POST['username'] ?? '');
    $pass = $_POST['password'] ?? '';
    if ($user === ADMIN_USER && $pass === ADMIN_PASS) {
        $_SESSION[ADMIN_SESSION_KEY] = true;
        header('Location: index.php');
        exit;
    }
    $error = 'Usuário ou senha incorretos.';
}

if (!empty($_SESSION[ADMIN_SESSION_KEY])) {
    header('Location: index.php');
    exit;
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Admin — Rota Escolar</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: sans-serif; background: #f5f5f5; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
  .card { background: #fff; border-radius: 12px; padding: 40px; width: 340px; box-shadow: 0 2px 16px rgba(0,0,0,.1); }
  h1 { font-size: 1.4rem; margin-bottom: 8px; color: #222; }
  p.sub { font-size: .85rem; color: #888; margin-bottom: 24px; }
  label { display: block; font-size: .85rem; color: #555; margin-bottom: 4px; }
  input { width: 100%; padding: 10px 12px; border: 1px solid #ddd; border-radius: 8px; font-size: .95rem; margin-bottom: 16px; }
  input:focus { outline: none; border-color: #f5c400; }
  button { width: 100%; padding: 12px; background: #f5c400; border: none; border-radius: 8px; font-size: 1rem; font-weight: 600; cursor: pointer; }
  button:hover { background: #e0b000; }
  .error { background: #fdecea; color: #c0392b; padding: 10px 12px; border-radius: 8px; font-size: .85rem; margin-bottom: 16px; }
</style>
</head>
<body>
<div class="card">
  <h1>🚌 Rota Escolar</h1>
  <p class="sub">Painel Administrativo</p>
  <?php if ($error): ?>
    <div class="error"><?= htmlspecialchars($error) ?></div>
  <?php endif; ?>
  <form method="POST">
    <label>Usuário</label>
    <input type="text" name="username" autofocus autocomplete="username">
    <label>Senha</label>
    <input type="password" name="password" autocomplete="current-password">
    <button type="submit">Entrar</button>
  </form>
</div>
</body>
</html>
