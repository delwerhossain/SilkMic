// SilkMic/Voice/DeviceAlertNotifier.swift
import CoreAudio
import Foundation
import UserNotifications
import VoiceCore
import os

/// Posts "connected" / "disconnected" notifications for real audio devices (earbuds, headsets,
/// USB mics, speakers). FineTune only notified when an app was routed to the device, so plugging
/// in or losing earbuds was silent. Honours Settings > General > Device Disconnect Alerts.
@MainActor
final class DeviceAlertNotifier {
    private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "DeviceAlerts")
    private let isEnabled: () -> Bool
    private var known: [String: String] = [:]   // uid -> name
    private var listener: AudioObjectPropertyListenerBlock?
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var debounce: Task<Void, Never>?

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
        known = Self.realDevices()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.scheduleCheck() }
        }
        listener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
    }

    /// Bluetooth devices appear as several quick list changes; wait for the list to settle.
    private func scheduleCheck() {
        debounce?.cancel()
        debounce = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func check() {
        let now = Self.realDevices()
        defer { known = now }
        guard isEnabled() else { return }
        for (uid, name) in now where known[uid] == nil {
            post(title: "\(name) connected", body: "Ready to use with SilkMic.", id: "connect-\(uid)")
        }
        for (uid, name) in known where now[uid] == nil {
            post(title: "\(name) disconnected", body: "SilkMic switched to the next available device.", id: "disconnect-\(uid)")
        }
    }

    private func post(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error { logger.error("Device alert failed: \(error.localizedDescription)") }
        }
    }

    /// Real devices by UID → name: no aggregates, virtual devices or SilkMic/NoNoise helpers.
    private static func realDevices() -> [String: String] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [:] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [:] }
        var result: [String: String] = [:]
        for id in ids {
            guard let uid = string(id, kAudioDevicePropertyDeviceUID),
                  let name = string(id, kAudioObjectPropertyName) else { continue }
            if VirtualMicRouting.isPhysicalInput(uid: uid, name: name),
               !SilkMicDeviceFilter.isVirtualMic(uid: uid, name: name) {
                result[uid] = name
            }
        }
        return result
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
