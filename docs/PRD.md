# PRD — SilkMic

Status: draft v1 · 2026-11-01 · Author: Delwer Hossain
Name: **SilkMic** (decided 2026-11-01, see `docs/NAMING.md`).
Research basis: `docs/RESEARCH.md` (5 research passes + adversarial fact-check, 2026-11-01).

## 1. Vision

A free, open-source, on-device Mac menu-bar app that makes your voice sound clean in every app and keeps your audio under control — without subscriptions, accounts or setup.

One-line pitch: **"Free SoundSource + Krisp for Mac, on-device."**

The app started from the author's own daily problem: switching between the MacBook mic and Bluetooth earbuds (QCY) while sending WhatsApp voice notes and taking calls, and the voice reaching the other side with background noise — or not at all.

## 2. Target users

| Segment | Typical situation | Main need |
|---|---|---|
| Remote workers / freelancers | Zoom, Meet, Teams, WhatsApp calls from home or cafés | Clean voice, never "you're on mute" moments |
| Earbud users (AirPods, QCY, etc.) | Listen with earbuds, talk on calls | Earbuds stay hi-fi; mic does not jump around |
| Voice-note senders | WhatsApp/Telegram desktop voice notes | Noise-free notes with zero extra steps |
| Creators | Voice Memos/QuickTime recording, quick voice-overs | Clean recordings without a studio |
| Bangla speakers (phase 3) | Typing in Bangla/English is slow | Push-to-talk dictation that understands Bangla |

Platform for v1: macOS on Apple Silicon only. Windows/Linux are out of scope for v1 (see §9).

## 3. Problems → solutions

Evidence links are in `docs/RESEARCH.md`.

| # | Problem (what people feel) | Evidence | Our solution | Feature |
|---|---|---|---|---|
| P1 | "My AirPods/earbuds sound terrible on calls" — using the earbud mic forces Bluetooth into low-quality call mode, and macOS re-picks the earbud mic on every reconnect | HN thread 223 pts/309 comments; Apple Community threads; paid single-purpose apps (SoundAnchor, AudioWrangler, ToothFairy); FineTune #342 #428 #459 | Keep the input on the built-in (or chosen) mic while earbuds are the output, automatically | F3 Hi-Fi Saver, F2 Smart Mic |
| P2 | "People hear my fan/street/keyboard" in calls and voice notes | Krisp $8–16/mo; Apple Voice Isolation only in apps that support it | AI noise removal on a virtual mic that every app uses automatically | F1 Clean Mic |
| P3 | "My voice disappears" or "the noise is back" after changing mics | The author's own NoNoise + FineTune setup; NoNoise #19 #20 | Mic chosen by stable device ID from a priority list; never captures from itself; self-healing | F2 Smart Mic, F9 Self-repair |
| P4 | "Am I muted?" — no Mac has a mic-mute key | 7+ single-purpose mute apps; FineTune #341 #104 | One global mute with clear state and a "you're talking while muted" alert | F4 Mute Everywhere |
| P5 | "Which mic is live and how do I sound?" | FineTune #417 | Live level meter + 5-second before/after test | F5 Mic Check |
| P6 | No per-app volume or output on macOS | FineTune ~10k stars, ~330k downloads | Per-app volume, mute and output device | F6 App Mixer |
| P7 | Audio utilities that break things (silent mic, crackle, volume blast, double audio) | FineTune #185 #156 #363 #170 #292 | Reliability as a feature: watchdog, safe defaults, regression tests | F9 Self-repair, NFRs |
| P8 | Noise from the other side of the call | User reports; NoNoise "Clean Incoming" broke all audio | Clean incoming audio only for chosen call apps, never system-wide | F11 Clean Incoming |
| P9 | Echo when using speakers instead of headphones | Low evidence; follows from P8 | Echo cancellation only when output is speakers | F12 Echo Guard |
| P10 | Typing in Bangla/English is slow; no good Bangla dictation on Mac | Apple Dictation/SpeechTranscriber lack Bangla | Push-to-talk dictation, English via Apple engine, Bangla via a fine-tuned Whisper | F14 Dictation |
| P11 | Important recordings still sound amateur | Adobe Podcast is web-only, limited | Offline "Studio clean" for files and voice notes | F15 Studio Clean |

## 4. Goals and non-goals

Goals (v1):
- Clean voice in every app with zero per-app setup.
- Earbuds stay hi-fi by default.
- Never lose the voice: no silent mic, no loops.
- Feel native, beautiful and new (own brand and UI).
- Idle cost near zero; small, fast, private (no account, no cloud, no telemetry).
- Install from GitHub in under 2 minutes.

