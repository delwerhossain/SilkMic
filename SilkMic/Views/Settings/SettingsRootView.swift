// SilkMic/Views/Settings/SettingsRootView.swift
// Modified by Delwer Hossain, 2026: System Settings–style sidebar layout for SilkMic.
import SwiftUI

@MainActor
struct SettingsRootView: View {
    @Bindable var settings: SettingsManager
    @Bindable var audioEngine: AudioEngine
    @Bindable var deviceVolumeMonitor: DeviceVolumeMonitor
    @Bindable var accessibility: AccessibilityPermissionService
    @Bindable var mediaKeyStatus: MediaKeyStatus
    let mediaKeyMonitor: MediaKeyMonitor
    let shortcutsRegistry: ShortcutsRegistry
    @ObservedObject var updateManager: UpdateManager

    enum Section: String, Hashable, CaseIterable, Identifiable {
        case general, audio, shortcuts, updates, about
        var id: Self { self }

        var title: String {
            switch self {
            case .general: return "General"
            case .audio: return "Audio"
            case .shortcuts: return "Shortcuts"
            case .updates: return "Updates"
            case .about: return "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: return "gearshape.fill"
            case .audio: return "speaker.wave.2.fill"
            case .shortcuts: return "command"
            case .updates: return "arrow.triangle.2.circlepath"
            case .about: return "info.circle.fill"
            }
        }

        /// Icon tile colour, like the coloured squares in macOS System Settings.
        var tileColor: Color {
            switch self {
            case .general: return Color(nsColor: .systemGray)
            case .audio: return Color(nsColor: .systemPink)
            case .shortcuts: return Color(nsColor: .systemBlue)
            case .updates: return Color(nsColor: .systemGreen)
            case .about: return SilkPalette.violet
            }
        }
    }

    @State private var selection: Section? = .general

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    SettingsIconTile(symbol: section.symbol, color: section.tileColor)
                }
                .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            detail(for: selection ?? .general)
                .navigationTitle((selection ?? .general).title)
        }
        .frame(width: 760, height: 560)
        .preferredColorScheme(settings.appSettings.appearance.swiftUIColorScheme)
        .background(WindowAppearanceBridge(appearance: settings.appSettings.appearance.nsAppearance))
        .background(WindowTitleBridge(title: "SilkMic Settings"))
    }

    @ViewBuilder
    private func detail(for section: Section) -> some View {
        switch section {
        case .general:
            GeneralTab(
                settings: settings,
                onResetAll: {
                    audioEngine.handleSettingsReset()
                    deviceVolumeMonitor.setSystemFollowDefault()
                }
            )
        case .audio:
            AudioTab(
                settings: settings,
                audioEngine: audioEngine,
                deviceVolumeMonitor: deviceVolumeMonitor
            )
        case .shortcuts:
            ShortcutsTab(
                settings: settings,
                accessibility: accessibility,
                mediaKeyStatus: mediaKeyStatus,
                mediaKeyMonitor: mediaKeyMonitor,
                shortcutsRegistry: shortcutsRegistry
            )
        case .updates:
            UpdatesTab(updateManager: updateManager)
        case .about:
            AboutTab()
        }
    }
}

/// Small rounded-square icon with a white symbol, as in macOS System Settings.
struct SettingsIconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(color.gradient))
    }
}
