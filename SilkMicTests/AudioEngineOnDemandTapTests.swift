// SilkMicTests/AudioEngineOnDemandTapTests.swift
import AppKit
import AudioToolbox
import Testing
@testable import SilkMic

/// On-demand taps: an app gets a process tap only while something about its sound is changed
/// (or a global feature needs every app's audio), and loses it when it is back to defaults.
@MainActor
@Suite("AudioEngine — on-demand taps")
struct AudioEngineOnDemandTapTests {
    private struct Fixture {
        let engine: AudioEngine
        let settings: SettingsManager
        let deviceVolume: MockDeviceVolumeProviding
        let app: AudioApp
        let device: AudioDevice
        let created: () -> Int
    }

    @MainActor
    private final class Counter { var taps = 0 }

    private func makeFixture() -> Fixture {
        let settings = SettingsManager(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        let deviceMonitor = MockAudioDeviceMonitor()
        let device = AudioDevice(id: AudioDeviceID(77), uid: "uid-speakers", name: "Speakers",
                                 icon: nil, supportsAutoEQ: true)
        deviceMonitor.addOutputDevice(device)
        let deviceVolume = MockDeviceVolumeProviding(deviceMonitor: deviceMonitor)
        deviceVolume.defaultDeviceUID = device.uid
        deviceVolume.volumes[device.id] = 1

        let app = AudioApp(id: 4242, processObjectIDs: [], name: "Player", icon: NSImage(),
                           bundleID: "com.test.ondemand")
        let processMonitor = StubProcessMonitor()
        processMonitor.activeApps = [app]
        let permission = AudioRecordingPermission()
        permission.status = .authorized
        let counter = Counter()

        let engine = AudioEngine(
            permission: permission,
            settingsManager: settings,
            autoEQProfileManager: AutoEQProfileManager(),
            deviceProvider: deviceMonitor,
            processMonitor: processMonitor,
            deviceVolumeMonitor: deviceVolume,
            tapFactory: { app, uids, _ in
                counter.taps += 1
                return RecordingProcessTapController(app: app, deviceUIDs: uids)
            },
            startMonitorsAutomatically: false
        )
        engine.tapReleaseDelay = .milliseconds(10)
        return Fixture(engine: engine, settings: settings, deviceVolume: deviceVolume,
                       app: app, device: device, created: { counter.taps })
    }

    @Test("An app at its defaults gets no tap")
    func defaultsNoTap() {
        let fix = makeFixture()
        fix.engine.applyPersistedSettings()
        #expect(fix.created() == 0)
        #expect(!fix.engine.needsTap(for: fix.app))
    }

    @Test("Changing the volume creates a tap; returning to 100 % releases it")
    func volumeCreatesAndReleases() async throws {
        let fix = makeFixture()
        fix.engine.applyPersistedSettings()
        fix.engine.setVolume(for: fix.app, to: 0.5)
        #expect(fix.created() == 1)
        #expect(fix.engine.needsTap(for: fix.app))

        fix.engine.setVolume(for: fix.app, to: 1.0)
        #expect(!fix.engine.needsTap(for: fix.app))
        try await Task.sleep(for: .milliseconds(80))
        fix.engine.setVolume(for: fix.app, to: 0.6)   // a fresh tap proves the old one was released
        #expect(fix.created() == 2)
    }

    @Test("Mute, boost, a chosen device and a non-flat EQ each need a tap")
    func eachChangeNeedsTap() {
        let fix = makeFixture()
        fix.engine.applyPersistedSettings()

        fix.engine.setMute(for: fix.app, to: true)
        #expect(fix.engine.needsTap(for: fix.app))
        fix.engine.setMute(for: fix.app, to: false)

        fix.engine.setBoost(for: fix.app, to: .x2)
        #expect(fix.engine.needsTap(for: fix.app))
        fix.engine.setBoost(for: fix.app, to: .x1)

        fix.engine.setEQSettings(EQSettings(bandGains: [3, 0, 0, 0, 0, 0, 0, 0, 0, 0], isEnabled: true), for: fix.app)
        #expect(fix.engine.needsTap(for: fix.app))
        fix.engine.setEQSettings(.flat, for: fix.app)
        #expect(!fix.engine.needsTap(for: fix.app))

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)
        #expect(fix.engine.needsTap(for: fix.app))
        #expect(fix.created() >= 1)
    }

    @Test("A software-volume output needs taps for every app")
    func softwareVolumeNeedsTaps() {
        let fix = makeFixture()
        fix.deviceVolume.overridesByUID[fix.device.uid] = .software
        fix.engine.applyPersistedSettings()
        #expect(fix.engine.needsTap(for: fix.app))
        #expect(fix.created() == 1)
    }

    @Test("Enabled AutoEQ on the output needs taps")
    func autoEQNeedsTaps() {
        let fix = makeFixture()
        fix.settings.setAutoEQSelection(for: fix.device.uid, to: AutoEQSelection(profileID: "p", isEnabled: true))
        #expect(fix.engine.needsTap(for: fix.app))
    }
}