Non-goals (any version):
- Meeting recording, AI meeting notes, accounts, cloud processing.
- Pro routing graphs (Loopback style), AU plug-in chains, 3D/spatial effects.
- Windows/Linux in v1.

## 5. Key scenarios (acceptance stories)

S1 WhatsApp voice note: user holds WhatsApp's mic button in a noisy room → the receiver hears clean voice. No app setting was touched.
S2 Call with earbuds: user connects QCY earbuds and joins a call → earbuds stay in hi-fi, the built-in mic is used and cleaned; when earbuds disconnect, nothing breaks. With the lid closed (external display), the next available mic is used instead of the disabled built-in one.
S3 Switch mic on purpose: user picks "Earbud mic" in the menu → cleaning continues on that mic; when the earbuds die, the app falls back to the next mic in the list and shows a notice.
S4 Mute: user presses the mute hotkey → every app hears silence, the menu-bar icon turns red; if the user speaks while muted, a small notice appears.
S5 Recording: user records in Voice Memos/QuickTime → the recording is clean by default; with Clean Mic toggled off it is raw.
S6 Restart: user restarts the Mac → the app starts (if enabled), the clean mic is default again, no action needed.
S7 Quit: user quits the app → the system default input returns to the physical mic; no app is left with a silent mic.
S8 Dictation (phase 3): user holds Fn, says a Bangla sentence, releases → the text appears in the focused field.

## 6. Features

Priority: **P0 = MVP (v1.0)**, P1 = v1.x, P2 = v2.

### P0 — MVP

| ID | Feature | Behaviour | Acceptance criteria |
|---|---|---|---|
| F1 | Clean Mic | A virtual microphone ("SilkMic Mic") is the system default input. Audio from the chosen physical mic is cleaned with DeepFilterNet3 and sent to it. One toggle: Clean on/off (bypass keeps the same device, so calls never drop). Strength presets: Light 15 dB, **Balanced 30 dB (default)**, Strong 45 dB, Max 100 dB, **Auto** (adapts between Light and Strong from the measured noise floor); Advanced slider 10–100 dB; pause gate on by default. | Every app that uses the system default mic (WhatsApp, Voice Memos, QuickTime default, Meet/Zoom/Discord on "System default") receives cleaned audio with no per-app change; apps pinned to a raw mic are detected by F21; toggle switches within 50 ms without clicks; added latency ≤ 90 ms (target 60); the first word of a voice note is not clipped (cleaned audio ≤ 150 ms after the app starts recording) |
| F2 | Smart Mic | Ordered mic priority list stored by device UID. Auto-follow on connect/disconnect (debounced). Never captures from its own virtual devices or from "default". Manual pick from the menu always wins until that device disappears. Remembers the choice across restarts. | Unplug/plug/BT disconnect never leaves the virtual mic silent for > 1 s while another mic exists; choice survives restart |
| F3 | Hi-Fi Saver | When the output is Bluetooth earbuds, the input stays on the built-in/next non-Bluetooth mic unless the user opts in to the earbud mic. On by default. The built-in mic is skipped while the lid is closed (clamshell), because it is cut off in hardware. | Earbuds never switch to call mode because of the app; macOS auto-switching to the earbud mic on connect is reverted; with the lid closed the next mic is used |
| F4 | Mute Everywhere | Global hotkey (default ⌥⌘M, configurable; uses a hotkey API that needs no permission) mutes the virtual mic (sends silence). Menu-bar icon and HUD show state. "Talking while muted" detection with a gentle notice (the UI explains that the orange mic dot stays on because the app keeps listening for this). Optional: remap the F5 mic key (needs Input Monitoring). | Mute applies to every app within 50 ms; state is always visible; speaking while muted triggers a notice within 1 s |
| F5 | Mic Check | Live input level and noise level meters. "Test" records 5 s and plays back original vs cleaned. | User can hear the difference in one click |
| F6 | App Mixer | Per-app volume, mute and output device (inherited from FineTune). | Same quality as FineTune today; no volume blast at start |
| F7 | Launch at login | Opt-in during onboarding (recommended on); starts silently to the menu bar. | After reboot S6 passes |
| F8 | Onboarding | Steps: move to Applications (if launched from the DMG) → welcome → detect and replace old tools (F24) → permissions (Microphone, Audio Capture; Input Monitoring only if F5 remap/dictation is enabled) → install the virtual mic (admin password once) → mic test. Shows the "Open Anyway" Gatekeeper help when needed. | New user reaches a working clean mic in < 2 min |
| F9 | Self-repair | Watchdog detects a silent virtual mic, lost device, stuck tap or crashed engine and recovers. Restores the physical default input on quit or crash. Orphaned taps cleaned on launch. Safe mode if the driver is missing. **Driver keepalive:** if the app stops sending its heartbeat for > 10 s (crash, deleted, failed at login), the virtual mic hides itself and stops being default, so apps fall back to a real mic. | No scenario leaves the system with a silent mic for > 10 s, even if the app is gone |
| F10 | Updates | Sparkle with the app's **own** EdDSA key and feed on GitHub (never the upstream feed); driver updated only when its version changes. | One-click update keeps settings and mic permission |
| F21 | Raw-mic detector | Detect apps that are pinned to a physical mic instead of the system default (Zoom, Teams, Discord, Chrome) and show "Zoom uses the raw mic → Fix" with one-click instructions. | Detection within 2 s of the app opening the mic |
| F22 | Uninstall | One button (and a script in the DMG): remove driver, restart Core Audio, restore default input, remove login item, delete settings and models. | System is back to its original state |
| F23 | Smart strength (intelligence, MVP) | "Auto" strength from the measured noise floor; suggests Strong in loud places and Light in quiet ones; never changes while the user is speaking. | Auto keeps voice natural in a quiet room and removes a fan/street noise in a loud one |
| F24 | Migration | Detects FineTune, NoNoise and other input lockers; offers to quit them, remove their login items and the old NoNoise driver, and imports FineTune per-app volumes. | No two apps fight over the default input after onboarding |

