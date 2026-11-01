# SilkMic — working context (handoff)

Last updated: 2026-11-01. Read this first in a new session; details live in PRD/TRD/ROADMAP/DESIGN/NAMING.

## What SilkMic is

Free, open-source macOS menu-bar app (GPL-3.0) by Delwer Hossain. Repo `github.com/delwerhossain/SilkMic`, local `~/Projects/mac-voice-app` (branch `main`, push freely as delwerhossain — see `~/ClaudeHub/skills/git-commit/repos.md`).
Fork of FineTune (per-app volume, GPL-3.0, history kept, remote `upstream-finetune`) + NoNoise Mac code (MIT, remote `upstream-nonoise`): HAL virtual mic driver + DeepFilterNet3 Core ML.
Pitch: "Free SoundSource + Krisp for Mac, on-device." Logo: Hush Capsule (mic capsule with a wave cut). Brand: Silk Violet `#7B61FF` accent, aurora `#7B61FF → #E15CFF → #4CC9F0` used sparingly.

## Owner decisions (do not re-ask)

- Mac first; Swift + C, no Rust. No Apple Developer ID for now (GitHub DMG, self-signed later). Public repo.
- Noise strength: Light 15 / Balanced 30 (default) / Strong 45 / Max 100 dB.
- UI: native macOS look (System Settings–style settings with sidebar; popup on native popover material); Liquid Glass only on controls/tiles (Control Center style). Notch drop-down panel optional.
- Dictation: Wispr-Flow style, on-device. English via Apple engine (0 MB). Bengali-script output = optional download later (try IndicXlit transliteration ~40 MB first, fallback Whisper-medium Bangla ~500 MB).
- Credits to FineTune / NoNoise (+ MetalVoice/Ghostkwebb) / DynamicNotchKit must stay (About, Acknowledgements, NOTICE).

## What works now (verified on owner's MacBook Pro M3 Pro, macOS 27.2)

- Renamed app `app.silkmic.SilkMic`, own icon, about/licences, 966 unit tests pass.
- Driver `Driver/SilkMicDriver` installed in `/Library/Audio/Plug-Ins/HAL`: visible "SilkMic" mic appears only while the app runs (keepalive `'kpal'` CFNumber on engine device; unplugs mic from device list ~10 s after app quits).
- Clean Mic (`SilkMic/Voice/VoiceController.swift` + `Packages/VoiceCore`): locks default input to SilkMic mic, source mic remembered by UID (built-in default), Bluetooth mics listed, aggregates hidden, engine/capture auto-recover after Bluetooth call-mode switch (QCY works).
- Popup: Control Center–style glass tiles (Clean Mic, Microphone, Noise Removal) — `Views/Voice/VoiceCardView.swift`.
- Notch panel (hover/click, spring) — `Views/Notch/NotchController.swift` (DynamicNotchKit 1.1.0).
- Device connect/disconnect notifications — `Voice/DeviceAlertNotifier.swift`.
- Launch at login default on; FineTune and NoNoise login items removed (they are no longer needed).
- Dictation — `SilkMic/Dictation/`: hold ⌥Space (English, Apple engine) / ⌥⇧Space (Bangla), tap for hands-free; pastes via ⌘V (needs Accessibility); HUD pill under notch. English 0.30 s.
- Optional Bangla-letters model (539 MB, BengaliAI whisper-medium q5_0 via whisper.cpp b5454, `Packages/WhisperCpp`): download/remove in Settings → Shortcuts → Dictation; suggested once by notification after the first Bangla dictation. Installed on the owner's Mac. Test clip: exact Bangla script, ~1.3 s warm (model kept 10 min after use). Without it Bangla uses Apple bn-IN (Latin letters).

## Pending / next

1. Owner tests: dictation with real hotkey (Mic, Speech Recognition, Accessibility permissions), notch hover, QCY speech.
2. Owner feedback on Bangla model accuracy/speed with real voice.
3. MVP rest: mute hotkey + talking-while-muted, Mic Check, Hi-Fi Saver warning UI, raw-mic detector, migration (remove old NoNoise driver), uninstall, menu-bar state icons (drafts in `design/logo/menubar`).
4. Release: Sparkle EdDSA key + own feed (owner keychain), self-signed cert, DMG, README with real before/after demo, launch posts (r/macapps, Show HN, Product Hunt).

## Gotchas

- Always test from `~/Applications` (`scripts/dev-install.sh`); DerivedData builds can't post notifications or register login items.
- In this shell `log` is shadowed — use `/usr/bin/log show ...`.
- Driver install/update needs the owner's admin password (run `Driver/install-driver.sh` in a terminal tab).
- `SpeechTranscriber` locales: only `bn-IN` for Bangla (outputs Latin script); `bn`/`bn-BD` unsupported.
- Max (100 dB) removes all sound between words — silent recordings without speech are expected.
