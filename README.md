<p align="center">
  <img src="design/logo/export/silkmic-symbol-app-icon.svg" width="112" height="112" alt="SilkMic app icon">
</p>

<h1 align="center">SilkMic: free AI noise cancellation and dictation for Mac</h1>

<p align="center">
  <b>Clean voice in every app, one-click mic and speaker switching, per-app volume and push-to-talk dictation.</b><br>
  Free, open source, on-device. A free Krisp alternative for macOS.
</p>

<p align="center">
  <a href="https://github.com/delwerhossain/SilkMic/releases/latest"><img src="assets/download-badge.svg" alt="Download SilkMic for macOS" height="44"></a>
</p>

<p align="center">
  <img alt="macOS 15.4+" src="https://img.shields.io/badge/macOS-15.4%2B-black?logo=apple">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-M1%E2%80%93M5-7B61FF">
  <img alt="License GPL-3.0" src="https://img.shields.io/badge/license-GPL--3.0-blue">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
</p>

---

SilkMic removes background noise from your microphone in **every app on your Mac**: Zoom, Google Meet, Microsoft Teams, Discord, Slack, WhatsApp, FaceTime, OBS, QuickTime and your browser. It runs the DeepFilterNet3 AI model on your Mac's Neural Engine, so your voice never leaves your computer. No account, no subscription, no cloud and no telemetry.

## Features

- **Clean Mic everywhere.** AI noise removal on a virtual microphone called "SilkMic". Fans, keyboards, traffic, cafés and barking dogs fade out; your voice stays. Pick Light, Balanced, Strong or Max.
- **Works with any mic.** Built-in MacBook mic, USB mics and Bluetooth earbuds (AirPods and others). SilkMic remembers your choice and recovers by itself when Bluetooth switches to call mode.
- **Notch panel.** On a MacBook with a notch, hover the notch to switch microphone and speakers, turn Clean Mic on or off and change the noise level, all in one small Liquid Glass panel.
- **Dictation, Wispr Flow style.** Hold the Fn (Globe) key, speak, let go: the text is typed into any app. English uses Apple's on-device speech engine (no download). Bangla in Bengali script is an optional on-device model you can add in Settings.
- **Per-app volume mixer.** Set volume, mute and output device for each app, with EQ, from the menu bar.
- **Device alerts.** A notification when a mic or headphones connect or disconnect.
- **Native macOS design.** Menu-bar app with System Settings-style preferences and Liquid Glass on macOS 26 Tahoe.

Everything runs locally on your Mac.

## Download and install

1. Download **SilkMic-x.y.z.dmg** from the [latest release](https://github.com/delwerhossain/SilkMic/releases/latest).
2. Open the DMG and drag **SilkMic** to **Applications**.
3. Open SilkMic. SilkMic is free and not yet signed with a paid Apple Developer ID, so macOS stops the first launch. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. You only do this once.
4. SilkMic asks to install its microphone. Click **Install** and enter your Mac password. Sound stops for a second while it installs.
5. Allow microphone access when macOS asks.
6. In Zoom, Meet, Discord or any other app, choose **SilkMic** as the microphone. SilkMic also sets it as the Mac's default input for you.

For dictation, also allow Accessibility (so SilkMic can type for you) and set **System Settings → Keyboard → Press 🌐 key to → Do Nothing**.

## Requirements

- Mac with Apple Silicon (M1 or later)
- macOS 15.4 or later; dictation and Liquid Glass need macOS 26 Tahoe or later
- About 40 MB of disk space (15 MB download) (plus 539 MB if you add the optional Bangla dictation model)

## FAQ

**Is SilkMic really free?** Yes. It is free and open source under GPL-3.0, with no paid tier.

**Does my voice go to a server?** No. Noise removal and dictation run on your Mac. SilkMic has no account and sends no telemetry.

**How is it different from Krisp?** Krisp is a paid cloud-account app. SilkMic is free, open source and fully on-device.

**How do I uninstall SilkMic?** Quit SilkMic, delete it from Applications, then remove `/Library/Audio/Plug-Ins/HAL/SilkMicDriver.driver` (needs your password) and restart the Mac.

## Build from source

You need Xcode 26 or later.

```bash
git clone https://github.com/delwerhossain/SilkMic.git
cd SilkMic
Driver/build-driver.sh && Driver/install-driver.sh   # virtual mic, asks for your password
scripts/dev-install.sh                               # builds and opens ~/Applications/SilkMic.app
```

`scripts/build-dmg.sh` makes the same DMG as a release. Design docs: [`docs/PRD.md`](docs/PRD.md), [`docs/TRD.md`](docs/TRD.md), [`docs/ROADMAP.md`](docs/ROADMAP.md). Contributions are welcome: see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Credits

SilkMic is made by [Delwer Hossain](https://github.com/delwerhossain). It is built on open-source work and keeps its licences:

- [FineTune](https://github.com/ronitsingh10/FineTune) by Ronit Singh: per-app audio engine (GPL-3.0). SilkMic started as a fork of FineTune.
- [NoNoise Mac](https://github.com/ivalsaraj/NoNoise-Mac) by ivalsaraj, based on MetalVoice by Ghostkwebb: virtual mic driver and DeepFilterNet3 pipeline (MIT).
- [DeepFilterNet](https://github.com/Rikorose/DeepFilterNet), [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) and the other packages in [`NOTICE`](NOTICE).

## License

SilkMic is licensed under the [GNU General Public License v3.0](LICENSE). Copyright (C) 2026 Delwer Hossain.
