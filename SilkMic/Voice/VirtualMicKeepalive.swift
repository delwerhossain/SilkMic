// SilkMic/Voice/VirtualMicKeepalive.swift
import CoreAudio
import Foundation
import os

/// Keeps the SilkMic virtual mic alive while the app runs.
///
/// The driver publishes the visible "SilkMic" mic only while it hears from the app; after 10 s of
/// silence it unplugs the mic, so a crashed, quit or deleted app never leaves every other app
/// recording silence. This writes the driver's `'kpal'` property on the hidden engine device
/// (always published) every few seconds. If the driver is not installed, each tick is a cheap
/// no-op until it appears.
nonisolated final class VirtualMicKeepalive: @unchecked Sendable {
    static let micUID = "SilkMic:visible:48k2ch"
    static let engineUID = "SilkMic:engine:48k2ch"
    private static let selector = AudioObjectPropertySelector(0x6B70_616C) // 'kpal'
    private static let interval: DispatchTimeInterval = .seconds(4)

    private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "Keepalive")
    private let queue = DispatchQueue(label: "app.silkmic.keepalive", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastLoggedFound: Bool?

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: Self.interval, leeway: .milliseconds(500))
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    private func tick() {
        guard let device = Self.resolveDevice(uid: Self.engineUID) else {
            if lastLoggedFound != false { logger.info("SilkMic virtual mic not installed; keepalive idle") }
            lastLoggedFound = false
            return
        }
        var address = AudioObjectPropertyAddress(
            mSelector: Self.selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        // Custom HAL properties carry CFPropertyList data, so the keepalive is a CFNumber.
        var value: CFPropertyList = NSNumber(value: 1)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<CFPropertyList>.size), &value)
        if status != noErr {
            logger.error("Keepalive write failed: \(status)")
        } else if lastLoggedFound != true {
            logger.info("Keepalive running for SilkMic virtual mic")
        }
        lastLoggedFound = status == noErr
    }

    /// Looks the device up by UID each time: AudioObjectIDs change when coreaudiod restarts.
    static func resolveDevice(uid deviceUID: String) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid = deviceUID as CFString
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = withUnsafeMutablePointer(to: &uid) { uidPtr in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address,
                UInt32(MemoryLayout<CFString>.size), uidPtr, &size, &device
            )
        }
        guard status == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }
}
