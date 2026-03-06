# freshrss-patches

Idempotent patch script for [FreshRSS](https://github.com/FreshRSS/FreshRSS) and [RSS-Bridge](https://github.com/RSS-Bridge/rss-bridge) that fixes issues not yet addressed upstream. Run after each update — patches are only applied when needed.

## Patches

### Favicon: RFP (Resist Fingerprinting) detection

**File:** `p/scripts/main.js`

FreshRSS dynamically generates its favicon via HTML5 canvas to overlay an unread article count. Browsers with Resist Fingerprinting enabled (LibreWolf, Firefox with arkenfox) corrupt the output of `canvas.toDataURL()`, producing a garbled striped image. FreshRSS doesn't detect this and replaces the good static favicon with corrupted data.

This patch adds a pixel verification check before the favicon is replaced: it draws a known red pixel on a test canvas and reads it back. If the color doesn't match (indicating RFP is active), the function returns early and the static favicon is preserved.

**Trade-off:** When RFP is active, the unread count badge on the favicon is disabled. The tab title still shows the unread count.

See: [FreshRSS#4091](https://github.com/FreshRSS/FreshRSS/issues/4091), [arkenfox/user.js#1317](https://github.com/arkenfox/user.js/issues/1317)

### Nord theme: transparent circular favicons

**Files:** `p/themes/Nord/nord.css`, `p/themes/Nord/nord.rtl.css`

The default Nord theme places a light background (`var(--text-accent)`, `#eceff4`) behind feed favicons with `border-radius: 4px`. This creates a visible light rectangle behind transparent or circular favicons — particularly noticeable with custom favicons like YouTube channel avatars.

This patch removes the background and sets `border-radius: 50%` for circular favicons.

**Before:** Light rectangle behind each favicon
**After:** No background, circular clipping

In practice, favicons remain clearly visible without the background rectangle regardless of whether they are transparent or opaque.

### RSS-Bridge: YoutubeBridge cache TTL (3h → 6h)

**File:** `bridges/YoutubeBridge.php`

YouTube rate-limits automated requests to its RSS feed endpoint (`/feeds/videos.xml`). When many feeds refresh simultaneously through RSS-Bridge, YouTube returns intermittent 404 errors. This is a [well-documented recurring issue](https://github.com/RSS-Bridge/rss-bridge/issues/2113) affecting any RSS-Bridge instance with multiple YouTube feeds.

Increasing the cache TTL from 3 hours to 6 hours halves the request frequency. YouTube channels rarely post more than once a day, so 6 hours remains responsive enough for feed readers.

## Usage

```bash
# Default paths (/var/www/FreshRSS and /var/www/rss-bridge)
sudo ./freshrss-patch.sh

# Custom paths
sudo FRESHRSS_DIR=/path/to/FreshRSS RSSBRIDGE_DIR=/path/to/rss-bridge ./freshrss-patch.sh
```

Run after each FreshRSS or RSS-Bridge update. The script checks whether each patch is needed before applying, so it's safe to run repeatedly (e.g. from a cron job or health check).

## Tested with

- FreshRSS 1.28.x
- RSS-Bridge 2025-08-05
- PHP 8.2 / 8.3
- Debian 12 (Bookworm)

## A note on AI

Parts of this repository were written with the help of [Claude Code](https://docs.anthropic.com/en/docs/claude-code). I'm choosing to publish patches here rather than submit upstream PRs, because I think AI-assisted contributions to other projects deserve transparency and a space where the trade-offs can be documented honestly. If any of these patches prove useful and well-tested enough, proper upstream issues or PRs may follow — written or reviewed by a human.
