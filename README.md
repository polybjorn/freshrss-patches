# freshrss-patches

Custom fixes, tweaks, and utilities for [FreshRSS](https://github.com/FreshRSS/FreshRSS) and [RSS-Bridge](https://github.com/RSS-Bridge/rss-bridge) not yet addressed upstream. Patches are idempotent and safe to run after each update.

| Type | Item | Files |
|---|---|---|
| Patch | Nord theme: transparent circular favicons | `nord.css`, `nord.rtl.css` |
| Patch | YoutubeBridge cache TTL (3h -> 6h) | `YoutubeBridge.php` |
| Utility | Batched feed fetch | `freshrss-fetch.{sh,php}` + systemd units |
| Utility | YouTube channel avatar favicons | `freshrss-yt-favicons.sh` + systemd units |

Patches are reapplied via `freshrss-patch.sh` after upstream updates. Utilities are standalone scripts.

## Patches

### Nord theme: transparent circular favicons

**Files:** `p/themes/Nord/nord.css`, `p/themes/Nord/nord.rtl.css`

The default Nord theme places a light background (`var(--text-accent)`) behind feed favicons with `border-radius: 4px`. This creates a visible light rectangle behind transparent or circular favicons, particularly noticeable with custom YouTube channel avatars. The patch removes the background and sets `border-radius: 50%`.

**Before:** Light rectangle behind each favicon
**After:** No background, circular clipping

### RSS-Bridge: YoutubeBridge cache TTL (3h -> 6h)

**File:** `bridges/YoutubeBridge.php`

YouTube rate-limits automated requests to `/feeds/videos.xml`, producing intermittent 404s when many feeds refresh simultaneously. See [RSS-Bridge#2113](https://github.com/RSS-Bridge/rss-bridge/issues/2113). Raising the cache TTL from 3 hours to 6 hours halves request frequency while remaining responsive (YouTube channels rarely post more than once a day).

## Utilities

Standalone scripts, not invoked by `freshrss-patch.sh`. Run manually or use the systemd units shipped in `systemd/`.

### Batched feed fetch

**Scripts:** `freshrss-fetch.php`, `freshrss-fetch.sh`
**Systemd:** `systemd/freshrss-fetch.service`, `systemd/freshrss-fetch.timer`

FreshRSS's default refresh runs every feed on the same interval and in parallel. For instances with many feeds (especially YouTube feeds via RSS-Bridge), this produces refresh bursts that invite rate-limiting. This script fetches a small batch per tick instead:

1. Retry errored (non-muted) feeds first, up to the batch size.
2. Fill remaining slots with the oldest feeds (FreshRSS's default ordering).

Paired with a 10-minute timer and a batch size of 15, roughly 90 feeds cycle per hour with naturally staggered requests. Errored feeds get retried on the next tick instead of waiting for the full cycle.

```bash
# Manual run; the wrapper invokes php as www-data
sudo ./freshrss-fetch.sh 15

# Env overrides if your install lives elsewhere
sudo FRESHRSS_DIR=/path/to/FreshRSS ./freshrss-fetch.sh
```

`FRESHRSS_USER` is auto-detected from `data/users/`; set it explicitly only for multi-user installs.

To install as a timer: copy `systemd/freshrss-fetch.*` to `/etc/systemd/system/`, put `freshrss-fetch.sh` on `PATH` (or edit the unit's `ExecStart`), then `systemctl enable --now freshrss-fetch.timer`. Disable FreshRSS's own refresh cron if you use this.

### YouTube channel avatar favicons

**Script:** `freshrss-yt-favicons.sh`
**Systemd:** `systemd/freshrss-yt-favicons.service`, `systemd/freshrss-yt-favicons.timer`

FreshRSS uses a generic RSS favicon for feeds coming through RSS-Bridge. For YouTube feeds, every channel ends up with the same icon. This script queries the FreshRSS SQLite database for YouTube feeds (including those wrapped in FilterBridge), fetches each channel's avatar, and saves it as a custom favicon using FreshRSS's salted hash naming convention.

```bash
sudo ./freshrss-yt-favicons.sh

# Env overrides if your install lives elsewhere
sudo FRESHRSS_DIR=/path/to/FreshRSS ./freshrss-yt-favicons.sh
```

`FRESHRSS_USER` is auto-detected from `data/users/`; set it explicitly only for multi-user installs. The shipped timer runs monthly (1st of month, 04:00); channel avatars rarely change.

## Applying patches

```bash
# Default paths (/var/www/FreshRSS and /var/www/rss-bridge)
sudo ./freshrss-patch.sh

# Custom paths
sudo FRESHRSS_DIR=/path/to/FreshRSS RSSBRIDGE_DIR=/path/to/rss-bridge ./freshrss-patch.sh
```

The script checks whether each patch is needed before applying, so it's safe to run repeatedly (e.g. from a cron job or health check).

To add a new patch: define an `apply_*` function in `freshrss-patch.sh`, call it from `main`, document it in this README.

## Last verified

2026-05-01 against FreshRSS 1.28.2-dev, RSS-Bridge 2026-02-21, PHP 8.5.5, Debian 12 (Bookworm).
