// SilkMic/Dictation/DictationController.swift
import AVFoundation
import AppKit
import ApplicationServices
import KeyboardShortcuts
import Observation
import UserNotifications
import WhisperCpp
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
    /// Bengali-script path: 16 kHz mono samples for whisper.cpp (nil when Apple's engine is used).
    @ObservationIgnored private var whisperSamples: [Float]?
    @ObservationIgnored private let whisperCollector = SampleCollector()
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
        let useWhisper = language == .bangla && BanglaModelManager.shared.isInstalled
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        if useWhisper {
            // Bengali script via the downloaded Whisper model; warm it while the user talks.
            BanglaModelManager.shared.preload()
            engineBox = nil
            whisperCollector.reset(inputFormat: format)
            let collector = whisperCollector
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                collector.append(buffer)
                let level = Self.rms(buffer)
                Task { @MainActor in self?.level = level }
            }
        } else {
            let engine = SpeechEngine()
            do {
                try await engine.start(language: language)
            } catch {
                fail("Could not start \(language.title) dictation.")
                logger.error("Dictation start failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            engineBox = engine
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, engine] buffer, _ in
                engine.append(buffer)
                let level = Self.rms(buffer)
                Task { @MainActor in self?.level = level }
            }
        }
        currentLanguage = language
        usingWhisper = useWhisper
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

    @ObservationIgnored private var currentLanguage: DictationLanguage = .english
    @ObservationIgnored private var usingWhisper = false

    private func stopAndInsert() async {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        level = 0
        phase = .transcribing
        var text = ""
        if usingWhisper {
            let samples = whisperCollector.drain()
            if let model = await BanglaModelManager.shared.model(), samples.count > 8_000 {
                text = await Task.detached(priority: .userInitiated) { model.transcribe(samples: samples, language: "bn") }.value
            }
        } else if #available(macOS 26.0, *), let engine = engineBox as? SpeechEngine {
            text = await engine.finish()
        }
        engineBox = nil
        if currentLanguage == .bangla && !usingWhisper { suggestBanglaModelOnce() }
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

    /// First Bangla dictation without the script model: suggest it once (it is optional).
    private func suggestBanglaModelOnce() {
        let key = "silkmic.banglaModelSuggested"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let content = UNMutableNotificationContent()
        content.title = "Write Bangla in Bangla letters?"
        content.body = "Download the optional Bangla model (\(BanglaModelManager.sizeLabel)) in SilkMic Settings → Shortcuts → Dictation. Without it, Bangla is written in English letters."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "bangla-model-suggestion", content: content, trigger: nil))
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


/// Collects tap audio as 16 kHz mono Float32 for whisper.cpp. Thread-safe (tap thread writes).
final class SampleCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    func reset(inputFormat: AVAudioFormat) {
        lock.lock(); defer { lock.unlock() }
        samples.removeAll(keepingCapacity: true)
        converter = AVAudioConverter(from: inputFormat, to: target)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let data = out.floatChannelData?[0], out.frameLength > 0 else { return }
        lock.lock(); defer { lock.unlock() }
        samples.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(out.frameLength)))
    }

    func drain() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        let result = samples
        samples.removeAll()
        return result
    }
}
