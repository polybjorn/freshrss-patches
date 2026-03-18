# freshrss-patches

Custom fixes and tweaks for [FreshRSS](https://github.com/FreshRSS/FreshRSS) and [RSS-Bridge](https://github.com/RSS-Bridge/rss-bridge) not yet addressed upstream. Run after each update — changes are only applied when needed.

## Upstream viability

| Patch | PR candidate? | Summary |
|---|---|---|
| ~~Favicon RFP detection~~ | ~~**Strong**~~ | ~~Fixed upstream — FreshRSS now uses SVG favicons instead of canvas, avoiding the RFP issue entirely.~~ [Proposed upstream](https://github.com/FreshRSS/FreshRSS/issues/4091#issuecomment-4010452335), [merged in #8577](https://github.com/FreshRSS/FreshRSS/pull/8577). |
| Nord theme favicons | **Weak** | Cosmetic preference — removes the favicon background and makes clipping circular. Looks better to me, but it's a style opinion, not a bug fix. |
| YoutubeBridge cache TTL | **Weak** | Mitigates a well-documented rate-limiting issue ([RSS-Bridge#2113](https://github.com/RSS-Bridge/rss-bridge/issues/2113)), but the "right" default is debatable. 6 hours works for casual readers; users who want faster updates would disagree. Better suited as a user-configurable default than a hardcoded change. |
| YouTube channel avatars | **None** | Standalone utility script, not a patch. Fetches YouTube channel avatars and sets them as custom FreshRSS favicons for RSS-Bridge feeds. Too deployment-specific for upstream — depends on local DB paths, salt, and username. |

The Nord patch could go either way depending on maintainer taste. The TTL change is more of a personal tuning preference. The avatar script is a companion utility, not an upstream candidate.

## Patches

### ~~Favicon: RFP (Resist Fingerprinting) detection~~

> **Resolved upstream.** FreshRSS [#8577](https://github.com/FreshRSS/FreshRSS/pull/8577) replaced the canvas-based favicon with SVG rendering, which avoids the RFP issue entirely. Merged 2026-03-08.

<details>
<summary>Original patch (obsolete)</summary>

**File:** `p/scripts/main.js`

FreshRSS dynamically generates its favicon via HTML5 canvas to overlay an unread article count. Browsers with Resist Fingerprinting enabled (LibreWolf, Firefox with arkenfox) corrupt the output of `canvas.toDataURL()`, producing a garbled striped image. FreshRSS doesn't detect this and replaces the good static favicon with corrupted data.

This patch adds a pixel verification check before the favicon is replaced: it draws a known red pixel on a test canvas and reads it back. If the color doesn't match (indicating RFP is active), the function returns early and the static favicon is preserved.

**Trade-off:** When RFP is active, the unread count badge on the favicon is disabled. The tab title still shows the unread count.

See: [FreshRSS#4091](https://github.com/FreshRSS/FreshRSS/issues/4091) ([proposed upstream](https://github.com/FreshRSS/FreshRSS/issues/4091#issuecomment-4010452335)), [arkenfox/user.js#1317](https://github.com/arkenfox/user.js/issues/1317)

</details>

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

### YouTube channel avatar favicons

**Script:** `freshrss-yt-favicons.sh`

FreshRSS uses generic RSS favicons for feeds coming through RSS-Bridge, since the bridge URL has no associated favicon. For YouTube feeds, this means every channel shows the same icon.

This script queries the FreshRSS SQLite database for YouTube feeds (including those wrapped in FilterBridge), fetches each channel's avatar from the channel page, and saves it as a custom favicon using FreshRSS's salted hash naming convention.

Designed to run monthly via systemd timer — channel avatars rarely change.

```bash
sudo ./freshrss-yt-favicons.sh
```

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
