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

// Motoristas para o seletor de reset
$motoristas = $pdo->query("
    SELECT m.motorista_id, u.nome
    FROM motoristas m
    JOIN usuarios u ON u.uid = m.uid
    ORDER BY u.nome
")->fetchAll();

// Últimos resets (log)
$ultimosResets = $pdo->query("
    SELECT r.reset_at, r.data_servico, r.tipo, r.alunos_afetados,
           COALESCE(u.nome, 'Todos') AS motorista_nome
    FROM rota_resets r
    LEFT JOIN motoristas m ON m.motorista_id = r.motorista_id
    LEFT JOIN usuarios u ON u.uid = m.uid
    ORDER BY r.reset_at DESC
    LIMIT 10
")->fetchAll();

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

  /* Reset de rota */
  .reset-card {
    background: #fff;
    border-radius: 10px;
    box-shadow: 0 1px 6px rgba(0,0,0,.08);
    padding: 24px;
  }
  .reset-form {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: flex-end;
    margin-bottom: 20px;
  }
  .reset-form label { font-size: .82rem; color: #666; display: block; margin-bottom: 4px; }
  .reset-form input[type=date],
  .reset-form select {
    padding: 8px 10px;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: .9rem;
    background: #fafafa;
  }
  .btn-reset {
    padding: 9px 18px;
    border-radius: 6px;
    border: none;
    cursor: pointer;
    font-size: .88rem;
    font-weight: 600;
  }
  .btn-reset-primary { background: #2c7be5; color: #fff; }
  .btn-reset-primary:hover { background: #1a68d1; }
  .btn-reset-danger  { background: #e74c3c; color: #fff; }
  .btn-reset-danger:hover  { background: #c0392b; }
  .reset-log { margin-top: 16px; }
  .reset-log table { margin-top: 8px; }
  .reset-log th, .reset-log td { font-size: .82rem; }
  #reset-msg { margin-top: 12px; padding: 10px 14px; border-radius: 6px; display: none; font-size: .9rem; }
  #reset-msg.ok  { background: #eafaf1; color: #1e8449; border: 1px solid #a9dfbf; }
  #reset-msg.err { background: #fdecea; color: #c0392b; border: 1px solid #f5c6c6; }
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

  <!-- Zerar Rota do Dia -->
  <div class="section">
    <div class="section-title">Zerar Rota do Dia</div>
    <div class="reset-card">
      <div class="reset-form">
        <div>
          <label>Data</label>
          <input type="date" id="reset-data" value="<?= date('Y-m-d') ?>">
        </div>
        <div>
          <label>Motorista</label>
          <select id="reset-motorista">
            <option value="0">— Selecione —</option>
            <?php foreach ($motoristas as $m): ?>
              <option value="<?= $m['motorista_id'] ?>"><?= htmlspecialchars($m['nome']) ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div>
          <label>O que zerar</label>
          <select id="reset-tipo">
            <option value="ambos">Motorista + Responsáveis</option>
            <option value="mysql">Só tela do motorista</option>
            <option value="rtdb">Só tela dos responsáveis</option>
          </select>
        </div>
        <button class="btn-reset btn-reset-primary" onclick="fazerReset(false)">↺ Zerar motorista selecionado</button>
        <button class="btn-reset btn-reset-danger"  onclick="fazerReset(true)"
                title="Zera todos os motoristas na data selecionada">⚠ Zerar TODOS</button>
      </div>

      <div id="reset-msg"></div>

      <!-- Log dos últimos resets -->
      <?php if (!empty($ultimosResets)): ?>
      <div class="reset-log">
        <strong style="font-size:.85rem;color:#666">Últimos resets</strong>
        <table>
          <thead>
            <tr><th>Data/hora</th><th>Data serviço</th><th>Motorista</th><th>Tipo</th><th>Alunos</th></tr>
          </thead>
          <tbody>
            <?php foreach ($ultimosResets as $r): ?>
            <tr>
              <td><?= date('d/m H:i', strtotime($r['reset_at'])) ?></td>
              <td><?= date('d/m/Y', strtotime($r['data_servico'])) ?></td>
              <td><?= htmlspecialchars($r['motorista_nome']) ?></td>
              <td><?= $r['tipo'] ?></td>
              <td><?= $r['alunos_afetados'] ?></td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
      <?php endif; ?>
    </div>
  </div>

</main>

<script>
async function fazerReset(todos) {
  const data       = document.getElementById('reset-data').value;
  const motoristaId = todos ? 0 : parseInt(document.getElementById('reset-motorista').value);
  const tipo       = document.getElementById('reset-tipo').value;
  const msg        = document.getElementById('reset-msg');

  if (!todos && motoristaId === 0) {
    showMsg('Selecione um motorista ou use "Zerar TODOS".', false);
    return;
  }

  const confirma = todos
    ? confirm('⚠ Isso vai zerar TODOS os motoristas na data ' + data + '.\n\nTem certeza?')
    : confirm('Zerar rota de ' + document.getElementById('reset-motorista').selectedOptions[0].text + ' em ' + data + '?');

  if (!confirma) return;

  msg.style.display = 'none';

  try {
    const res = await fetch('../api/admin/reset_route.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data, motorista_id: motoristaId, tipo }),
    });
    const json = await res.json();
    if (json.success) {
      const debugInfo = json.rtdb_debug ? json.rtdb_debug.map(d =>
        `aluno ${d.aluno_id}: HTTP ${d.http} | resp: ${d.response}`
      ).join('\n') : '';
      const authInfo   = json.rtdb_auth_method ? ` [auth: ${json.rtdb_auth_method}]` : '';
      const secretInfo = `\nsecret_found: ${json.rtdb_secret_found}\npath: ${json.rtdb_secret_path}`;
      const errInfo    = json.rtdb_errors?.length ? '\nErros RTDB:\n' + json.rtdb_errors.join('\n') : '';
      showMsg('✓ ' + json.message + authInfo + secretInfo + (debugInfo ? '\n\nDebug RTDB:\n' + debugInfo : '') + errInfo, true);
      setTimeout(() => location.reload(), 2000);
    } else {
      showMsg('Erro: ' + json.message, false);
    }
  } catch (e) {
    showMsg('Erro de conexão: ' + e, false);
  }
}

function showMsg(text, ok) {
  const el = document.getElementById('reset-msg');
  el.innerText = text;
  el.style.whiteSpace = 'pre-wrap';
  el.className = ok ? 'ok' : 'err';
  el.style.display = 'block';
}
</script>
</body>
</html>
