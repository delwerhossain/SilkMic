// SilkMic/Voice/SilkMicDeviceFilter.swift
import Foundation
import VoiceCore

/// Which audio devices SilkMic hides from people: helper aggregates and virtual mics.
enum SilkMicDeviceFilter {
    /// Aggregates created by the system or by SilkMic's own per-app taps.
    static func isHelperAggregate(name: String) -> Bool {
        VirtualMicRouting.helperAggregatePrefixes.contains { name.hasPrefix($0) }
    }

    /// SilkMic's own virtual devices and other virtual mics (e.g. NoNoise).
    static func isVirtualMic(uid: String, name: String) -> Bool {
        uid == VirtualMicRouting.visibleDeviceUID
            || uid == VirtualMicRouting.engineDeviceUID
            || VirtualMicRouting.filterInputs([name]).isEmpty
    }
}
