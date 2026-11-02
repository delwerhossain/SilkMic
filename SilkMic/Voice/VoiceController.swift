// SilkMic/Voice/VoiceController.swift
import AVFoundation
import Combine
import CoreAudio
import Foundation
import Observation
import VoiceCore
import os

/// How strongly Clean Mic removes noise. Maps to DeepFilterNet3's attenuation limit.
/// Balanced is the default: unlimited attenuation (Max) gates the room to silence between words,
/// which sounds like dropouts.
enum NoiseStrength: String, CaseIterable, Identifiable, Codable {
    case light, balanced, strong, max

    var id: String { rawValue }

    var attenuationDb: Float {
        switch self {
        case .light: return 15
        case .balanced: return 30
        case .strong: return 45
        case .max: return VoicePreset.maxAttenuationDb
        }
    }

    var title: String {
        switch self {
        case .light: return "Light"
        case .balanced: return "Balanced"
        case .strong: return "Strong"
        case .max: return "Max"
        }
    }
}

/// Clean Mic: owns the voice engine (VoiceCore.AudioModel) and keeps the system default input on
/// the SilkMic virtual mic, so every app that uses the default mic gets cleaned audio.
@MainActor
@Observable
final class VoiceController {
    private enum Keys {
        static let cleanEnabled = "silkmic.cleanEnabled"
        static let strength = "silkmic.noiseStrength"
    }

    private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "Voice")
    @ObservationIgnored let model: AudioModel
    @ObservationIgnored private weak var audioEngine: AudioEngine?
    @ObservationIgnored private var devicesListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    /// Clean on: DeepFilterNet3 runs. Off: the same virtual mic passes the voice through, so apps
    /// never see a device change mid-call.
    var cleanEnabled: Bool {
        didSet {
            UserDefaults.standard.set(cleanEnabled, forKey: Keys.cleanEnabled)
            model.isAIEnabled = cleanEnabled
        }
    }

    var strength: NoiseStrength {
        didSet {
            UserDefaults.standard.set(strength.rawValue, forKey: Keys.strength)
            applyStrength()
        }
    }

    /// Physical mics SilkMic can clean (own and other virtual mics excluded). Mirrored from the
    /// engine's published list so SwiftUI views update.
    private(set) var sourceMics: [(id: String, name: String)] = []

    /// The mic SilkMic is cleaning right now (Core Audio device UID).
    var selectedSourceMicID: String = "" {
        didSet {
            if model.selectedInputDeviceID != selectedSourceMicID { model.selectedInputDeviceID = selectedSourceMicID }
        }
    }
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    /// Picks the physical mic SilkMic cleans. Ignored if it is not a usable source mic.
    func selectSourceMic(uid: String) {
        guard model.inputDevices.contains(where: { $0.uniqueID == uid }) else {
            logger.info("Ignoring source mic that is not available for capture: \(uid, privacy: .public)")
            return
        }
        selectedSourceMicID = uid
    }

    // MARK: - Output (for the notch panel)

    /// Speakers and headphones people can switch to (SilkMic's own devices and helper aggregates hidden).
    var outputDevices: [AudioDevice] {
        (audioEngine?.outputDevices ?? []).filter {
            !SilkMicDeviceFilter.isVirtualMic(uid: $0.uid, name: $0.name)
                && !SilkMicDeviceFilter.isHelperAggregate(name: $0.name)
        }
    }

    var defaultOutputUID: String? { audioEngine?.deviceVolumeMonitor.defaultDeviceUID }

    /// Makes `device` the system output (apps that follow the default move with it).
    func selectOutput(_ device: AudioDevice) {
        audioEngine?.setDefaultOutputDevice(device.id)
    }

    init(audioEngine: AudioEngine) {
        let defaults = UserDefaults.standard
        cleanEnabled = defaults.object(forKey: Keys.cleanEnabled) as? Bool ?? true
        strength = NoiseStrength(rawValue: defaults.string(forKey: Keys.strength) ?? "") ?? .balanced
        model = AudioModel()
        self.audioEngine = audioEngine
        model.isAIEnabled = cleanEnabled
        applyStrength()
        model.$inputDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in self?.sourceMics = devices.map { ($0.uniqueID, $0.localizedName) } }
            .store(in: &cancellables)
        model.$selectedInputDeviceID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                guard let self, self.selectedSourceMicID != id else { return }
                self.selectedSourceMicID = id
            }
            .store(in: &cancellables)
        installDeviceListener()
        lockDefaultInputToVirtualMic()
        // The driver publishes the mic only after the first keepalive; retry briefly after launch.
        Task { @MainActor [weak self] in
            for _ in 0..<10 {
                try? await Task.sleep(for: .seconds(1))
                self?.lockDefaultInputToVirtualMic()
            }
        }
    }

    private func applyStrength() {
        model.selectedPreset = .custom
        model.suppressionStrength = 1.0
        model.attenuationLimitDb = strength.attenuationDb
    }

    /// The virtual mic appears a moment after launch (driver keepalive), so re-check on every
    /// device-list change.
    private func installDeviceListener() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // The engine's device monitor refreshes its own list asynchronously after the same
            // event, so check again shortly after instead of racing it.
            Task { @MainActor in
                for delay in [0.3, 1.0, 2.5] {
                    try? await Task.sleep(for: .seconds(delay))
                    self?.lockDefaultInputToVirtualMic()
                }
            }
        }
        devicesListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, .main, block)
    }

    /// Makes "SilkMic" the default input (and the locked one, so macOS auto-switching to newly
    /// connected earbuds is reverted). Uses the FineTune input lock that SilkMic inherited.
    private func lockDefaultInputToVirtualMic() {
        guard let engine = audioEngine,
              let mic = engine.deviceMonitor.inputDevice(for: VirtualMicRouting.visibleDeviceUID) else { return }
        guard engine.deviceVolumeMonitor.defaultInputDeviceUID != mic.uid
                || engine.settingsManager.lockedInputDeviceUID != mic.uid else { return }
        logger.info("Locking default input to the SilkMic virtual mic")
        engine.setLockedInputDevice(mic)
    }
}
