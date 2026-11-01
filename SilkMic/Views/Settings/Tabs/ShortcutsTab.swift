// SilkMic/Views/Settings/Tabs/ShortcutsTab.swift
import SwiftUI
import KeyboardShortcuts

@MainActor
struct ShortcutsTab: View {
    @Bindable var settings: SettingsManager
    @Bindable var accessibility: AccessibilityPermissionService
    @Bindable var mediaKeyStatus: MediaKeyStatus
    let mediaKeyMonitor: MediaKeyMonitor
    let shortcutsRegistry: ShortcutsRegistry

    @State private var banglaModel = BanglaModelManager.shared
    @AppStorage(DictationController.fnEnabledKey) private var fnEnabled = true
    @AppStorage(DictationHUD.showPillKey) private var showPill = true
    @AppStorage(DictationController.fnLanguageKey) private var fnLanguage = DictationLanguage.english.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dictationSection
                volumeSection
                mediaKeysSection
                hotkeysSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .onChange(of: settings.appSettings.mediaKeyControlEnabled) { _, _ in
            mediaKeyMonitor.reconcile()
        }
    }

    // MARK: - Dictation

    private var dictationSection: some View {
        SettingsSection("Dictation") {
            SettingsRow(
                "Hold Fn (🌐) to Dictate",
                description: "Hold Fn, talk, release to type. Tap Fn once for hands-free, tap again to stop. Tip: set Keyboard → \"Press 🌐 key to\" → Do Nothing."
            ) {
                Toggle("", isOn: $fnEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            SettingsRowDivider()
            SettingsRow(
                "Show Dictation Pill",
                description: "Small pill at the bottom of the screen while dictating. Hover it for ✕, or press Esc, to cancel."
            ) {
                Toggle("", isOn: $showPill)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            SettingsRowDivider()
            SettingsRow(
                "Fn Dictation Language",
                description: "Language used when you hold Fn."
            ) {
                Picker("", selection: $fnLanguage) {
                    ForEach(DictationLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            SettingsRowDivider()
            SettingsRow(
                "Extra Shortcut: English",
                description: "Optional key combo for English dictation (hold to talk)."
            ) {
                KeyboardShortcuts.Recorder(for: .dictateEnglish)
            }
            SettingsRowDivider()
            SettingsRow(
                "Extra Shortcut: Bangla",
                description: banglaModel.isInstalled
                    ? "Same as English, written in Bangla letters (Bangla model installed)."
                    : "Same as English. Without the Bangla model it is written in English letters."
            ) {
                KeyboardShortcuts.Recorder(for: .dictateBangla)
            }
            SettingsRowDivider()
            SettingsRow(
                "Bangla Letters Model",
                description: "Optional, \(BanglaModelManager.sizeLabel). Writes Bangla in Bangla script, on this Mac. BengaliAI Whisper medium (Apache-2.0)."
            ) {
                banglaModelControl
            }
        }
    }

    @ViewBuilder
    private var banglaModelControl: some View {
        switch banglaModel.state {
        case .installed:
            HStack(spacing: 8) {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 12))
                Button("Remove") { banglaModel.remove() }
                    .controlSize(.small)
            }
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress).frame(width: 110)
                Text("\(Int(progress * 100))%").font(.system(size: 11).monospacedDigit())
                Button("Cancel") { banglaModel.cancelDownload() }.controlSize(.small)
            }
        case .notInstalled, .failed:
            VStack(alignment: .trailing, spacing: 2) {
                Button("Download \(BanglaModelManager.sizeLabel)") { banglaModel.download() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                if case .failed(let message) = banglaModel.state {
                    Text(message).font(.system(size: 10)).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Volume

    private var volumeSection: some View {
        SettingsSection("Volume") {
            SettingsRow(
                "Volume Step",
                description: "How much each keypress changes the volume. Applies to media keys, configured hotkeys, and arrow-key nav in the popup."
            ) {
                Picker("", selection: $settings.appSettings.volumeHotkeyStep) {
                    ForEach(VolumeHotkeyStep.allCases) { step in
                        Text(step.description).tag(step)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    // MARK: - Media Keys

    private var mediaKeysSection: some View {
        SettingsSection("Media Keys") {
            SettingsRow(
                "Media Keys Control",
                description: "Use F11/F12 (or volume keys) to control SilkMic"
            ) {
                Toggle("", isOn: $settings.appSettings.mediaKeyControlEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            if !accessibility.isTrustedCached {
                SettingsRowDivider()
                AccessibilityPromptStrip(accessibility: accessibility)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            if mediaKeyStatus.isOffline {
                SettingsRowDivider()
                MediaKeyOfflineCard {
                    mediaKeyMonitor.reconcile()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if settings.appSettings.mediaKeyControlEnabled && accessibility.isTrustedCached {
                SettingsRowDivider()
                SettingsRow(
                    "HUD Style",
                    description: "How the volume indicator appears"
                ) {
                    HUDStyleSegmentedControl(selection: $settings.appSettings.hudStyle)
                }
            }
        }
    }

    // MARK: - Hotkeys

    private var hotkeysSection: some View {
        SettingsSection("Hotkeys") {
            ForEach(Array(ShortcutAction.allCases.enumerated()), id: \.element) { index, action in
                if index > 0 { SettingsRowDivider() }
                SettingsRow(
                    action.displayName,
                    description: description(for: action)
                ) {
                    KeyboardShortcuts.Recorder(
                        for: shortcutsRegistry.name(for: action),
                        onChange: shortcutsRegistry.recordCallback(for: action)
                    )
                }
            }
        }
    }

    private func description(for action: ShortcutAction) -> String {
        switch action {
        case .togglePopup: "Show or hide the menu bar popup"
        case .targetAppVolumeUp: "Raise volume for the app playing audio"
        case .targetAppVolumeDown: "Lower volume for the app playing audio"
        case .targetAppMuteToggle: "Mute or unmute the app playing audio"
        }
    }
}
