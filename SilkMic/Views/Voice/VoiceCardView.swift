// SilkMic/Views/Voice/VoiceCardView.swift
import SwiftUI

/// Clean Mic controls as Control Center–style Liquid Glass modules: separate glass tiles grouped
/// in one container, colour only on what is active. Used in the menu-bar popup and the notch panel.
struct VoiceCardView: View {
    @Bindable var voice: VoiceController
    /// Notch layout: microphone and output pickers side by side, the Clean Mic switch inside the
    /// noise module. The menu-bar popup keeps its own output list, so it leaves this off.
    var showsOutput = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tileRadius: CGFloat = 22
    private let spacing: CGFloat = 8

    var body: some View {
        glassGroup {
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    if showsOutput {
                        micTile
                        outputTile
                    } else {
                        cleanTile
                        micTile
                    }
                }
                strengthModule
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.72), value: voice.cleanEnabled)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.68), value: voice.strength)
    }

    // MARK: - Tiles

    /// Like Control Center's Wi-Fi tile: round icon (coloured when on), title, state.
    private var cleanTile: some View {
        Button {
            voice.cleanEnabled.toggle()
        } label: {
            HStack(spacing: 10) {
                iconCircle(systemName: voice.cleanEnabled ? "waveform" : "waveform.slash", active: voice.cleanEnabled)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: voice.cleanEnabled && !reduceMotion)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Clean Mic")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(voice.cleanEnabled ? "On" : "Off")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .silkGlassCard(cornerRadius: tileRadius, interactive: true)
        .accessibilityLabel("Clean Mic")
        .accessibilityValue(voice.cleanEnabled ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    /// Mic tile: which physical mic is being cleaned; click to choose another.
    private var micTile: some View {
        deviceTile(title: "Microphone", icon: "mic.fill", current: currentMicName,
                   items: voice.sourceMics.map { ($0.id, $0.name) },
                   selectedID: voice.selectedSourceMicID) { voice.selectSourceMic(uid: $0) }
    }

    /// Output tile: the system speaker or headphones; click to switch.
    private var outputTile: some View {
        let devices = voice.outputDevices
        let current = devices.first { $0.uid == voice.defaultOutputUID }?.name ?? "None"
        return deviceTile(title: "Output", icon: outputIcon(for: current), current: current,
                          items: devices.map { ($0.uid, $0.name) },
                          selectedID: voice.defaultOutputUID ?? "") { uid in
            if let device = devices.first(where: { $0.uid == uid }) { voice.selectOutput(device) }
        }
    }

    /// A Control Center–style tile that opens a device menu (current device ticked).
    private func deviceTile(title: String, icon: String, current: String,
                            items: [(id: String, name: String)], selectedID: String,
                            select: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(items, id: \.id) { item in
                Button {
                    select(item.id)
                } label: {
                    if item.id == selectedID {
                        Label(item.name, systemImage: "checkmark")
                    } else {
                        Text(item.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                iconCircle(systemName: icon, active: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(current)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .silkGlassCard(cornerRadius: tileRadius, interactive: true)
        .help(current)
        .accessibilityLabel("\(title): \(current)")
    }

    private func outputIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods") { return "airpods" }
        if ["buds", "headphone", "headset", "earphone", "qcy"].contains(where: lower.contains) { return "headphones" }
        if lower.contains("display") || lower.contains("tv") || lower.contains("hdmi") { return "tv" }
        return "speaker.wave.2.fill"
    }

    /// Like Control Center's Display/Sound sliders: one glass capsule, the chosen level is a
    /// bright pill that slides between positions.
    private var strengthModule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if showsOutput {
                    Image(systemName: voice.cleanEnabled ? "waveform" : "waveform.slash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(voice.cleanEnabled ? SilkPalette.violet : Color.primary.opacity(0.6))
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: voice.cleanEnabled && !reduceMotion)
                }
                Text(showsOutput ? "Clean Mic" : "Noise Removal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(showsOutput ? .primary : .secondary)
                Spacer(minLength: 0)
                if showsOutput {
                    Toggle("Clean Mic", isOn: $voice.cleanEnabled)
                        .toggleStyle(SilkSwitchStyle())
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 4)
            HStack(spacing: 2) {
                ForEach(NoiseStrength.allCases) { level in
                    strengthSegment(level)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            .disabled(!voice.cleanEnabled)
            .opacity(voice.cleanEnabled ? 1 : 0.45)
        }
        .padding(10)
        .silkGlassCard(cornerRadius: tileRadius)
    }

    @Namespace private var strengthNamespace

    private func strengthSegment(_ level: NoiseStrength) -> some View {
        let selected = voice.strength == level
        return Button {
            voice.strength = level
        } label: {
            Text(level.title)
                .font(.system(size: 12, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.primary.opacity(0.78))
                .frame(maxWidth: .infinity, minHeight: 26)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "strengthPill", in: strengthNamespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.title) noise removal")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Pieces

    /// Round icon like Control Center: tinted brand violet when active, neutral glass when not.
    private func iconCircle(systemName: String, active: Bool) -> some View {
        ZStack {
            Circle()
                .fill(active ? AnyShapeStyle(SilkPalette.violet) : AnyShapeStyle(Color.primary.opacity(0.12)))
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.primary.opacity(0.85))
        }
        .frame(width: 32, height: 32)
    }

    private var currentMicName: String {
        voice.sourceMics.first(where: { $0.id == voice.selectedSourceMicID })?.name ?? "None"
    }

    @ViewBuilder
    private func glassGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

/// A switch that keeps its colour when the window is not focused. The system switch turns grey in
/// inactive windows, and the notch panel never takes focus from the app you are typing in.
struct SilkSwitchStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(configuration.isOn ? AnyShapeStyle(SilkPalette.violet) : AnyShapeStyle(Color.white.opacity(0.18)))
                .frame(width: 34, height: 20)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                        .padding(2)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
