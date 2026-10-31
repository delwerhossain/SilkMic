// SilkMic/Dictation/SpeechEngine.swift
import AVFoundation
import Foundation
import Speech
import os

/// Languages SilkMic can dictate. Both run fully on device with Apple's SpeechAnalyzer
/// (macOS 26+); the models are system assets, so SilkMic ships no model files.
enum DictationLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case bangla

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en-US")
        case .bangla: return Locale(identifier: "bn-IN")
        }
    }

    var title: String {
        switch self {
        case .english: return "English"
        case .bangla: return "বাংলা"
        }
    }
}

/// One dictation take: stream audio buffers in, get the final text out.
@available(macOS 26.0, *)
final class SpeechEngine {
    private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "Dictation")
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<String, Error>?
    private var converter: AVAudioConverter?
    private(set) var analyzerFormat: AVAudioFormat?

    /// Downloads the language model once if macOS does not have it yet.
    static func prepare(_ language: DictationLanguage) async throws {
        let transcriber = SpeechTranscriber(locale: language.locale, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    func start(language: DictationLanguage) async throws {
        let transcriber = SpeechTranscriber(locale: language.locale, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation
        resultsTask = Task {
            var text = ""
            for try await result in transcriber.results where result.isFinal {
                text += String(result.text.characters)
            }
            return text
        }
        try await analyzer.start(inputSequence: stream)
        self.analyzer = analyzer
    }

    /// Called from the audio tap: converts to the analyzer's format and queues the buffer.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let target = analyzerFormat, let continuation = inputContinuation else { return }
        if buffer.format == target {
            continuation.yield(AnalyzerInput(buffer: buffer))
            return
        }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
        }
        guard let converter else { return }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, out.frameLength > 0 {
            continuation.yield(AnalyzerInput(buffer: out))
        }
    }

    /// Ends the take and returns the transcript (empty if nothing was understood).
    func finish() async -> String {
        inputContinuation?.finish()
        inputContinuation = nil
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
            let text = try await resultsTask?.value ?? ""
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    func cancel() {
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        Task { [analyzer] in await analyzer?.cancelAndFinishNow() }
    }
}
