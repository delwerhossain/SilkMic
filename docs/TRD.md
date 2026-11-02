# TRD — SilkMic technical design

Status: draft v1 · 2026-11-01. Companion to `docs/PRD.md`. Feature IDs (F1…) refer to the PRD.

## 1. Stack decisions

| Area | Choice | Why |
|---|---|---|
| Language (app) | Swift 6, SwiftUI + AppKit where needed | Both upstreams are Swift; every key API (Core Audio taps, Core ML, SpeechAnalyzer, Liquid Glass, notch geometry) is Apple/Swift-native |
| Real-time audio code | C (callbacks, rings), called from Swift | No allocation, locks, ARC or Objective-C messaging on the audio thread |
| Virtual mic | AudioServerPlugIn HAL driver in C (from NoNoise `Driver/NoNoiseMic`) | Process taps cannot create a microphone; every commercial tool (Krisp, Loopback, BlackHole) uses a HAL plug-in |
| Noise model | DeepFilterNet3 streaming, Core ML (from NoNoise) | Best open full-band real-time model; ~3% of one core; INT8 variant 2.2 MB |
| DSP libraries | WebRTC Audio Processing (AEC3, AGC2, HPF) via a C wrapper (P1) | BSD-3, industry standard |
| Speech-to-text (P2) | Apple SpeechTranscriber (English); whisper.cpp + Bangla fine-tune | 0 MB for English; best published Bangla accuracy |
| Updates | Sparkle 2 (FineTune already ships `UpdateManager`) | Works without Apple Developer ID using EdDSA |
| Min OS | macOS 15.4 (FineTune's target), Apple Silicon | Liquid Glass gated to 26+ with fallbacks |
| No Rust (for now) | Keep the DSP chain behind a small C API | A Rust core can replace it later for a Linux port without touching the app |

## 2. Repository layout

The repo is a fork of FineTune (history kept, `upstream-finetune` remote) with NoNoise code imported as files (`upstream-nonoise` remote for reference).

```
/                       Xcode project (renamed from FineTune)
App/                    SwiftUI app, menu bar, notch surface, settings, onboarding
  Audio/                FineTune engine: per-app taps, device monitors, mixer (kept)
  Voice/                NEW: InputRouter, VoiceEngine bridge, MuteController, SmartAssist
  UI/                   NEW design system + views (replaces FineTune's look)
Packages/VoiceCore/     SwiftPM package: DeepFilterNet3 (Core ML), VoiceChain, presets, file denoiser (from NoNoise)
  Sources/CRealtime/    C: capture/render callbacks, lock-free SPSC rings, resampler
Driver/                 HAL plug-in in C (from NoNoise), own bundle ID and device UIDs, C unit tests
Installer/              privileged first-run installer script + uninstaller
Resources/              model, icons, Sparkle public key
docs/                   PRD, TRD, ROADMAP, DESIGN, NAMING, RESEARCH
NOTICE, LICENSE (GPL-3.0)
```

## 3. Component design

### 3.1 Data flow

```
Physical mic (built-in / USB / BT if allowed)
   │  InputRouter resolves UID → AudioDeviceID (never "default", never our own UIDs)
   ▼
Capture IOProc (AUHAL, 256–480 frames) ──► SPSC ring (C)
   ▼
DSP worker thread (QoS userInteractive, not the IO thread), 48 kHz, 10 ms hops:
   HPF 80 Hz → [AEC3 when output = speakers, P1] → DeepFilterNet3 (atten limit by preset)
   → pause gate (VAD) → AGC/limiter → mute gate → drift-correcting resampler
   ▼
Shared ring → HAL driver output side ("Engine" hidden device) → virtual mic input
   ▼
Any app (WhatsApp, Zoom, Voice Memos…) reads "SilkMic Mic" = system default input (locked)
```

Incoming (F11, P1): FineTune's per-app process tap for selected call apps → DeepFilterNet3 (no gate) → that app's output. Never a global tap.

### 3.2 InputRouter (F2, F3) — new

- Inputs: `kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultInputDevice`, `kAudioHardwarePropertyDefaultOutputDevice`, per-device `kAudioDevicePropertyDeviceIsAlive`, nominal sample rate and stream configuration. Debounce 300–500 ms.
- State: ordered priority list of `{uid, name, transport, allowed}` persisted in settings; `manualSelection` (uid) that wins until that device disappears.
- Selection: first alive device in priority list, excluding our own UIDs (by UID, not name), devices without input streams, private aggregates and loopback devices. If Hi-Fi Saver is on and the default output is a Bluetooth device, skip that device's own input unless `allowed` was set by the user.
- Default-input lock: keep the system default input on our virtual mic using FineTune's `EchoTracker` + grace period (ignore change events caused by our own writes). A change made by the user in System Settings is treated as a manual source pick (capture switches to that mic, default goes back to the virtual mic), not fought. macOS auto-switching on Bluetooth connect is reverted. Restore the physical default on quit/crash (CrashGuard + `atexit`) and rely on the driver keepalive (§3.4) when the app is gone.
- Clamshell: read IOKit `AppleClamshellState`; exclude the built-in mic while the lid is closed (it is listed as alive but cut off in hardware).
- Raw-mic detector (F21): use Core Audio process objects (`kAudioHardwarePropertyProcessObjectList`, `kAudioProcessPropertyIsRunningInput`, `kAudioProcessPropertyDevices`, macOS 14.2+) to find apps reading a physical mic instead of ours; surface "App X uses the raw mic → Fix".
- Formats: physical mics may be 16/24 kHz (Bluetooth HFP), 44.1 kHz (USB) or multichannel. Convert to 48 kHz, pick the first/selected channel, mono → 2 ch for the driver. Rebuild capture on sample-rate or stream-configuration change.
- Sleep/wake: on `NSWorkspace.didWakeNotification` flush rings, re-resolve UIDs, restart capture.
- Output: emits `selectedInputChanged(uid)` to VoiceEngine; VoiceEngine restarts capture without touching the virtual device (apps never see a device change).

Pseudo:
```
onDeviceEvent (debounced):
  candidates = priority.filter(alive && hasInput && !ours && !aggregate)
  if hiFiSaver && output.isBluetooth: candidates.remove(output.pairedInput) unless allowed
  target = manualSelection.isAlive ? manualSelection : candidates.first
  if target == nil: voiceEngine.serveSilence(); ui.warn(.noMic)
  elif target != current: voiceEngine.switchCapture(to: target)
  ensureDefaultInputIsVirtual()
```

### 3.3 VoiceEngine (F1, F4, F5) — from NoNoise, reworked

- Replace `AVCaptureSession` with AUHAL capture on an explicit `AudioDeviceID` (lower, predictable latency).
- Run DeepFilterNet3 off the IO thread; each 10 ms hop must finish < 10 ms; measure CPU-only vs `.all` compute units and pick the one with lower jitter.
- Presets map to `atten_lim_db`: Light 15, Balanced 30, Strong 45, Max 100; Advanced 10–100. Pause gate floor ≈ −45 dB, opens after ≥ 2 speech frames with 1–3 frames lookahead.
- Clean toggle = delay-matched bypass (same latency both ways, so no click and no device change).
- Mute = write zeros into the virtual mic; keep analysing input for "talking while muted" (energy + VAD).
- On-demand: capture runs only while some client reads the virtual mic (`kAudioDevicePropertyDeviceIsRunningSomewhere` on our device) or the Mic Check is open. The compiled Core ML model stays loaded (a few MB) so the first word of a voice note is not clipped; target ≤ 150 ms from client StartIO to cleaned audio. Some apps (Discord, Teams, Chrome) keep mic IO open permanently, so "idle" also means: skip DFN inference when input is below −60 dBFS and pass silence.
- Drift: resampler driven by ring fill level (BT ≈ 50 ppm, built-in ≈ 20 ppm).
- Meters: publish levels at ≤ 15 Hz to the UI only while the panel is visible.

### 3.4 Driver (F1) — from NoNoise

- Keep NoNoise's design: visible input device + hidden "engine" output device sharing a 65 536-frame ring and host-time clock (48 kHz stereo).
- Rename bundle ID, device names and UIDs to the new brand; keep a migration that detects and offers to remove the old NoNoise driver.
- Add a version property; app installs/updates the driver only when its version changes and no client is running.
- Serve silence (not stale audio) when the engine is absent; expose an "engine running" property so the watchdog can detect a stalled engine.
- **Keepalive (separate from engine running):** the app writes a custom keepalive property every 5 s. If it is stale for > 10 s (app crashed, deleted, failed at login), the driver reports `IsAlive = 0` and `CanBeDefault = 0` on the visible mic, so macOS falls back to a real mic. It re-appears when the keepalive resumes.
- Install: `/Library/Audio/Plug-Ins/HAL`, admin password once, strip quarantine, `coreaudiod` restart (warn the user that audio blips once). Consider a `.pkg` like NoNoise. Ad-hoc-signed HAL drivers load (NoNoise ships one today), so no Developer ID is needed.
- A raw second device for F19 needs per-client streams or a second visible device (NoNoise ignores `AddDeviceClient` today).

### 3.4a Migration and uninstall (F22, F24)

- Detect FineTune/NoNoise/other input lockers by bundle ID and login items; offer to quit them and remove their login items; remove `/Library/Audio/Plug-Ins/HAL/NoNoiseMic.driver` with consent; import FineTune per-app volumes from its settings JSON.
- Uninstall: remove our driver, restart `coreaudiod`, restore default input, unregister `SMAppService`, delete Application Support data and models. Same steps in a shell script shipped in the DMG.

### 3.5 App mixer (F6) — FineTune, kept

Per-app process taps + private aggregates, `OrphanedTapCleanup`, `CrashGuard`, Bluetooth drift handling, loudness equalizer. Upstream fixes are merged regularly from `upstream-finetune`.

### 3.6 SmartAssist (F13, P1)

A small on-device rules engine, not an LLM. Signals: noise level (DFN removed energy), call-app process running, output transport, mic transport, virtual-mic silence, user overrides. Each rule: condition → suggestion or action, with a per-rule off switch and a cooldown so it never nags.

### 3.7 UI

- Menu-bar `NSStatusItem` + popover/panel is the primary surface; template icon with states (clean, bypass, muted, problem).
- Notch surface (P1) behind a `SurfaceProvider`: hardware notch detected (`safeAreaInsets.top > 0` and both auxiliary areas) → click-to-open panel; Dynamic Island/unknown cutout → menu-bar mode; no notch → popover.
- Liquid Glass: `glassEffect` / `GlassEffectContainer` on macOS 26+, `.ultraThinMaterial` below 26, solid when Reduce Transparency is on; glass only on visible panels.
- New design system (`docs/DESIGN.md`) replaces FineTune's tokens and components.

### 3.8 Dictation (F14, P2)

Hotkey via CGEventTap (`flagsChanged`, keycode 63 for Fn), Input Monitoring permission; Accessibility only for paste. Engine per language; models downloaded on demand to `~/Library/Application Support/SilkMic/Models`, unloaded after 5 min idle. Text insertion: pasteboard + synthetic ⌘V, restore clipboard after `changeCount` confirms the read.

## 4. Settings and state

- One versioned JSON settings file in Application Support (FineTune pattern) with migrations; UserDefaults only for trivial UI state.
- Device identity = UID everywhere; never persist `AudioDeviceID`.
- Diagnostics export: settings (no audio), device list, recent log lines.

## 5. Performance and optimization checklist

Idle
- Engine, model and capture stopped when no client reads the virtual mic.
- No polling timers; react to Core Audio property listeners only.
- UI timers and meters run only while a panel is visible.
- App Nap allowed when idle; status item redraw only on state change.

Active audio
- IO threads: no allocation, locks, logging, ARC or Objective-C; preallocated buffers; C callbacks.
- DSP on a dedicated worker with userInteractive QoS; 10 ms hops; bounded queues.
- Model: INT8 Core ML (2.2 MB) if quality matches; compiled once and cached; prewarm on first launch.
- Choose compute units by measured jitter, not assumption.
- vDSP/Accelerate for FFT, resampling and gain.
- Single DFN instance shared by mic path; incoming path gets its own only when enabled.

Memory and disk
- No bundled dictation models; download on demand; unload after idle.
- Release builds: whole-module optimization, `-O`, dead-code stripping, LTO for C targets.

Startup
- Menu-bar ready before the engine starts; engine starts lazily on first client.
- Launch-at-login via `SMAppService.mainApp`.

Energy
- Avoid waking the GPU when idle; glass effects only on visible panels.
- Coalesce device events (debounce) to avoid restart storms.

Reliability
- Watchdog (1 Hz only while active): virtual mic silent while input has signal → restart engine; tap stuck → rebuild; driver missing → safe mode.
- Restore default input on quit/crash; orphan cleanup on launch.
- Logging with `os.Logger`, privacy-safe, low volume.

## 6. Testing

- Keep and run FineTune's and NoNoise's unit tests; driver C tests (`Driver/tests`).
- New unit tests: InputRouter selection rules (table-driven), preset mapping, settings migration.
- DSP golden tests: fixed noisy clips → output within tolerance; latency measured by impulse.
- Performance harness: CPU, memory, latency, jitter per preset; record in `docs/benchmarks.md`.
- Manual matrix (before every release): devices {built-in, QCY BT, AirPods, USB} × apps {WhatsApp voice note + call, Zoom, Meet in Chrome, Discord, Voice Memos, QuickTime} × events {connect, disconnect, sleep/wake, reboot, quit}.

## 7. Build and release

- `xcodebuild` Release, arm64.
- Replace upstream `SUFeedURL` and `SUPublicEDKey` in `Info.plist` with our own feed and a new EdDSA key, otherwise the fork would update itself into FineTune.
- Key custody: the EdDSA private key and the self-signed certificate private key are backed up offline and stored as CI secrets. Losing them breaks updates and mic permission for every user.
- Sign with a stable self-signed code-signing certificate (keeps TCC permissions across updates); document how contributors create their own.
- Move-to-Applications gate on first launch: running from the DMG (App Translocation) breaks `SMAppService`, the driver installer and Sparkle.
- Test a Sparkle update 1.0 → 1.0.1 on macOS 26 and 27 (App Management prompt for apps without a Team ID).
- CI on every PR: build, unit tests, driver C tests, DSP golden tests (adapt FineTune's `ci.yml`).
- Hotkeys: `RegisterEventHotKey` for global shortcuts (no permission); CGEventTap only for the F5 remap and Fn push-to-talk (Input Monitoring).
- Crash diagnostics without telemetry: MetricKit/local crash logs + "Copy diagnostics" button feeding a GitHub issue template.
- Package: `.dmg` (background image, Applications link) + `.zip`; Sparkle appcast with EdDSA signature; GitHub Actions release workflow (FineTune and NoNoise both have one to adapt).
- Installer: first-run privileged step for the driver with a clear explanation.

## 8. Open questions

1. DFN3 latency/jitter on ANE vs CPU on M3 Pro (measure).
2. Does the self-signed certificate keep the mic permission across updates on macOS 27? (test).
3. Does a personal Homebrew tap accept a non-notarized cask? (verify).
4. Apple Sound Isolation AU latency/quality as a second engine (measure).
5. Dynamic Island Macs: notch geometry (test on hardware); detect the cutout by geometry, since `safeAreaInsets.top > 0` may also be true there.
6. Bangla dictation: real WER on real voice notes (benchmark).
7. Sparkle self-update without a Team ID: does macOS 26/27 show the App Management prompt?
8. Echo Guard reference: is the call app's per-app tap enough as AEC far-end reference, and how to detect apps that already run VPIO/WebRTC AEC?

Questions 1, 2 and 7 are Phase 1 go/no-go spikes (ROADMAP 1.10).
