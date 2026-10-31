# Roadmap and task list

Status: draft v1 · 2026-11-01. Each task has an ID, a done-check, and dependencies. Feature IDs refer to `docs/PRD.md`; design references to `docs/TRD.md`.

Legend: ☐ todo · ◐ in progress · ☑ done

## Phase 0 — fix the owner's Mac today (no new code)

| ID | Task | Done when | Deps |
|---|---|---|---|
| 0.1 ☑ | FineTune + NoNoise launch at login | Both running after a reboot | – |
| 0.2 ☑ | NoNoise attenuation 100 → 30 dB | `mv.attenuationLimitDb = 30`; Voice Memos test sounds natural | – |
| 0.3 | Confirm FineTune input lock = NoNoise Mic and NoNoise input = MacBook mic | Voice note to self is clean | 0.1 |

## Phase 1 — foundations

| ID | Task | Done when | Deps |
|---|---|---|---|
| 1.1 ☑ | Fork FineTune into this repo (history kept), add `upstream-finetune` and `upstream-nonoise` remotes | `git log` shows FineTune history; both remotes fetch | – |
| 1.2 ☑ | Build upstream FineTune unchanged on this Mac | Debug build succeeded 2026-11-01 (Xcode 27.1, unsigned) | 1.1 |
| 1.0 ☑ | Choose name (`docs/NAMING.md`): domain, social handles, trademark search | Name fixed in all docs | – |
| 1.3 ◐ | Rename targets, bundle IDs, product name, settings folder; replace Sparkle `SUFeedURL` + `SUPublicEDKey` with our own | App builds and runs under the new name; no "FineTune" in UI strings (upstream file headers kept); our own feed and key in `Info.plist` | 1.2, 1.0 |
| 1.4 ◐ | Import NoNoise `Driver/` with new bundle ID, device names and UIDs; add keepalive (TRD §3.4); run its C tests | Driver tests pass; driver installs and shows "SilkMic Mic"; killing the app hides the mic within 10 s | 1.1 |
| 1.5 ☑ | Create `Packages/VoiceCore` from NoNoise Core (DFN3, VoiceChain, presets, file denoiser) | Package builds; NoNoise DSP tests pass | 1.1 |
| 1.6 ◐ | `NOTICE`, LICENSE (GPL-3.0), in-app Acknowledgements, About screen notices, "Modified by" headers | PRD §10 licence checklist complete | 1.1 |
| 1.7 | Stable self-signed signing certificate + build script | Rebuilt app keeps mic permission | 1.3 |
| 1.8 | Key custody: offline backup of EdDSA key and signing cert; CI secrets | Restore tested on a clean keychain | 1.7 |
| 1.9 | CI on PRs: build, unit tests, driver C tests, DSP golden tests | Green CI on a test PR | 1.4, 1.5 |
| 1.10 | Go/no-go spikes: DFN3 ANE vs CPU jitter; self-signed cert keeps mic permission on 27; Sparkle update prompt without Team ID | Results in `docs/benchmarks.md` | 1.5, 1.7 |
| 1.11 ◐ | Design tokens first (`docs/DESIGN.md` + tokens), so Phase 2 UI is not built twice | Tokens in code | 1.0 |

## Phase 2 — MVP features

| ID | Task | Feature | Done when | Deps |
|---|---|---|---|---|
| 2.1 | AUHAL capture on explicit device + C ring + DSP worker | F1 | Clean audio reaches the virtual mic from a chosen device | 1.4, 1.5 |
| 2.2 | Strength presets + advanced slider + pause gate | F1 | Presets audibly differ; Balanced default | 2.1 |
| 2.3 | Delay-matched bypass toggle | F1 | Toggle mid-call has no click and no device change | 2.1 |
| 2.4 | InputRouter: priority list by UID, auto-follow, never-self, manual pick, persistence | F2 | Table-driven tests pass; S3 passes | 2.1 |
| 2.5 | Default-input lock to virtual mic + restore on quit/crash | F2, F9 | S6 and S7 pass | 2.4 |
| 2.6 | Hi-Fi Saver | F3 | S2 passes with QCY and AirPods | 2.4 |
| 2.7 | Mute Everywhere + hotkey + talking-while-muted | F4 | S4 passes | 2.1 |
| 2.8 | Mic Check: meters + 5 s before/after | F5 | One-click A/B works | 2.1 |
| 2.9 | Watchdog + safe mode + orphan cleanup | F9 | Fault-injection tests recover | 2.5 |
| 2.10 | Launch at login (SMAppService) | F7 | S6 passes | 1.3 |
| 2.11 | Onboarding flow incl. driver install and Gatekeeper help | F8 | Fresh-user install < 2 min | 1.4, 2.1 |
| 2.12 | On-demand engine (runs only with a client) | NFR | Idle CPU ~0% measured | 2.1 |
| 2.13 | Performance harness + benchmarks | NFR | `docs/benchmarks.md` filled for each preset | 2.2 |
| 2.14 | Migration from FineTune/NoNoise (quit, login items, old driver, import volumes) | F24 | No fight over default input after onboarding | 2.5 |
| 2.15 | Uninstall button + DMG script | F22 | System back to original state | 1.4 |
| 2.16 | Raw-mic detector (process objects) | F21 | Zoom pinned to raw mic is detected | 2.4 |
| 2.17 | Auto strength from noise floor | F23 | Quiet room natural, loud room clean | 2.2 |
| 2.18 | Clamshell, sample-rate/channel conversion, sleep/wake handling | F2, F3 | Lid-closed, USB 44.1 kHz, BT 16 kHz and wake tests pass | 2.4 |
| 2.19 | Driver update path (version check, update only when idle) | F10 | Driver update without user confusion | 1.4 |
| 2.20 | Move-to-Applications gate | F8 | Launch from DMG offers to move | 1.3 |
| 2.21 | Localization (English, Bangla) + VoiceOver labels | NFR | Both languages complete; VoiceOver pass | 3.3 |
| 2.22 | "Copy diagnostics" + issue template | NFR | Diagnostics paste into a GitHub issue | 2.9 |

