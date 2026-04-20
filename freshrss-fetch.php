#!/usr/bin/env php
<?php
// Batched FreshRSS feed fetcher, intended to run frequently via a systemd timer.
// Priority 1: retry errored (non-muted) feeds.
// Priority 2: fill remaining slots with the oldest feeds (FreshRSS's default order).
//
// Usage: sudo -u www-data php freshrss-fetch.php [max_feeds]
// Env:   FRESHRSS_DIR (default /var/www/FreshRSS)
//        FRESHRSS_USER (default freshrss)

declare(strict_types=1);

$freshrssDir = getenv('FRESHRSS_DIR') ?: '/var/www/FreshRSS';
$freshrssUser = getenv('FRESHRSS_USER') ?: 'freshrss';

require $freshrssDir . '/cli/_cli.php';

$maxFeeds = (int)($argv[1] ?? 15);

performRequirementCheck(FreshRSS_Context::systemConf()->db['type'] ?? '');

$username = cliInitUser($freshrssUser);

$totalUpdated = 0;
$totalNew = 0;

$feedDAO = FreshRSS_Factory::createFeedDao();
$allFeeds = $feedDAO->listFeeds();
$erroredIds = [];
foreach ($allFeeds as $feed) {
  if ($feed->inError() && !$feed->mute()) {
    $erroredIds[] = $feed->id();
  }
}

$errorCount = 0;
foreach ($erroredIds as $id) {
  if ($totalUpdated >= $maxFeeds) break;
  [$updated, , $newArticles] = FreshRSS_feed_Controller::actualizeFeedsAndCommit($id);
  $totalUpdated += $updated;
  $totalNew += $newArticles;
  if ($updated > 0) $errorCount++;
}

$remaining = $maxFeeds - $totalUpdated;
if ($remaining > 0) {
  [$updated, , $newArticles] = FreshRSS_feed_Controller::actualizeFeedsAndCommit(null, null, $remaining);
  $totalUpdated += $updated;
  $totalNew += $newArticles;
}

if ($errorCount > 0) {
  echo "Retried $errorCount errored feed(s), ";
}
echo "Actualized $totalUpdated feeds ($totalNew new articles)\n";

invalidateHttpCache($username);

done($totalUpdated > 0);
