// WhisperCpp/WhisperModel.swift — thin Swift wrapper over whisper.cpp's C API.
import Foundation
@_exported import whisper

/// One loaded Whisper model. Load once, transcribe many short clips (16 kHz mono Float32).
public final class WhisperModel: @unchecked Sendable {
    private let context: OpaquePointer
    private let lock = NSLock()

    public init?(path: String) {
        var params = whisper_context_default_params()
        params.use_gpu = true
        guard let ctx = whisper_init_from_file_with_params(path, params) else { return nil }
        context = ctx
    }

    deinit { whisper_free(context) }

    /// Greedy decoding: fastest, and accurate enough for short dictation takes.
    public func transcribe(samples: [Float], language: String) -> String {
        lock.lock(); defer { lock.unlock() }
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false
        params.no_timestamps = true
        params.single_segment = false
        params.n_threads = Int32(max(2, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        let code = language.withCString { lang -> Int32 in
            params.language = lang
            return samples.withUnsafeBufferPointer { buf in
                whisper_full(context, params, buf.baseAddress, Int32(buf.count))
            }
        }
        guard code == 0 else { return "" }
        var text = ""
        for i in 0..<whisper_full_n_segments(context) {
            if let cstr = whisper_full_get_segment_text(context, i) { text += String(cString: cstr) }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
