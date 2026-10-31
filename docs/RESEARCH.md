# Mac voice app — research and plan

> **Note (2026-11-01):** this is the original research summary. Later decisions supersede parts of it: no Apple Developer ID for now (self-signed builds, GitHub DMG; §4–§7 mentions of notarization, official Homebrew cask and Developer ID are deferred), Swift + C instead of Rust (§8), and HAL drivers load without Developer ID (NoNoise ships ad-hoc). Current specs: `PRD.md`, `TRD.md`, `ROADMAP.md`.

Date: 2026-11-01. Research: 5 parallel research passes + 1 adversarial fact-check. Name: SilkMic (see NAMING.md).

One-line pitch: **free, on-device SoundSource + Krisp for Mac** — clean mic in every app, per-app volume, earbuds stay in hi-fi, optional Bangla/English dictation.

## 1. People's problems (ranked)

| # | Problem | Evidence | Confidence |
|---|---|---|---|
| 1 | AirPods/Bluetooth earbuds drop to low quality when their mic is used; macOS re-picks the earbud mic on every reconnect | HN "prevent AirPods quality degradation" 223 pts / 309 comments, mostly angry at a $20/yr subscription; many Apple Community threads; paid apps SoundAnchor, AudioWrangler, ToothFairy; FineTune #342 #428 #459; NoNoise #20 | High |
| 2 | Background noise in calls and voice notes (WhatsApp, Meet, Discord) | Krisp $8–16/mo with no noise-only plan; Apple Voice Isolation works only in apps that support it | Medium-high |
| 3 | No per-app volume in macOS | FineTune ~10k stars, ~330k downloads in 10 months; SoundSource $49 | High |
| 4 | "Am I muted?" — no Mac has a mic-mute key (F5 = Dictation) | 7+ open-source mute apps; FineTune #341 #104 | Medium |
| 5 | Audio apps that break things (silent virtual mic, wrong device, crackle, volume blast, double audio) | FineTune #185 #156 #363 #170 #292; NoNoise #19 #20 | High |
| 6 | Bangla / Banglish dictation | Apple Dictation and SpeechTranscriber have no Bangla; Wispr Flow only one language per dictation | High (gap) |

## 2. Verified facts that shape the design

