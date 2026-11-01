// SilkMic/Dictation/BanglaModelManager.swift
import Foundation
import Observation
import WhisperCpp
import os

/// Optional Bengali-script dictation model. Not bundled (it is 539 MB): SilkMic suggests it the
/// first time someone dictates in Bangla, and downloads it only on request.
/// Model: BengaliAI whisper-medium fine-tune (Apache-2.0), whisper.cpp q5_0 build.
@MainActor
@Observable
final class BanglaModelManager {
    static let shared = BanglaModelManager()
    enum State: Equatable {
        case notInstalled
        case downloading(progress: Double)
        case installed
        case failed(String)
    }

    nonisolated static let fileName = "ggml-bengaliai-whisper-medium-q5_0.bin"
    static let downloadURL = URL(string: "https://huggingface.co/winshades/bengaliai-whisper-medium-ggml/resolve/main/ggml-bengaliai-whisper-medium-q5_0.bin")!
    static let sizeLabel = "539 MB"
    static let expectedBytes: Int64 = 539_257_671

    private(set) var state: State = .notInstalled
    @ObservationIgnored private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "BanglaModel")
    @ObservationIgnored private var task: URLSessionDownloadTask?
    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored private var loaded: WhisperModel?
    @ObservationIgnored private var unloadTask: Task<Void, Never>?

    nonisolated static var modelsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SilkMic/Models", isDirectory: true)
    }

    nonisolated static var modelURL: URL { modelsDirectory.appendingPathComponent(fileName) }

    init() {
        refresh()
    }

    var isInstalled: Bool { state == .installed }

    func refresh() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: Self.modelURL.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        if size == Self.expectedBytes {
            state = .installed
        } else if case .downloading = state {
            // keep showing progress
        } else {
            state = .notInstalled
        }
    }

    func download() {
        guard task == nil else { return }
        try? FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
        state = .downloading(progress: 0)
        let task = URLSession.shared.downloadTask(with: Self.downloadURL) { [weak self] tempURL, _, error in
            var moveError: Error?
            if let tempURL {
                do {
                    try? FileManager.default.removeItem(at: Self.modelURL)
                    try FileManager.default.moveItem(at: tempURL, to: Self.modelURL)
                } catch { moveError = error }
            }
            Task { @MainActor in
                guard let self else { return }
                self.task = nil
                self.observation = nil
                if let error = error ?? moveError {
                    self.logger.error("Bangla model download failed: \(error.localizedDescription, privacy: .public)")
                    self.state = .failed("Download failed. Check your connection and try again.")
                } else {
                    self.state = .notInstalled
                    self.refresh()
                    if self.state != .installed { self.state = .failed("The download was incomplete. Try again.") }
                }
            }
        }
        observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let value = progress.fractionCompleted
            Task { @MainActor in
                if case .downloading = self?.state { self?.state = .downloading(progress: value) }
            }
        }
        self.task = task
        task.resume()
    }

    func cancelDownload() {
        task?.cancel()
        task = nil
        observation = nil
        state = .notInstalled
    }

    func remove() {
        loaded = nil
        try? FileManager.default.removeItem(at: Self.modelURL)
        refresh()
    }

    /// Loads the model (kept in memory for 10 minutes after the last use so repeat dictation is
    /// fast, then released to free ~600 MB).
    nonisolated func model() async -> WhisperModel? {
        await MainActor.run { self.unloadTask?.cancel() }
        if let existing = await MainActor.run(body: { self.loaded }) {
            await scheduleUnload()
            return existing
        }
        let path = Self.modelURL.path
        let model = await Task.detached(priority: .userInitiated) { WhisperModel(path: path) }.value
        await MainActor.run { self.loaded = model }
        await scheduleUnload()
        return model
    }

    /// Warm the model when the Bangla hotkey is pressed, so it is ready when the user stops talking.
    nonisolated func preload() {
        Task { _ = await model() }
    }

    private func scheduleUnload() {
        unloadTask?.cancel()
        unloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(600))
            guard !Task.isCancelled else { return }
            self?.loaded = nil
        }
    }
}
