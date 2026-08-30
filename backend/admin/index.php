<?php
session_start();
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/../config/database.php';

if (empty($_SESSION[ADMIN_SESSION_KEY])) {
    header('Location: login.php');
    exit;
}

// Logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: login.php');
    exit;
}

// Ação de aprovação/rejeição via POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id     = (int)($_POST['id']     ?? 0);
    $acao   = $_POST['acao']   ?? '';
    $tabela = $_POST['tabela'] ?? '';

    if ($id && in_array($acao, ['aprovar', 'rejeitar'])) {
        $pdo = Database::getInstance();

        if ($tabela === 'bairros') {
            if ($acao === 'aprovar') {
                $pdo->prepare("UPDATE bairros SET status = 'ativo' WHERE id = ?")->execute([$id]);
            } else {
                $pdo->prepare("DELETE FROM bairros WHERE id = ? AND status = 'pendente'")->execute([$id]);
            }
        } elseif ($tabela === 'escolas') {
            if ($acao === 'aprovar') {
                $pdo->prepare("UPDATE escolas SET status = 'ativo' WHERE escola_id = ?")->execute([$id]);
            } else {
                $pdo->prepare("DELETE FROM escolas WHERE escola_id = ? AND status = 'pendente'")->execute([$id]);
            }
        }
    }
    header('Location: index.php');
    exit;
}

$pdo = Database::getInstance();