### P1 — v1.x

| ID | Feature | Behaviour |
|---|---|---|
| F11 | Clean Incoming | Per-app, opt-in, for call apps (WhatsApp, Zoom, Meet, Teams, Discord): clean the other side's audio via a per-app tap. Never a global tap. |
| F12 | Echo Guard | Echo cancellation (WebRTC AEC3) only when output is the built-in speakers. Far-end reference = the per-app taps of the active call app (not a global tap). Disabled automatically for apps that already run their own echo cancellation, to avoid doing it twice. |
| F13 | Smart Assist ("intelligence", rules on device) | Suggest or auto-apply: noisy room detected → suggest Strong; call app started → apply "Meeting" scene; speakers + call → enable Echo Guard; earbud mic chosen → warn about quality; virtual mic silent → auto-repair; long silence while unmuted in a call → nothing (never nag). Every automation can be turned off. |
| F16 | Scenes | One click: Meeting / Music / Recording — sets mic, strength, outputs, volumes. |
| F17 | Notch panel | Click the notch (on notched Macs) to drop down the main panel; menu bar remains the primary entry. |
| F18 | Loudness leveler | Optional per-app or system leveler for loud ads (FineTune has a loudness equalizer to build on). |
| F19 | Per-app clean toggle | Raw mic for chosen apps (e.g. music recording). Needs a second virtual device ("SilkMic Raw Mic") or per-client streams in the driver. |
| F25 | Notch on new Macs | Test and enable the notch panel on Dynamic Island MacBook Pro (PROLED) and M6 hardware; detect the cutout by geometry, not by "notch exists". |

### P2 — v2

