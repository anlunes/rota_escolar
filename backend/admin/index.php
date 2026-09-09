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

    if ($id && $tabela === 'cnh') {
        $pdo = Database::getInstance();
        if ($acao === 'aprovar') {
            $pdo->prepare("UPDATE motoristas SET cnh_ocr_verificado = 1, updated_at = NOW() WHERE motorista_id = ?")
                ->execute([$id]);
        } elseif ($acao === 'rejeitar') {
            // Remove a CNH e zera o flag para o motorista ter que reenviar
            $pdo->prepare("UPDATE motoristas SET cnh_url = NULL, cnh_ocr_verificado = 0, updated_at = NOW() WHERE motorista_id = ?")
                ->execute([$id]);
        }
        header('Location: index.php');
        exit;
    }

    if ($id && in_array($acao, ['aprovar', 'rejeitar', 'aprovar_coords'])) {
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
            } elseif ($acao === 'aprovar_coords') {
                // Aprovação manual com lat/lon digitados pelo admin
                $lat = isset($_POST['lat']) ? (float)$_POST['lat'] : null;
                $lon = isset($_POST['lon']) ? (float)$_POST['lon'] : null;
                if ($lat && $lon) {
                    $pdo->prepare("
                        UPDATE escolas
                        SET status = 'ativo', lat = ?, lon = ?, geocode_fonte = 'manual_admin'
                        WHERE escola_id = ?
                    ")->execute([$lat, $lon, $id]);
                }
            } else {
                $pdo->prepare("UPDATE escolas SET status = 'rejeitada' WHERE escola_id = ?")->execute([$id]);
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

// Escolas pendentes com endereço preenchido pelo pai (aguardando aprovação)
try {
    $escolasPendentes = $pdo->query("
        SELECT escola_id, nome,
               COALESCE(logradouro, '')  AS logradouro,
               COALESCE(municipio, '')   AS municipio,
               COALESCE(estado, '')      AS estado
        FROM escolas
        WHERE status = 'pendente'
          AND logradouro IS NOT NULL AND logradouro != ''
        ORDER BY escola_id DESC
    ")->fetchAll();
} catch (Throwable $e) {
    $escolasPendentes = [];
    $escolasErro = $e->getMessage();
}

// Escolas verificadas automaticamente (script achou coords, aguarda aprovação admin)
try {
    $escolasVerificadas = $pdo->query("
        SELECT escola_id, nome,
               COALESCE(bairro, '')      AS bairro,
               COALESCE(municipio, '')   AS municipio,
               COALESCE(estado, '')      AS estado,
               lat, lon, geocode_fonte
        FROM escolas
        WHERE status = 'verificado'
          AND lat IS NOT NULL
        ORDER BY escola_id DESC
    ")->fetchAll();
} catch (Throwable $e) {
    $escolasVerificadas = [];
}

// Escolas com endereço informado pelo pai — aguardando coordenadas do admin
try {
    $escolasComEndereco = $pdo->query("
        SELECT escola_id, nome,
               COALESCE(logradouro, '') AS logradouro,
               COALESCE(municipio, '')  AS municipio,
               COALESCE(estado, '')     AS estado
        FROM escolas
        WHERE logradouro IS NOT NULL AND logradouro != ''
          AND (lat IS NULL OR lon IS NULL)
        ORDER BY escola_id DESC
    ")->fetchAll();
} catch (Throwable $e) {
    $escolasComEndereco = [];
}

// Orçamentos com endereço residencial pendente de confirmação
try {
    $orcamentosPendentes = $pdo->query("
        SELECT so.id, so.aluno_id, so.created_at,
               a.nome AS aluno_nome,
               COALESCE(a.logradouro, '')          AS logradouro,
               COALESCE(a.numero_residencia, '')   AS numero,
               COALESCE(a.bairro_residencia, '')   AS bairro,
               COALESCE(a.cep_residencia, '')      AS cep,
               u.nome AS motorista_nome
        FROM solicitacoes_orcamento so
        JOIN alunos a      ON a.aluno_id       = so.aluno_id
        JOIN motoristas m  ON m.motorista_id   = so.motorista_id
        JOIN usuarios u    ON u.uid            = m.uid
        WHERE so.status = 'pendente'
          AND (a.lat_residencia IS NULL OR a.lon_residencia IS NULL)
        ORDER BY so.created_at ASC
    ")->fetchAll();
} catch (Throwable $e) {
    $orcamentosPendentes = [];
}

// CNH enviadas por foto (OCR não verificou CPF — revisão manual)
try {
    $cnhPendentes = $pdo->query("
        SELECT m.motorista_id, u.nome, m.cnh_url, m.cpf,
               m.email, m.telefone, m.created_at
        FROM motoristas m
        JOIN usuarios u ON u.uid = m.uid
        WHERE m.cnh_ocr_verificado = 0
          AND m.cnh_url IS NOT NULL
          AND m.cnh_url != ''
        ORDER BY m.created_at DESC
    ")->fetchAll();
} catch (Throwable $e) {
    $cnhPendentes = [];
}

// Escolas não encontradas pelo script (revisão manual com Street View)
try {
    $escolasNaoEncontradas = $pdo->query("
        SELECT escola_id, nome,
               COALESCE(bairro, '')      AS bairro,
               COALESCE(logradouro, '')  AS logradouro,
               COALESCE(numero, '')      AS numero,
               COALESCE(cep, '')         AS cep,
               COALESCE(municipio, '')   AS municipio,
               COALESCE(estado, '')      AS estado
        FROM escolas
        WHERE status = 'nao_encontrado'
        ORDER BY escola_id DESC
    ")->fetchAll();
} catch (Throwable $e) {
    $escolasNaoEncontradas = [];
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

  /* Fila de revisão de escolas */
  .badge-ok  { background: #27ae60; color: #fff; font-size: .75rem; padding: 2px 8px; border-radius: 99px; font-weight: 600; }
  .badge-warn{ background: #e67e22; color: #fff; font-size: .75rem; padding: 2px 8px; border-radius: 99px; font-weight: 600; }
  .coords-tag { font-size: .78rem; color: #27ae60; font-family: monospace; }
  .btn-link {
    background: none; border: 1px solid #2c7be5; color: #2c7be5;
    padding: 5px 10px; border-radius: 6px; cursor: pointer; font-size: .82rem;
    text-decoration: none; display: inline-block;
  }
  .btn-link:hover { background: #eaf1fb; }
  .coords-input-group { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
  .coords-input-group input {
    width: 130px; padding: 5px 8px; border: 1px solid #ddd;
    border-radius: 6px; font-size: .85rem; font-family: monospace;
  }
  .coords-input-group input:focus { outline: 2px solid #2c7be5; border-color: transparent; }
</style>
</head>
<body>

<header>
  <h1>🚌 Rota Escolar — Admin</h1>
  <a href="?logout=1">Sair</a>
</header>

<main>

  <!-- Endereços residenciais pendentes de confirmação -->
  <div class="section">
    <div class="section-title">
      📍 Endereços residenciais aguardando confirmação
      <?php if (!empty($orcamentosPendentes)): ?>
        <span class="badge"><?= count($orcamentosPendentes) ?></span>
      <?php endif; ?>
    </div>

    <?php if (empty($orcamentosPendentes)): ?>
      <p class="empty">Nenhum endereço pendente.</p>
    <?php else: ?>
      <table>
        <thead>
          <tr>
            <th>Aluno</th>
            <th>Endereço</th>
            <th>Motorista</th>
            <th>Coordenadas (Google Maps)</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <?php foreach ($orcamentosPendentes as $o): ?>
          <tr>
            <td><?= htmlspecialchars($o['aluno_nome']) ?></td>
            <td>
              <?= htmlspecialchars(implode(', ', array_filter([
                  $o['logradouro'],
                  $o['numero'] ? 'nº ' . $o['numero'] : '',
                  $o['bairro'],
                  $o['cep'],
              ]))) ?>
              <br>
              <a class="btn-link" style="margin-top:4px;font-size:.78rem"
                 href="https://maps.google.com/?q=<?= urlencode(implode(', ', array_filter([$o['logradouro'], $o['numero'], $o['bairro']]))) ?>"
                 target="_blank">🗺 Abrir no Maps</a>
            </td>
            <td><?= htmlspecialchars($o['motorista_nome']) ?></td>
            <td>
              <div class="coords-input-group">
                <input type="text" id="lat_res_<?= $o['id'] ?>" placeholder="Latitude"
                       title="Cole aqui: -22.8793, -43.3568 — preenche os dois automaticamente">
                <input type="text" id="lon_res_<?= $o['id'] ?>" placeholder="Longitude">
              </div>
              <small style="color:#888;font-size:.74rem">
                Maps → pressione longamente → copie as coordenadas
              </small>
            </td>
            <td>
              <button class="btn-aprovar" onclick="confirmarResidencia(<?= $o['id'] ?>)">
                ✓ Confirmar
              </button>
            </td>
          </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    <?php endif; ?>
  </div>

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

  <!-- CNH pendentes de revisão manual -->
  <div class="section">
    <div class="section-title">
      CNH — Revisão Manual de CPF
      <?php if (!empty($cnhPendentes)): ?>
        <span class="badge" style="background:#e67e22"><?= count($cnhPendentes) ?></span>
      <?php endif; ?>
    </div>
    <p style="font-size:.85rem;color:#666;margin-bottom:12px">
      Motoristas que enviaram a CNH por foto (não PDF). O OCR não conseguiu verificar o CPF automaticamente — revise a imagem e o CPF informado.
    </p>

    <?php if (empty($cnhPendentes)): ?>
      <p class="empty">Nenhuma CNH aguardando revisão.</p>
    <?php else: ?>
      <table>
        <thead>
          <tr><th>Motorista</th><th>CPF informado</th><th>CNH</th><th>Ações</th></tr>
        </thead>
        <tbody>
          <?php foreach ($cnhPendentes as $c): ?>
          <?php
            $cpfFormatado = '';
            $cpfRaw = preg_replace('/\D/', '', $c['cpf'] ?? '');
            if (strlen($cpfRaw) === 11) {
                $cpfFormatado = substr($cpfRaw,0,3).'.'.substr($cpfRaw,3,3).'.'.substr($cpfRaw,6,3).'-'.substr($cpfRaw,9,2);
            } else {
                $cpfFormatado = $c['cpf'] ? htmlspecialchars($c['cpf']) : '<em style="color:#aaa">Não informado</em>';
            }
          ?>
          <tr>
            <td>
              <strong><?= htmlspecialchars($c['nome']) ?></strong><br>
              <small style="color:#888"><?= htmlspecialchars($c['email'] ?? '') ?></small>
            </td>
            <td><?= $cpfFormatado ?></td>
            <td>
              <?php if ($c['cnh_url']): ?>
                <a href="<?= htmlspecialchars($c['cnh_url']) ?>" target="_blank"
                   style="color:#2980b9;font-size:.85rem">🔍 Ver CNH</a>
              <?php else: ?>
                <em style="color:#aaa">Sem arquivo</em>
              <?php endif; ?>
            </td>
            <td>
              <div class="actions">
                <form method="POST" style="display:inline"
                      onsubmit="return confirm('Confirmar que o CPF da CNH está correto?')">
                  <input type="hidden" name="id"     value="<?= $c['motorista_id'] ?>">
                  <input type="hidden" name="acao"   value="aprovar">
                  <input type="hidden" name="tabela" value="cnh">
                  <button class="btn-aprovar" type="submit">✓ CPF OK</button>
                </form>
                <form method="POST" style="display:inline"
                      onsubmit="return confirm('Rejeitar CNH? O motorista terá que reenviar o documento.')">
                  <input type="hidden" name="id"     value="<?= $c['motorista_id'] ?>">
                  <input type="hidden" name="acao"   value="rejeitar">
                  <input type="hidden" name="tabela" value="cnh">
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
          <tr><th>#</th><th>Escola</th><th>Endereço</th><th>Verificar</th><th>Lat / Lon</th><th>Ações</th></tr>
        </thead>
        <tbody>
          <?php foreach ($escolasPendentes as $e):
            $searchQuery = urlencode($e['nome'] . ' ' . $e['logradouro'] . ' ' . $e['municipio']);
            $mapsUrl     = 'https://www.google.com/maps/search/?api=1&query=' . $searchQuery;
          ?>
          <tr>
            <td><?= $e['escola_id'] ?></td>
            <td><?= htmlspecialchars($e['nome']) ?></td>
            <td style="font-size:.85rem">
              <?= htmlspecialchars($e['logradouro']) ?>
              <br><span style="color:#aaa"><?= htmlspecialchars($e['municipio']) ?>/<?= htmlspecialchars($e['estado']) ?></span>
            </td>
            <td>
              <a class="btn-link" href="<?= $mapsUrl ?>" target="_blank">📍 Ver no Maps</a>
            </td>
            <td>
              <div class="coords-input-group">
                <input type="text" id="lat_pend_<?= $e['escola_id'] ?>" placeholder="-22.9035" title="Latitude">
                <input type="text" id="lon_pend_<?= $e['escola_id'] ?>" placeholder="-43.1731" title="Longitude">
                <small style="color:#aaa;font-size:.75rem">Cole "lat, lon" do Maps no 1º campo</small>
              </div>
            </td>
            <td>
              <div class="actions" style="flex-direction:column;gap:6px">
                <button class="btn-aprovar" type="button"
                        onclick="aprovarComCoords(<?= $e['escola_id'] ?>,'pend')">✓ Salvar e aprovar</button>
                <form method="POST" style="display:inline"
                      onsubmit="return confirm('Rejeitar esta escola?')">
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

  <!-- Escolas com endereço informado pelo pai — aguardando coords -->
  <?php if (!empty($escolasComEndereco)): ?>
  <div class="section">
    <div class="section-title">
      Escolas com endereço — aguardando coordenadas
      <span class="badge-warn"><?= count($escolasComEndereco) ?></span>
      <span style="font-size:.8rem;color:#888;font-weight:400">&nbsp;— endereço informado pelo responsável, confirme no Maps e insira lat/lon</span>
    </div>
    <table>
      <thead>
        <tr><th>#</th><th>Escola</th><th>Endereço informado</th><th>Verificar</th><th>Lat / Lon</th><th>Ações</th></tr>
      </thead>
      <tbody>
        <?php foreach ($escolasComEndereco as $e):
          $searchQuery = urlencode($e['nome'] . ' ' . $e['logradouro'] . ' ' . $e['municipio']);
          $mapsUrl     = 'https://www.google.com/maps/search/?api=1&query=' . $searchQuery;
        ?>
        <tr>
          <td><?= $e['escola_id'] ?></td>
          <td><?= htmlspecialchars($e['nome']) ?></td>
          <td style="font-size:.85rem">
            <?= htmlspecialchars($e['logradouro']) ?>
            <?php if ($e['municipio']): ?>
              <br><span style="color:#aaa"><?= htmlspecialchars($e['municipio']) ?>/<?= htmlspecialchars($e['estado']) ?></span>
            <?php endif; ?>
          </td>
          <td>
            <a class="btn-link" href="<?= $mapsUrl ?>" target="_blank">📍 Ver no Maps</a>
          </td>
          <td>
            <div class="coords-input-group">
              <input type="text" id="lat_ce_<?= $e['escola_id'] ?>" placeholder="-22.9035" title="Latitude">
              <input type="text" id="lon_ce_<?= $e['escola_id'] ?>" placeholder="-43.1731" title="Longitude">
              <small style="color:#aaa;font-size:.75rem">Cole "lat, lon" do Maps no 1º campo</small>
            </div>
          </td>
          <td>
            <div class="actions" style="flex-direction:column;gap:6px">
              <button class="btn-aprovar" type="button"
                      onclick="aprovarComCoords(<?= $e['escola_id'] ?>,'ce')">✓ Salvar e aprovar</button>
              <form method="POST" style="display:inline"
                    onsubmit="return confirm('Rejeitar esta escola?')">
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
  </div>
  <?php endif; ?>

  <!-- Escolas verificadas automaticamente -->
  <?php if (!empty($escolasVerificadas)): ?>
  <div class="section">
    <div class="section-title">
      Escolas verificadas automaticamente
      <span class="badge-ok"><?= count($escolasVerificadas) ?></span>
      <span style="font-size:.8rem;color:#888;font-weight:400">&nbsp;— coordenadas encontradas pelo script, aguardando aprovação</span>
    </div>
    <table>
      <thead>
        <tr><th>#</th><th>Escola</th><th>Município</th><th>Coordenadas</th><th>Fonte</th><th>Ações</th></tr>
      </thead>
      <tbody>
        <?php foreach ($escolasVerificadas as $e):
          $mapsUrl = 'https://www.google.com/maps/search/?api=1&query=' . urlencode($e['nome'] . ' ' . $e['municipio']);
        ?>
        <tr>
          <td><?= $e['escola_id'] ?></td>
          <td><?= htmlspecialchars($e['nome']) ?></td>
          <td><?= htmlspecialchars($e['municipio']) ?>/<?= htmlspecialchars($e['estado']) ?></td>
          <td class="coords-tag"><?= $e['lat'] ?>, <?= $e['lon'] ?></td>
          <td style="font-size:.8rem;color:#888"><?= htmlspecialchars($e['geocode_fonte'] ?? '') ?></td>
          <td>
            <div class="actions" style="flex-wrap:wrap;gap:6px">
              <a class="btn-link" href="https://www.google.com/maps?q=<?= $e['lat'] ?>,<?= $e['lon'] ?>" target="_blank">📍 Ver no Maps</a>
              <form method="POST" style="display:inline">
                <input type="hidden" name="id"     value="<?= $e['escola_id'] ?>">
                <input type="hidden" name="acao"   value="aprovar">
                <input type="hidden" name="tabela" value="escolas">
                <button class="btn-aprovar" type="submit">✓ Aprovar</button>
              </form>
              <form method="POST" style="display:inline"
                    onsubmit="return confirm('Rejeitar esta escola?')">
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
  </div>
  <?php endif; ?>

  <!-- Escolas não encontradas — revisão manual -->
  <?php if (!empty($escolasNaoEncontradas)): ?>
  <div class="section">
    <div class="section-title">
      Escolas não encontradas — revisão manual
      <span class="badge-warn"><?= count($escolasNaoEncontradas) ?></span>
      <span style="font-size:.8rem;color:#888;font-weight:400">&nbsp;— informe lat/lon após verificar no Street View</span>
    </div>
    <table>
      <thead>
        <tr><th>#</th><th>Escola</th><th>Endereço informado</th><th>Verificar</th><th>Lat / Lon</th><th>Ações</th></tr>
      </thead>
      <tbody>
        <?php foreach ($escolasNaoEncontradas as $e):
          $enderecoCompleto = trim(implode(', ', array_filter([
              $e['logradouro'],
              $e['numero'] ? 'nº ' . $e['numero'] : '',
              $e['bairro'],
              $e['municipio'],
              $e['estado'],
          ])));
          $searchQuery   = urlencode($e['nome'] . ' ' . $e['municipio'] . ' ' . $e['estado']);
          $streetQuery   = urlencode($enderecoCompleto . ', Brasil');
          $mapsSearchUrl = 'https://www.google.com/maps/search/?api=1&query=' . $searchQuery;
          $streetViewUrl = 'https://www.google.com/maps?q=' . $streetQuery . '&layer=c';
        ?>
        <tr>
          <td><?= $e['escola_id'] ?></td>
          <td><?= htmlspecialchars($e['nome']) ?></td>
          <td style="font-size:.82rem">
            <?= htmlspecialchars($enderecoCompleto) ?>
            <?php if ($e['cep']): ?><br><span style="color:#aaa">CEP <?= htmlspecialchars($e['cep']) ?></span><?php endif; ?>
          </td>
          <td style="white-space:nowrap">
            <a class="btn-link" href="<?= $mapsSearchUrl ?>" target="_blank" style="display:block;margin-bottom:4px">🔍 Buscar escola</a>
            <a class="btn-link" href="<?= $streetViewUrl ?>" target="_blank">🚶 Street View</a>
          </td>
          <td>
            <div class="coords-input-group">
              <input type="text" id="lat_<?= $e['escola_id'] ?>" placeholder="-22.9035" title="Latitude">
              <input type="text" id="lon_<?= $e['escola_id'] ?>" placeholder="-43.1731" title="Longitude">
              <small style="color:#aaa;font-size:.75rem">Cole do Maps</small>
            </div>
          </td>
          <td>
            <div class="actions" style="flex-direction:column;gap:6px">
              <button class="btn-aprovar" type="button"
                      onclick="aprovarComCoords(<?= $e['escola_id'] ?>,'')">✓ Salvar e aprovar</button>
              <form method="POST" style="display:inline"
                    onsubmit="return confirm('Rejeitar esta escola?')">
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
  </div>
  <?php endif; ?>

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

// Confirma coordenadas de residência via AJAX
async function confirmarResidencia(id) {
  const latInput = document.getElementById('lat_res_' + id);
  const lonInput = document.getElementById('lon_res_' + id);
  const lat = latInput.value.trim().replace(',', '.');
  const lon = lonInput.value.trim().replace(',', '.');

  if (!lat || !lon || isNaN(parseFloat(lat)) || isNaN(parseFloat(lon))) {
    alert('Informe latitude e longitude antes de confirmar.\n\nDica: no Google Maps, pressione longamente no local e copie as coordenadas que aparecem no topo do menu.');
    return;
  }
  if (!confirm('Confirmar coordenadas (' + lat + ', ' + lon + ') para este aluno?')) return;

  try {
    const res = await fetch('../api/admin/confirm_residencia.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ solicitacao_id: id, lat: parseFloat(lat), lon: parseFloat(lon) }),
    });
    const json = await res.json();
    if (json.success) {
      alert('✓ Coordenadas salvas! O orçamento será entregue ao responsável na próxima consulta.');
      location.reload();
    } else {
      alert('Erro: ' + json.message);
    }
  } catch (e) {
    alert('Erro de conexão: ' + e);
  }
}

// Detecta paste no formato "lat, lon" do Google Maps e preenche os dois campos
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('input[id^="lat_"]').forEach(latInput => {
    latInput.addEventListener('paste', (e) => {
      const text = (e.clipboardData || window.clipboardData).getData('text').trim();
      // Formato Google Maps: "-22.879304955882514, -43.356891195031714"
      const match = text.match(/^(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)$/);
      if (match) {
        e.preventDefault();
        const lonId = latInput.id.replace(/^lat_/, 'lon_');
        const lonInput = document.getElementById(lonId);
        latInput.value = match[1];
        if (lonInput) lonInput.value = match[2];
        latInput.style.background = '#eafaf1';
        if (lonInput) lonInput.style.background = '#eafaf1';
        setTimeout(() => {
          latInput.style.background = '';
          if (lonInput) lonInput.style.background = '';
        }, 1500);
      }
    });
  });
});

function aprovarComCoords(id, prefixo) {
  const pref = prefixo ? 'lat_' + prefixo + '_' : 'lat_';
  const lat = document.getElementById(pref + id).value.trim().replace(',', '.');
  const lon = document.getElementById((prefixo ? 'lon_' + prefixo + '_' : 'lon_') + id).value.trim().replace(',', '.');

  if (!lat || !lon || isNaN(parseFloat(lat)) || isNaN(parseFloat(lon))) {
    alert('Informe latitude e longitude antes de aprovar.\n\nDica: no Google Maps, clique com o botão direito no ponto e copie as coordenadas que aparecem no topo do menu.');
    return;
  }

  if (!confirm('Salvar coordenadas (' + lat + ', ' + lon + ') e aprovar esta escola?')) return;

  const form = document.createElement('form');
  form.method = 'POST';
  [['id', id], ['acao', 'aprovar_coords'], ['tabela', 'escolas'], ['lat', lat], ['lon', lon]].forEach(([k, v]) => {
    const inp = document.createElement('input');
    inp.type = 'hidden'; inp.name = k; inp.value = v;
    form.appendChild(inp);
  });
  document.body.appendChild(form);
  form.submit();
}
</script>
</body>
</html>