// Bairros pendentes
$bairrosPendentes = $pdo->query("
    SELECT id, nome,
           COALESCE(municipio_nome, CONCAT('IBGE ', municipio_id)) AS municipio_nome
    FROM bairros
    WHERE status = 'pendente'
    ORDER BY id DESC
")->fetchAll();

// Escolas pendentes
try {
    $escolasPendentes = $pdo->query("
        SELECT escola_id, nome,
               COALESCE(bairro, '')      AS bairro,
               COALESCE(logradouro, '')  AS logradouro,
               COALESCE(numero, '')      AS numero,
               COALESCE(cep, '')         AS cep,
               COALESCE(municipio, '')   AS municipio,
               COALESCE(estado, '')      AS estado
        FROM escolas
        WHERE status = 'pendente'
        ORDER BY escola_id DESC
    ")->fetchAll();
} catch (Throwable $e) {
    $escolasPendentes = [];
    $escolasErro = $e->getMessage();
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
  body { font-family: sans-serif; background: #f5f5f5; color: #333; }

  header {
    background: #f5c400;
    padding: 0 24px;
    height: 56px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 2px 6px rgba(0,0,0,.12);
  }
  header h1 { font-size: 1.1rem; font-weight: 700; }
  header a { font-size: .85rem; color: #333; text-decoration: none; opacity: .7; }
  header a:hover { opacity: 1; }

  main { max-width: 900px; margin: 32px auto; padding: 0 16px; }

  .section {
    margin-bottom: 40px;
  }
  .section-title {
    font-size: 1rem;
    font-weight: 700;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .badge {
    background: #e74c3c;
    color: #fff;
    font-size: .75rem;
    padding: 2px 8px;
    border-radius: 99px;
    font-weight: 600;
  }

  .empty { color: #888; font-size: .9rem; padding: 16px 0; }

  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 6px rgba(0,0,0,.08); }
  th { background: #fafafa; text-align: left; padding: 12px 16px; font-size: .8rem; color: #777; text-transform: uppercase; letter-spacing: .05em; border-bottom: 1px solid #eee; }
  td { padding: 12px 16px; border-bottom: 1px solid #f0f0f0; font-size: .92rem; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: #fffdf0; }

  .actions { display: flex; gap: 8px; }
  .btn-aprovar {
    background: #27ae60; color: #fff; border: none;
    padding: 6px 14px; border-radius: 6px; cursor: pointer; font-size: .85rem; font-weight: 600;
  }
  .btn-aprovar:hover { background: #219653; }
  .btn-rejeitar {
    background: #fff; color: #e74c3c; border: 1px solid #e74c3c;
    padding: 6px 14px; border-radius: 6px; cursor: pointer; font-size: .85rem; font-weight: 600;
  }
  .btn-rejeitar:hover { background: #fdecea; }
</style>
</head>
<body>

<header>
  <h1>🚌 Rota Escolar — Admin</h1>
  <a href="?logout=1">Sair</a>
</header>

<main>

  <!-- Bairros pendentes -->
  <div class="section">
    <div class="section-title">
      Bairros aguardando aprovação
      <?php if (count($bairrosPendentes)): ?>
        <span class="badge"><?= count($bairrosPendentes) ?></span>
      <?php endif; ?>
    </div>

    <?php if (empty($bairrosPendentes)): ?>
      <p class="empty">Nenhum bairro pendente.</p>
    <?php else: ?>
      <table>
        <thead>
          <tr><th>#</th><th>Bairro</th><th>Município</th><th>Ações</th></tr>
        </thead>
        <tbody>
          <?php foreach ($bairrosPendentes as $b): ?>
          <tr>
            <td><?= $b['id'] ?></td>
            <td><?= htmlspecialchars($b['nome']) ?></td>
            <td><?= htmlspecialchars($b['municipio_nome']) ?></td>
            <td>
              <div class="actions">
                <form method="POST" style="display:inline">
                  <input type="hidden" name="id"     value="<?= $b['id'] ?>">
                  <input type="hidden" name="acao"   value="aprovar">
                  <input type="hidden" name="tabela" value="bairros">
                  <button class="btn-aprovar" type="submit">✓ Aprovar</button>
                </form>
                <form method="POST" style="display:inline"
                      onsubmit="return confirm('Rejeitar e excluir este bairro?')">
                  <input type="hidden" name="id"     value="<?= $b['id'] ?>">
                  <input type="hidden" name="acao"   value="rejeitar">
                  <input type="hidden" name="tabela" value="bairros">
                  <button class="btn-rejeitar" type="submit">✕ Rejeitar</button>
                </form>
              </div>
            </td>
          </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    <?php endif; ?>
  </div>

  <!-- Escolas pendentes -->
  <div class="section">
    <div class="section-title">
      Escolas aguardando aprovação
      <?php if (count($escolasPendentes)): ?>
        <span class="badge"><?= count($escolasPendentes) ?></span>
      <?php endif; ?>
    </div>

    <?php if (!empty($escolasErro)): ?>
      <p class="empty" style="color:#e74c3c">Erro ao carregar escolas: <?= htmlspecialchars($escolasErro) ?></p>
    <?php elseif (empty($escolasPendentes)): ?>
      <p class="empty">Nenhuma escola pendente.</p>
    <?php else: ?>
      <table>
        <thead>
          <tr><th>#</th><th>Escola</th><th>Bairro</th><th>Endereço</th><th>Ações</th></tr>
        </thead>
        <tbody>
          <?php foreach ($escolasPendentes as $e): ?>
          <tr>
            <td><?= $e['escola_id'] ?></td>
            <td><?= htmlspecialchars($e['nome']) ?></td>
            <td><?= htmlspecialchars($e['bairro']) ?></td>
            <td style="font-size:.85rem">
              <?= htmlspecialchars(trim($e['logradouro'] . ' ' . $e['numero'])) ?>
              <?php if ($e['cep']): ?><br><span style="color:#888"><?= htmlspecialchars($e['cep']) ?> — <?= htmlspecialchars($e['municipio']) ?>/<?= htmlspecialchars($e['estado']) ?></span><?php endif; ?>
            </td>
            <td>
              <div class="actions">
                <form method="POST" style="display:inline">
                  <input type="hidden" name="id"     value="<?= $e['escola_id'] ?>">
                  <input type="hidden" name="acao"   value="aprovar">
                  <input type="hidden" name="tabela" value="escolas">
                  <button class="btn-aprovar" type="submit">✓ Aprovar</button>
                </form>
                <form method="POST" style="display:inline"
                      onsubmit="return confirm('Rejeitar e excluir esta escola?')">
                  <input type="hidden" name="id"     value="<?= $e['escola_id'] ?>">
                  <input type="hidden" name="acao"   value="rejeitar">
                  <input type="hidden" name="tabela" value="escolas">
                  <button class="btn-rejeitar" type="submit">✕ Rejeitar</button>
                </form>
              </div>
            </td>
          </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    <?php endif; ?>
  </div>

</main>
</body>
</html>