| ID | Feature | Behaviour |
|---|---|---|
| F14 | Dictation | Hold Fn = English (Apple SpeechTranscriber, 0 MB), Fn+Shift = Bangla (whisper.cpp + quantized `mozilla-ai/whisper-large-v3-bn`, downloaded on demand); text pasted into the focused field; clipboard restored. |
| F15 | Studio Clean | Drop a file or use "clean last voice note": offline enhancement (NoNoise's file denoiser first; optional Resemble Enhance download). |
| F20 | Quick voice note | Hotkey: record a clean clip, copy the file to the clipboard for WhatsApp/Telegram. |

## 7. UX principles

1. **Zero config:** defaults work for 90% of people (Balanced, Hi-Fi Saver on, Smart Mic on).
2. **Glanceable:** the menu-bar icon always shows clean on/off, muted, and problems.
3. **One click for daily actions:** toggle clean, mute, switch mic, strength.
4. **No surprises:** never change the default device mid-call; every automation is visible and reversible. If the user picks a mic in System Settings, the app treats it as their manual mic choice (cleaning continues on that mic) instead of fighting it.
5. **Native and new:** SwiftUI, Liquid Glass on macOS 26+, own visual identity (see `docs/DESIGN.md`).
6. **Accessible:** VoiceOver labels, keyboard navigation, Reduce Transparency/Motion respected.

### Settings (complete list for v1)

- General: launch at login, show in notch (when available), menu-bar icon style, HUD style, sounds on toggle, language (English, Bangla).
- Voice: clean on/off, strength preset + advanced slider, pause gate, mic priority list, Hi-Fi Saver, allow earbud mic.
- Shortcuts: toggle clean, mute, cycle mic, open panel, F5 remap.
- Apps: per-app volume/output (mixer), per-app clean (P1), clean incoming (P1).
- Updates: automatic check, channel (stable/beta).
- Privacy: everything on device; no telemetry; update check is the only network call (can be disabled).
- Advanced: engine (DeepFilterNet3 / Apple Sound Isolation), reinstall driver, reset settings, export diagnostics.

## 8. Non-functional requirements

| Area | Requirement (targets, to be measured) |
|---|---|
| Idle cost | ~0% CPU when no app uses the mic; no timers firing when the panel is closed |
| Active cost | ≤ 5% of one performance core while cleaning |
| Memory | < 80 MB resident without dictation models |
| Latency | ≤ 90 ms added, target 60 ms (DeepFilterNet3 adds 40 ms itself) |
| First word | Cleaned audio ≤ 150 ms after an app starts recording (model stays loaded; only capture stops when idle) |
| Startup | Menu-bar ready < 1 s after login |
| Reliability | Dogfood metric (no telemetry): zero crashes and zero silent-mic incidents in 2 weeks of daily use; local crash logs via "Copy diagnostics" |
| Localization | English and Bangla UI (String Catalog) |
| Accessibility | Every control has a VoiceOver label; panel and mixer fully keyboard-navigable |
| Privacy | No audio leaves the Mac; no analytics |
| Size | App download < 30 MB (models for dictation downloaded separately) |
| Compatibility | macOS 15.4+ (FineTune's base); Liquid Glass on 26+; tested on 27 |

## 9. Distribution

- GitHub Releases: `.dmg` (drag to Applications) and `.zip`.
- No Apple Developer account for now: builds signed with one stable self-signed certificate; README shows the one-time "Open Anyway" step (System Settings → Privacy & Security).
- Sparkle auto-updates with EdDSA signatures.
- Homebrew: a personal tap if possible (official cask requires notarization).
- License: GPL-3.0 (FineTune is GPL-3.0; NoNoise MIT and DeepFilterNet MIT/Apache are compatible).

## 10. Brand and credits

- New name, logo, colours and UI (see `docs/DESIGN.md`, `docs/NAMING.md`). The product looks and feels new.
- Legal requirement: GPL-3.0/MIT require keeping the original copyright notices and licence texts. Credits live in `NOTICE`, an in-app Acknowledgements screen, the About screen and the README "Built on" section; they are not shown anywhere else in the UI. Licence checklist:
  - FineTune (Ronit Singh, GPL-3.0); NoNoise (ivalsaraj, and Ghostkwebb for the original MetalVoice project, MIT); Sparkle (MIT); DeepFilterNet code and weights (MIT/Apache-2.0); later WebRTC APM (BSD-3), whisper.cpp (MIT), mozilla-ai Bangla model (Apache-2.0 NOTICE).
  - MIT/BSD/Apache notices ship **inside the .app** (Acknowledgements), not only in the repo.
  - Changed upstream files keep their headers and get a "Modified by Delwer Hossain, 2026" note (GPL-3.0 §5a).
  - About screen shows copyright, "no warranty" and a GPL-3.0 link (§5d); source code link on GitHub.

## 11. Success metrics

- Product: S1–S7 pass on the test matrix; NFR targets met.
- Adoption (6 months after launch): GitHub stars, release downloads, issues closed vs opened.
- Daily use on real Macs without manual fixes for 2 weeks before public launch.

## 12. Risks

| Risk | Mitigation |
|---|---|
| FineTune ships mic processing upstream (#385) | Differentiate on voice-first + Hi-Fi Saver + Bangla; keep merging upstream fixes |
| Unsigned app scares users | Clear README/GIF for "Open Anyway"; stable self-signed cert; consider Developer ID later |
| Driver bug kills all audio | Small C driver from NoNoise with tests; watchdog; safe mode; uninstall button |
| Bluetooth clock drift / crackle | Drift-correcting resampler; FineTune's Bluetooth learnings |
| Dynamic Island Macs (PROLED) behave differently | Menu bar is primary; notch panel only where detected and tested |
| Bangla dictation quality | Benchmark on real voice notes before shipping F14 |
