# CrazyGames Basic Launch — Compliance Checklist

This document maps the game to the published CrazyGames submission requirements.
Target: **Basic Launch** (monetization disabled, SDK optional). Built so Full
Launch can be enabled later without rework.

## Technical

| Requirement | Limit | This game | Status |
| --- | --- | --- | --- |
| Total file size | ≤ 250 MB | ~108 KB | ✅ |
| Initial download | ≤ 50 MB (≤ 20 MB mobile homepage) | ~108 KB | ✅ |
| File count | ≤ 1500 | 3 | ✅ |
| Time-to-gameplay | ≤ 20 s | Instant | ✅ |
| Paths | relative only | `base: './'` → `./assets/...` | ✅ |
| Chrome / Edge | required | Canvas2D / WebAudio / IndexedDB — standard | ✅ |
| Chromebook (4 GB) | smooth | Pooling, sprite cache, culling, DPR clamp ≤ 2 | ✅ |
| Mouse / keyboard / touch | required | All three, incl. floating joystick | ✅ |
| Landscape + portrait | required | Verified 1216×684, 800×450, 450×800, etc. | ✅ |
| `user-select: none` on body | mobile | Present in `styles.css` | ✅ |
| iOS audio resume | if applicable | `touchend` → `AudioContext.resume()` | ✅ |
| Physics across refresh rates | consistent | Fixed 60 Hz timestep with backlog cap | ✅ |

## Gameplay

| Requirement | This game | Status |
| --- | --- | --- |
| Readable at DPR 1 | HUD scales with `clamp()`; verified at DPR 1 | ✅ |
| English localization | All copy is English | ✅ |
| Intuitive controls | Move-to-grow understood in <5 s; onboarding hint | ✅ |
| Land directly in gameplay | Boot → play, no menus (offline modal is dismissable) | ✅ |
| No custom fullscreen button | None (CrazyGames provides it) | ✅ |
| Restricted keys | `Escape` never bound; pause = `P`, upgrades = `U`; WASD/ZQSD/arrows | ✅ |
| No cross-promotion | None | ✅ |
| Originality | Original concept, code, art, audio | ✅ |
| PEGI 12 | Abstract cosmic theme, no violence/gore/text chat | ✅ |

## Advertisement / Account / Multiplayer / Purchases

Not implemented (correct for Basic Launch). The game runs perfectly with these
disabled — no dead rewarded-ad buttons, no login walls, no multiplayer stubs.

- Ads: none. `src/sdk/CrazyGames.ts` leaves seams for SDK ads at Full Launch.
- Account: guest-only, no external login options.
- Multiplayer: single-player only.
- Purchases: none.

## Save / data

- IndexedDB primary + localStorage mirror; versioned & sanitized on load.
- Import / export via base64 codes in Settings.
- Autosave every 12 s and on `visibilitychange` / `pagehide` / `beforeunload`.
- No personal data is collected; no Privacy Policy notice required for Basic
  Launch (only SDK events would be sent, and only if the SDK is present).

## SDK

- `crazygames-sdk-v3.js` is loaded best-effort from the official CDN. If it is
  unreachable (offline / local dev), `window.__cgSdkFailed` is set and the game
  runs fully without it.
- `SDK.init()` is awaited, then `game.gameplayStart()` fires the moment the
  player can play (used by CrazyGames to measure initial download size).
- `gameplayStop()` fires on pause; `happytime()` fires on prestige.

## Pre-submission asset checklist (to produce before upload)

- [ ] 3 cover images — 1920×1080, 800×1200, 800×800 (no borders / extra text / logos).
- [ ] Preview videos — 15–20 s, ≤ 50 MB, 1080p landscape + portrait, no audio.
- [ ] Game description + controls metadata.

> Re-verify live limits at https://docs.crazygames.com before each submission;
> CrazyGames revises file-size and SDK rules periodically.