- Licenses: FineTune GPL-3.0 → merged app must be GPL-3.0. NoNoise MIT, DeepFilterNet MIT/Apache, WebRTC APM BSD-3, Resemble Enhance MIT, DynamicNotchKit MIT, Boring Notch GPL-3.0 — all compatible. Facebook Denoiser is CC-BY-NC → not usable.
- FineTune #385 (open, 2026-07-23): upstream prototype "input Audio Unit chain via a virtual microphone" → FineTune may ship mic processing itself. Talk to the maintainer early.
- NoNoise currently uses DeepFilterNet3 at `attenuationLimitDb=100` (unlimited). Unlimited gates background to silence between words → dropouts and metallic sound (WorkAdventure PR #16 uses 25 dB + 45 dB pause gate; Fluxer lowered to 30 dB).
- NoNoise bug source: `selectedInputDeviceID` not persisted; falls back to `AVCaptureDevice.default`; virtual mic filtered by name only; "Clean Incoming" uses a global tap and replays to default output.
- Voice Isolation mic mode is read-only for apps (only the system picker can be shown). `kAudioUnitSubType_AUSoundIsolation` is public (macOS 13+) → usable as an "Apple engine" option.
- Homebrew disables casks that fail Gatekeeper since September 2026 → need Apple Developer ID ($99/yr) + notarization. Also needed for a stable mic permission (ad-hoc signing loses it on every rebuild) and for the HAL driver.
- Hardware (Apple newsroom): M6 14" MacBook Pro (Oct 27, 2026, mini-LED design), MacBook Pro with PROLED XDR (Oct 28, 2026, Dynamic Island per press; Apple pages do not say "notch"), MacBook Neo (Mar 2026). Notch geometry on PROLED unknown until hands-on.
- Bangla STT: mozilla-ai/whisper-large-v3-bn (Apache-2.0) self-reports 9.65% WER vs 55.5% for base large-v3. No credible Banglish (code-switch) model exists; every engine picks one language per utterance.
- Dictation market is crowded with free open source: Handy 35.8k stars (MIT), VoiceInk ~7k (GPL).

## 3. Architecture

```
Physical mics (built-in, USB; earbud mic only if user opts in)
  | open by stored device UID from a priority list; never "default"; never our own UID
Capture (AUHAL, 256–480 frames) -> lock-free ring
DSP thread, 48 kHz, 10 ms blocks:
  high-pass 80 Hz -> AEC3 (only when output = speakers) -> DeepFilterNet3 (25–30 dB default)
  -> VAD pause gate (~-45 dB) -> AGC2 + limiter -> mute gate -> drift-correcting resampler
  | shared ring
HAL plug-in "Clean Mic" (from NoNoise driver) = system default input, locked
  -> WhatsApp, Zoom, Meet, QuickTime, Voice Memos (all automatic)

Incoming (opt-in per call app): FineTune per-app process tap -> DFN3 -> that app's output
Never a global tap.
```

- Base: fork FineTune (per-app taps, device lock with echo-tracker, orphan cleanup) + NoNoise driver and DFN3 Core ML.
- Auto-follow: listen to device list / default input / alive changes, debounce 300–500 ms, choose first alive device from the UID priority list. If output is Bluetooth earbuds, keep input on the built-in mic ("hi-fi saver"). If nothing is available, serve silence and warn.
- Toggle clean on/off = delay-matched bypass; never change the default device mid-call. Restore the physical default input on quit.
- Added latency ~70–90 ms (DFN3 40 ms). Run Core ML off the real-time thread.
- Engines: DeepFilterNet3 (default), Apple AUSoundIsolation (option), GTCRN/RNNoise as low-CPU fallback.
- Risks: a crashing driver kills all audio; coreaudiod restart on driver install drops audio; Bluetooth clock drift (~20–50 ppm) needs the resampler; leftover echo on speakers.

## 4. Features

MVP:
1. One-toggle AI noise removal for every app (virtual mic, auto-locked).
2. Auto mic + hi-fi saver (earbuds stay hi-fi, chosen mic restored after reconnect).
3. Global mic-mute hotkey, menu-bar state, "you are talking while muted" alert.
4. Mic test: 5 s before/after playback + live level meter.
5. Per-app volume and output (from FineTune).
6. Trust: signed + notarized, Homebrew cask, Sparkle updates, no volume blast at start, no AirPods regressions.

Phase 2: per-app incoming clean for call apps, AEC on speakers, scenes (Meeting / Music / Recording), loudness leveler, notch panel + Liquid Glass.

Phase 3 (optional downloads): dictation (hold Fn = English via Apple SpeechTranscriber, 0 MB; Fn+Shift = Bangla via whisper.cpp + quantized whisper-large-v3-bn), "Studio clean" for voice notes (Resemble Enhance, ~710 MB, ~2 s per 6 s clip on M4 Max via MLX).

Do not build: meeting recorder / AI notes / accounts, Loopback-style routing graphs, 3D/spatial effects.

## 5. UI

- Menu-bar icon is the main UI (small template icon; global hotkey opens the panel).
- Notch drop-down only when a hardware notch is detected (`safeAreaInsets.top > 0` and both aux areas); click to open, not hover (avoids fights with Boring Notch/NotchNook); hide over full-screen apps; rebuild on screen change and wake.
- Dynamic Island (PROLED) or unknown cutout: menu-bar mode by default, notch panel opt-in after testing on real hardware.
- No notch / external display / Neo: popover + optional top-center pill.
- Liquid Glass on macOS 26+ (`glassEffect`, `GlassEffectContainer`); `.ultraThinMaterial` fallback; solid fill with Reduce Transparency; glass only on the open panel.
- Hotkeys: hold Fn push-to-talk (CGEventTap keycode 63; tell users to set Globe key to "Do Nothing"), custom combos, optional F5 remap via `hidutil` (LaunchAgent re-applies at login).
- Permissions: Microphone, Audio capture (`NSAudioCaptureUsageDescription`), Input Monitoring; Accessibility only for key suppression and text paste (macOS 27 calls the pane "Device Control and Data Access").

## 6. Launch

- README: icon + one-line benefit, download badge, `brew install --cask` first, one screenshot, "free, no account, on-device", 15 s before/after audio demo.
- Channels: Show HN, r/macapps, r/MacOS, Product Hunt, awesome-macos. Pitch: "Free SoundSource + Krisp, on-device."
- Credit FineTune and NoNoise; GPL-3.0.

## 7. Phases

| Phase | What | Rough effort (estimate) |
|---|---|---|
| 0 — own Mac, now | FineTune + NoNoise auto-start at login, NoNoise attenuation 100 → 30 dB, verify with Voice Memos | 1 hour |
| 1 — MVP | Fork FineTune, integrate driver + DFN3, auto mic, hi-fi saver, mute, mic test, signed build | 4–6 weeks |
| 2 | Incoming clean, AEC, scenes, notch + glass | 3–4 weeks |
| 3 | Dictation (English/Bangla), Studio clean | 3–4 weeks |
| Launch | Video demo, brew cask, HN/Reddit/PH | 1 week |

Needs from the owner: Apple Developer account ($99/yr), app name, GitHub account for the repo, decision on fork vs contributing upstream to FineTune.

## 8. Decisions (2026-11-01, owner)

- **No Apple Developer account for now.** Distribute from GitHub Releases: `.dmg` (drag to Applications) + `.zip`, with a one-time "Open Anyway" guide (System Settings → Privacy & Security). Sign every build with one stable self-signed certificate so macOS keeps the mic permission across updates (ad-hoc signing loses it). Sparkle updates with its own EdDSA key. Official Homebrew cask is not possible without notarization; a personal tap may work (to verify). Driver installs via the first-run helper (admin password once), like NoNoise today.
- **One project, three platforms, Mac first.** Shared engine in Rust (DeepFilterNet's reference code is Rust; also WebRTC APM, whisper.cpp) built as a library. Native shell per OS:
  - macOS: Swift/SwiftUI — Liquid Glass, notch, Core Audio, HAL virtual mic (best experience).
  - Linux: PipeWire virtual source + filter (easiest port), small tray UI.
  - Windows: last. A virtual mic driver must be Microsoft-signed (EV certificate + attestation), so start with a VB-Cable-based route or skip.
  - Liquid Glass exists only on macOS; other platforms get a plain native look.
- **Noise strength presets instead of a raw dB number:** Light 15 dB, Balanced 30 dB (default), Strong 45 dB, Max 100 dB (current NoNoise setting), plus an "Advanced" slider 10–100 dB. Pause gate on by default.

- **Mac only for now; tech stack = Swift + C (no Rust yet).** Swift/SwiftUI for UI, Core Audio control, Core ML (DeepFilterNet3 INT8 on ANE), SpeechAnalyzer. C for the HAL driver (from NoNoise) and the real-time audio callback (no allocation, locks or ARC on the audio thread; preallocated lock-free rings). C++ libraries (WebRTC APM, whisper.cpp) behind a small C API. Keep the DSP chain behind that C API so a Rust core can replace it later for a Linux port. Reason: reuses FineTune + NoNoise code, every key API is Apple/Swift-native, the heavy work runs in Core ML so Rust would add bridging, not speed.
- Performance targets (to measure, not yet measured): idle CPU ~0% (engine runs only while some app uses the mic), active 2–5% of one core, RAM < 80 MB without dictation, added latency 40–60 ms.

## 9. Not verified

DFN3 timing on the Neural Engine; AUSoundIsolation latency and quality; PROLED notch/Dynamic Island geometry; SpeechTranscriber Bangla on a real device (check `SpeechTranscriber.supportedLocale(equivalentTo:)`); whether a HAL driver strictly needs Developer ID on 26/27; `hidutil` remap reliability on macOS 27; whether noise suppression before STT helps or hurts accuracy.
