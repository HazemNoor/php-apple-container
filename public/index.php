<?php

declare(strict_types=1);

$pdo = new PDO(
    sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', getenv('DB_HOST'), getenv('DB_NAME')),
    getenv('DB_USER'),
    getenv('DB_PASS'),
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
);

$pdo->exec('CREATE TABLE IF NOT EXISTS visits (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_agent VARCHAR(255) NOT NULL,
    visited_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
)');

$pdo->prepare('INSERT INTO visits (user_agent) VALUES (?)')
    ->execute([substr($_SERVER['HTTP_USER_AGENT'] ?? 'unknown', 0, 255)]);

$count  = (int) $pdo->query('SELECT COUNT(*) FROM visits')->fetchColumn();
$recent = $pdo->query('SELECT id, user_agent, visited_at FROM visits ORDER BY id DESC LIMIT 5')->fetchAll();
?>
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title><?= htmlspecialchars($_SERVER['HTTP_HOST'] ?? 'localhost') ?></title></head>
<body>
<h1>It works — Visits: <?= $count ?></h1>
<ul>
    <li>PHP <?= PHP_VERSION ?></li>
    <li><?= htmlspecialchars($_SERVER['SERVER_SOFTWARE'] ?? 'nginx') ?></li>
    <li>MySQL <?= htmlspecialchars($pdo->getAttribute(PDO::ATTR_SERVER_VERSION)) ?></li>
    <li>Xdebug <?= phpversion('xdebug') ?: 'not loaded' ?></li>
</ul>
<table border="1" cellpadding="4">
    <tr><th>#</th><th>User agent</th><th>When (UTC)</th></tr>
    <?php foreach ($recent as $v): ?>
    <tr>
        <td><?= $v['id'] ?></td>
        <td><?= htmlspecialchars($v['user_agent']) ?></td>
        <td><?= $v['visited_at'] ?></td>
    </tr>
    <?php endforeach ?>
</table>
</body>
</html>