## Phase 3 — brand and UI

| ID | Task | Done when | Deps |
|---|---|---|---|
| 3.1 ☑ | Logo + app icon + menu-bar template icons | Icon set in asset catalog; looks right at 16 px and in dark/light | naming |
| 3.2 | New design system (tokens, typography, colour, glass rules) | `DESIGN.md` approved; tokens implemented | 3.1 |
| 3.3 | Main panel redesign (voice card first, then apps) | Matches approved mockup | 3.2, 2.x |
| 3.4 | Settings + onboarding redesign | Matches mockup; VoiceOver labels | 3.2 |
| 3.5 | Liquid Glass on 26+, material fallback, Reduce Transparency | Visual check on 15.4/26/27 | 3.3 |

## Phase 4 — release v1.0

| ID | Task | Done when | Deps |
|---|---|---|---|
| 4.1 | DMG + zip packaging, Sparkle appcast, GitHub Actions release | Tagged build produces signed artifacts | 1.7 |
| 4.2 | README (pitch, GIF, before/after audio, install + Open Anyway guide, credits) | Reviewed | 3.x |
| 4.3 | Full manual test matrix | All S1–S7 pass on matrix | Phase 2 |
| 4.4 | Undo Phase 0 (remove FineTune/NoNoise login items and old driver), then two weeks of owner daily use | No manual fixes needed | 4.3 |
| 4.5 | Launch: Show HN, r/macapps, Product Hunt, awesome-macos | Posts live | 4.4 |

## Phase 5 — v1.x (P1)

5.1 Clean Incoming per app (F11) · 5.2 Echo Guard AEC3 (F12) · 5.3 SmartAssist rules (F13) · 5.4 Scenes (F16) · 5.5 Notch panel (F17) · 5.6 Loudness leveler (F18) · 5.7 Per-app clean toggle (F19) · 5.8 Apple Sound Isolation engine option · 5.9 Notch/Dynamic Island test on M6 and PROLED hardware (F25).

## Phase 6 — v2 (P2)

6.1 Dictation English (Apple) · 6.2 Bangla benchmark + dictation (whisper.cpp) · 6.3 Studio Clean (F15) · 6.4 Quick voice note (F20).

## Working order for this repo

Phase 0 → 1.1–1.2 → 1.0 naming → 1.3–1.11 (1.10 spikes decide go/no-go) → 2.1 → 2.4 → 2.5 → 2.6 → rest of Phase 2 → Phase 3 (logo starts as soon as the name is chosen) → Phase 4.

## Owner decisions (2026-11-01)

- Name: SilkMic. Repo: public `delwerhossain/SilkMic`; Claude may commit (as delwerhossain) and push work branches on its own; `main` stays release-ready.
- Brand colour: silk violet / lavender on graphite glass.
- Phase 0 approved.
- Steps that need the owner (admin password, permission prompts, hardware tests) are batched and asked at checkpoints.

## Working method (how each task is done)

- **Before a task:** re-read the relevant PRD/TRD section; if a fact is uncertain (API behaviour, macOS version detail, library licence), research it first (web search, Apple docs, upstream source via `gh`), and record the result in the doc or `docs/benchmarks.md`.
- **Skills used per area** (loaded when the task starts; new skills may be installed when a gap is found, and recorded here):
  - Git: `git-commit` before every commit/push/release.
  - Planning/quality: `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `superpowers:requesting-code-review`.
  - Design: `logo-design` (logo, icon), `anthropic-skills:frontend-design` / `artifact-design` (mockups), `codex-image` only for raster mockups if needed.
  - Docs/release: `engineering:documentation` (README), `engineering:deploy-checklist` (release).
  - Code search in large upstream code: `codebase-memory` MCP.
- **Done means verified:** build passes, tests pass, and the task's done-check in this file is met; otherwise the task stays ◐ with a note.
- **Commits:** small, one topic each, as delwerhossain (see `git-commit` skill); work on `main-app`, push to `delwerhossain/SilkMic`.
- **Owner checkpoints:** admin password, permission prompts, logo choice, hardware tests (QCY, WhatsApp) — batched and asked together.

## Progress log

- 2026-11-01: Phase 0 done (owner's voice test pending). Repo `delwerhossain/SilkMic` created. 1.3 rename done (966 app tests pass) — remaining: own Sparkle EdDSA key (needs owner keychain, 1.8). 1.4 driver imported, renamed, new factory UUID, C tests pass, builds — remaining: keepalive, install test (owner password). 1.5 VoiceCore package, 240 tests pass. 1.6 README + NOTICE done — remaining: in-app Acknowledgements and About notices.
- 2026-11-01 (later): 1.4 driver keepalive done (C tests + app sender; live test pending owner password). 1.6 About/Acknowledgements done (licence texts in app). 3.1 logo kit done (Hush Capsule, Silk Violet, app icon, menu-bar icon, favicon set; state icons drafted). 1.11 brand + voice-state tokens and accent colour done; full token pass continues with Phase 3 UI. App tests: 966 pass.
- 2026-11-01 (later): FineTune and NoNoise login items removed and both apps quit (part of 4.4 undo of Phase 0); SilkMic is the only login item. Old NoNoise driver still installed (remove in migration, F24).
