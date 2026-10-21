<?php
/**
 * Minimal heartbeat receiver. Put it on any PHP host, point services.monitoring.url at it.
 *   POST  {device, status, metrics[, static]}  with  Authorization: Bearer <token>   → stored as data/<device>.json
 *         "static" (os, versions, config summary) comes once a day; the stored copy is kept when it is absent.
 *   GET                                                                   → HTML table of all devices
 * Set TOKEN below (same as MONITORING_TOKEN in /opt/kiosk/secrets/monitoring.env) and make data/ writable.
 */
const TOKEN = 'change-me';
const DATA_DIR = __DIR__ . '/data';
const STALE_MIN = 15;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (TOKEN !== '' && $auth !== 'Bearer ' . TOKEN) { http_response_code(401); exit("unauthorized\n"); }
    $body = json_decode(file_get_contents('php://input'), true);
    $device = preg_replace('/[^a-zA-Z0-9_.-]/', '', $body['device'] ?? '');
    if ($device === '' || !is_array($body)) { http_response_code(400); exit("bad request\n"); }
    if (!is_dir(DATA_DIR)) mkdir(DATA_DIR, 0750, true);
    $body['received'] = date('c');
    $file = DATA_DIR . "/$device.json";
    if (!isset($body['static']) && is_file($file)) {
        $old = json_decode(file_get_contents($file), true);
        if (isset($old['static'])) $body['static'] = $old['static'];
    }
    file_put_contents($file, json_encode($body, JSON_PRETTY_PRINT), LOCK_EX);
    exit("ok\n");
}

$rows = [];
foreach (glob(DATA_DIR . '/*.json') ?: [] as $f) {
    $d = json_decode(file_get_contents($f), true);
    if ($d) $rows[] = $d;
}
usort($rows, fn($a, $b) => strcmp($a['device'] ?? '', $b['device'] ?? ''));
$e = fn($v) => htmlspecialchars((string)($v ?? ''), ENT_QUOTES);
?>
<!doctype html><meta charset="utf-8"><title>Kiosks</title>
<meta http-equiv="refresh" content="60">
<style>body{font:14px system-ui;margin:2em}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:.3em .6em;text-align:left}.stale{background:#fdd}.ok{background:#dfd}</style>
<h1>Kiosks</h1>
<table><tr><th>device</th><th>last seen</th><th>uptime</th><th>version</th><th>persistence</th><th>cpu °C</th><th>gpu °C</th><th>mem %</th><th>disk /</th><th>apps</th><th>ip</th></tr>
<?php foreach ($rows as $r):
    $age = (time() - strtotime($r['received'] ?? '1970-01-01')) / 60;
    $s = $r['status'] ?? []; $m = $r['metrics'] ?? []; $st = $r['static'] ?? [];
    $apps = implode(' ', array_map(fn($a) => $a['name'] . ':' . $a['state'], $s['apps'] ?? []));
?>
<tr class="<?= $age > STALE_MIN ? 'stale' : 'ok' ?>">
<td><?= $e($r['device']) ?></td><td><?= $e($r['received']) ?> (<?= round($age) ?> min)</td>
<td><?= $e($s['uptime']) ?></td><td><?= $e($st['version'] ?? $s['version'] ?? '') ?></td><td><?= $e($st['persistence'] ?? $s['persistence'] ?? '') ?></td>
<td><?= $e($m['cpu_temp']) ?></td><td><?= $e($m['gpu_temp']) ?></td><td><?= $e($m['mem_pct']) ?></td><td><?= $e($m['disk_root']) ?>%</td>
<td><?= $e($apps) ?></td><td><?= $e($s['ip']) ?></td>
</tr>
<?php endforeach; ?>
</table>
