# SilkMic

**Clean voice in every app, smart mic switching and per-app volume for Mac. Free, open source and on-device.**

> Status: in development. No release yet. Follow the plan in [`docs/ROADMAP.md`](docs/ROADMAP.md).

## What SilkMic does

- **Clean Mic everywhere** — AI noise removal (DeepFilterNet3) on a virtual microphone, so WhatsApp, Zoom, Meet, Discord, Voice Memos and every other app get a clean voice with no setup. One toggle; Light / Balanced / Strong / Max / Auto strength.
- **Smart Mic + Hi-Fi Saver** — picks the right mic automatically and keeps your Bluetooth earbuds in high-quality mode.
- **Mute Everywhere** — one hotkey, clear state, and a heads-up if you talk while muted.
- **Mic Check** — hear yourself before and after cleaning.
- **App Mixer** — per-app volume, mute and output device.
- Later: clean incoming call audio, echo guard, scenes, a notch panel, and push-to-talk dictation (English and Bangla).

Everything runs on your Mac. No account, no cloud, no telemetry.

## Requirements

macOS 15.4 or later on Apple Silicon. Liquid Glass styling on macOS 26 and later.

## Docs

- Product requirements: [`docs/PRD.md`](docs/PRD.md)
- Technical design: [`docs/TRD.md`](docs/TRD.md)
- Roadmap and tasks: [`docs/ROADMAP.md`](docs/ROADMAP.md)
- Design direction: [`docs/DESIGN.md`](docs/DESIGN.md)

## Build

Open `SilkMic.xcodeproj` in Xcode 26 or later and run the `SilkMic` scheme, or:

```bash
xcodebuild -project SilkMic.xcodeproj -scheme SilkMic -configuration Debug build
```

## Built on

SilkMic stands on two open-source projects and keeps their licences:

- [FineTune](https://github.com/ronitsingh10/FineTune) by Ronit Singh — per-app audio engine (GPL-3.0). SilkMic is a fork of FineTune.
- [NoNoise-Mac](https://github.com/ivalsaraj/NoNoise-Mac) by ivalsaraj, based on MetalVoice by Ghostkwebb — virtual mic driver and DeepFilterNet3 pipeline (MIT).

See [`NOTICE`](NOTICE) for all third-party notices.

## Licence

GPL-3.0. See [`LICENSE`](LICENSE).
