# freshrss-patches

Custom fixes, tweaks, and utilities for [FreshRSS](https://github.com/FreshRSS/FreshRSS) and [RSS-Bridge](https://github.com/RSS-Bridge/rss-bridge) not yet addressed upstream. Patches are idempotent and safe to run after each update.

## Upstream viability

| Item | PR candidate? | Summary |
|---|---|---|
| ~~Favicon RFP detection~~ | ~~**Strong**~~ | ~~Fixed upstream.~~ Replaced by [FreshRSS#8577](https://github.com/FreshRSS/FreshRSS/pull/8577) (SVG favicons). |
| Nord theme favicons | **Weak** | Cosmetic preference. Removes the favicon background and makes clipping circular. Style opinion, not a bug fix. |
| YoutubeBridge cache TTL | **Weak** | Mitigates [RSS-Bridge#2113](https://github.com/RSS-Bridge/rss-bridge/issues/2113). Largely redundant if paired with batched fetching (see utilities); more useful with stock refresh. Better suited as a user-configurable default than a hardcoded change. |
| nbUnreadsPerFeed hidden feed filter | **Strong** | Fixes a clear client/server mismatch causing an infinite notification loop. Small, safe change. [Issue filed upstream](https://github.com/FreshRSS/FreshRSS/issues/8694). |
| Nord nav_menu layout fixes | **Moderate** | Two Nord-specific layout bugs in the top-bar button row. [Issue filed upstream](https://github.com/FreshRSS/FreshRSS/issues/8707). |
| Batched feed fetch | **Moderate** | Utility, not a patch. Replaces the default refresh with a batched fetcher that prioritizes errored feeds. Upstream viability depends on whether FreshRSS wants this as a built-in scheduling mode. |
| YouTube channel avatars | **None** | Utility. Too deployment-specific for upstream (depends on local DB paths, salt, username). |

## Patches

### ~~Favicon: RFP (Resist Fingerprinting) detection~~

Resolved by [FreshRSS#8577](https://github.com/FreshRSS/FreshRSS/pull/8577) (merged 2026-03-08), which replaces the canvas-based favicon with SVG rendering. The original patch is no longer needed; kept in git history for reference.

### Nord theme: transparent circular favicons

**Files:** `p/themes/Nord/nord.css`, `p/themes/Nord/nord.rtl.css`

The default Nord theme places a light background (`var(--text-accent)`) behind feed favicons with `border-radius: 4px`. This creates a visible light rectangle behind transparent or circular favicons, particularly noticeable with custom YouTube channel avatars. The patch removes the background and sets `border-radius: 50%`.

**Before:** Light rectangle behind each favicon
**After:** No background, circular clipping

### RSS-Bridge: YoutubeBridge cache TTL (3h → 6h)

**File:** `bridges/YoutubeBridge.php`

YouTube rate-limits automated requests to `/feeds/videos.xml`, producing intermittent 404s when many feeds refresh simultaneously. See [RSS-Bridge#2113](https://github.com/RSS-Bridge/rss-bridge/issues/2113). Raising the cache TTL from 3 hours to 6 hours halves request frequency while remaining responsive (YouTube channels rarely post more than once a day).

### nbUnreadsPerFeed: exclude hidden feeds from notification poll

**File:** `app/views/javascript/nbUnreadsPerFeed.phtml`

FreshRSS polls `nbUnreadsPerFeed` every 2 minutes. The endpoint returns unread counts for all feeds, including hidden ones (priority < `PRIORITY_FEED`). The sidebar doesn't render DOM elements for hidden feeds, so `feed_unreads` defaults to 0 on the client. Any hidden feed with unreads triggers the "new articles available" banner every poll cycle, indefinitely. The patch filters hidden feeds from the JSON response.

See: [FreshRSS#8694](https://github.com/FreshRSS/FreshRSS/issues/8694)

### Nord theme: nav_menu layout fixes

**File:** `p/themes/Nord/nord.css`

Two small layout bugs in the Nord top button row: the sidebar toggle collides with the first button at narrow widths, and the mark-read dropdown loses its left border when the text button is hidden at `<=840px`.

See: [FreshRSS#8707](https://github.com/FreshRSS/FreshRSS/issues/8707) for full detail on both issues and the applied fixes.

## Utilities

Standalone scripts, not invoked by `freshrss-patch.sh`. Run manually or wire them into your own systemd units.

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
sudo FRESHRSS_DIR=/path/to/FreshRSS FRESHRSS_USER=myuser ./freshrss-fetch.sh
```

To install as a timer: copy `systemd/freshrss-fetch.*` to `/etc/systemd/system/`, put `freshrss-fetch.sh` on `PATH` (or edit the unit's `ExecStart`), then `systemctl enable --now freshrss-fetch.timer`. Disable FreshRSS's own refresh cron if you use this.

### YouTube channel avatar favicons

**Script:** `freshrss-yt-favicons.sh`

FreshRSS uses a generic RSS favicon for feeds coming through RSS-Bridge. For YouTube feeds, every channel ends up with the same icon. This script queries the FreshRSS SQLite database for YouTube feeds (including those wrapped in FilterBridge), fetches each channel's avatar, and saves it as a custom favicon using FreshRSS's salted hash naming convention. Designed to run monthly via systemd timer.

```bash
sudo ./freshrss-yt-favicons.sh
```

## Applying patches

```bash
# Default paths (/var/www/FreshRSS and /var/www/rss-bridge)
sudo ./freshrss-patch.sh

# Custom paths
sudo FRESHRSS_DIR=/path/to/FreshRSS RSSBRIDGE_DIR=/path/to/rss-bridge ./freshrss-patch.sh
```

The script checks whether each patch is needed before applying, so it's safe to run repeatedly (e.g. from a cron job or health check).

## Last verified

2026-04-20 against FreshRSS 1.28.2-dev, RSS-Bridge 2026-02-21, PHP 8.5, Debian 12 (Bookworm).

## A note on AI

Parts of this repository were written with the help of [Claude Code](https://docs.anthropic.com/en/docs/claude-code). I'm choosing to publish patches here rather than submit upstream PRs, because I think AI-assisted contributions to other projects deserve transparency and a space where the trade-offs can be documented honestly. If any of these patches prove useful and well-tested enough, proper upstream issues or PRs may follow, written or reviewed by a human.
