# Contributing to SilkMic

Thanks for helping make SilkMic better. Bug reports, ideas, translations and pull requests are all welcome.

## Building from source

You need a Mac with Apple Silicon and Xcode 26 or later.

1. Clone the repository:
   ```bash
   git clone https://github.com/delwerhossain/SilkMic.git
   cd SilkMic
   ```
2. Build and install the virtual mic driver (asks for your password; sound drops for a second):
   ```bash
   Driver/build-driver.sh && Driver/install-driver.sh
   ```
3. Build and open the app from `~/Applications` (notifications, login items and permissions only work there):
   ```bash
   scripts/dev-install.sh
   ```
4. Run the tests:
   ```bash
   xcodebuild test -project SilkMic.xcodeproj -scheme SilkMic -destination 'platform=macOS'
   ```

`scripts/build-dmg.sh` builds the release DMG (driver bundled, ad-hoc signed).

## Submitting Issues

- Check existing issues before creating a new one
- Include macOS version and steps to reproduce
- For audio issues, include which apps were playing audio
- For mic issues, include the microphone (built-in, USB or Bluetooth model) and the Clean Mic level

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test with multiple audio sources and output devices, and run the tests
5. Commit your changes
6. Push to your fork and open a pull request

## Code Style

- Follow existing patterns in the codebase
- Use `@Observable` and `@MainActor` for state management
- Audio callback code must be real-time safe (no allocations, locks, or ObjC)
- Views: props first, callbacks for mutations, `@State` only for local UI state

## Audio Callback Guidelines

Code running in `processAudio()` must be real-time safe:

- No memory allocations (`malloc`, `new`, `Array.append`)
- No locks (`NSLock`, `DispatchSemaphore`, `os_unfair_lock`)
- No Objective-C messaging
- No file I/O or logging
- No Swift `print()` statements

## Testing

Before submitting:
- Test with 2+ output devices
- Test device hot-plug (disconnect during playback)
- Test with 5+ apps playing audio simultaneously

## Licence

By contributing, you agree that your contributions are licensed under the GPL-3.0, the same licence as SilkMic.
