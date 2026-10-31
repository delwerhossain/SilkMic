// SilkMic/Dictation/DictationController.swift
import AVFoundation
import AppKit
import ApplicationServices
import KeyboardShortcuts
import Observation
import os

extension KeyboardShortcuts.Name {
    /// Hold to dictate in English (tap once for hands-free, tap again to stop).
    static let dictateEnglish = Self("silkmic.dictate.english", default: .init(.space, modifiers: [.option]))
    /// Hold to dictate in Bangla.
    static let dictateBangla = Self("silkmic.dictate.bangla", default: .init(.space, modifiers: [.option, .shift]))
}

/// Wispr Flow–style dictation: hold a hotkey, speak, release — the text is typed into the app
/// you are in. Audio comes from the system default input, which is the SilkMic clean mic, so
/// dictation hears the noise-free voice. Everything runs on device.
@MainActor
@Observable
final class DictationController {
    enum Phase: Equatable {
        case idle
        case preparing(DictationLanguage)
        case listening(DictationLanguage)
        case transcribing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Input level 0…1 for the HUD meter while listening.
    private(set) var level: Float = 0

    @ObservationIgnored private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "Dictation")
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var engineBox: AnyObject?
    @ObservationIgnored private var pressStartedAt: Date?
    @ObservationIgnored private var handsFree = false
    @ObservationIgnored private lazy var hud = DictationHUD(controller: self)

    /// A press shorter than this is a tap: dictation stays on until the next tap.
    private static let tapThreshold: TimeInterval = 0.35

    init() {
        for (name, language) in [(KeyboardShortcuts.Name.dictateEnglish, DictationLanguage.english),
                                 (.dictateBangla, .bangla)] {
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in self?.keyDown(language) }
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in self?.keyUp() }
        }
    }

    // MARK: - Hotkey state machine

    private func keyDown(_ language: DictationLanguage) {
        switch phase {
        case .idle, .failed:
            pressStartedAt = Date()
            handsFree = false
            Task { await start(language) }
        case .listening where handsFree:
            Task { await stopAndInsert() }
        default:
            break
        }
    }

    private func keyUp() {
        guard case .listening = phase, !handsFree else {
            if case .preparing = phase, let start = pressStartedAt,
               Date().timeIntervalSince(start) < Self.tapThreshold {
                handsFree = true
            }
            return
        }
        if let start = pressStartedAt, Date().timeIntervalSince(start) < Self.tapThreshold {
            handsFree = true   // quick tap: keep listening until the next tap
            return
        }
        Task { await stopAndInsert() }
    }

    // MARK: - Recording

    private func start(_ language: DictationLanguage) async {
        guard #available(macOS 26.0, *) else {
            fail("Dictation needs macOS 26 or later.")
            return
        }
        phase = .preparing(language)
        hud.show()
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            fail("Allow microphone access for SilkMic in System Settings.")
            return
        }
        let engine = SpeechEngine()
        do {
            try await engine.start(language: language)
        } catch {
            fail("Could not start \(language.title) dictation.")
            logger.error("Dictation start failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        engineBox = engine
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, engine] buffer, _ in
            engine.append(buffer)
            let level = Self.rms(buffer)
            Task { @MainActor in self?.level = level }
        }
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            fail("Could not open the microphone.")
            return
        }
        // The key may already be up (a quick tap) while the model was loading.
        phase = .listening(language)
        if !handsFree, let start = pressStartedAt, Date().timeIntervalSince(start) >= Self.tapThreshold,
           !KeyboardShortcuts.isAnyDictationKeyDown {
            await stopAndInsert()
        }
    }

    private func stopAndInsert() async {
        guard #available(macOS 26.0, *), let engine = engineBox as? SpeechEngine else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        level = 0
        phase = .transcribing
        let text = await engine.finish()
        engineBox = nil
        if text.isEmpty {
            phase = .idle
            hud.hide()
            return
        }
        TextInserter.insert(text)
        phase = .idle
        hud.hide()
    }

    func cancel() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        if #available(macOS 26.0, *) { (engineBox as? SpeechEngine)?.cancel() }
        engineBox = nil
        phase = .idle
        hud.hide()
    }

    private func fail(_ message: String) {
        phase = .failed(message)
        hud.show()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, case .failed = self.phase else { return }
            self.phase = .idle
            self.hud.hide()
        }
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) { sum += data[i] * data[i] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        return min(1, rms * 8)
    }
}

private extension KeyboardShortcuts {
    /// True while either dictation hotkey's key is still physically held.
    @MainActor static var isAnyDictationKeyDown: Bool {
        for name in [KeyboardShortcuts.Name.dictateEnglish, .dictateBangla] {
            if let key = getShortcut(for: name)?.carbonKeyCode,
               CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(key)) {
                return true
            }
        }
        return false
    }
}

/// Puts text into the focused app: pasteboard + ⌘V, then restores the previous clipboard.
/// Needs Accessibility permission to send the keystroke.
enum TextInserter {
    @MainActor static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCount = pasteboard.changeCount

        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) else {
            // Without Accessibility the text stays on the clipboard so it can be pasted by hand.
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore the old clipboard once the target app has read ours.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard pasteboard.changeCount == changeCount, let previous else { return }
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
    }
}
