// SilkMic/Views/Voice/VoiceCardView.swift
import SwiftUI

/// Clean Mic controls as Control Center–style Liquid Glass modules: separate glass tiles grouped
/// in one container, colour only on what is active. Used in the menu-bar popup and the notch panel.
struct VoiceCardView: View {
    @Bindable var voice: VoiceController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tileRadius: CGFloat = 22
    private let spacing: CGFloat = 8

    var body: some View {
        glassGroup {
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    cleanTile
                    micTile
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
        Menu {
            ForEach(voice.sourceMics, id: \.id) { mic in
                Button {
                    voice.selectSourceMic(uid: mic.id)
                } label: {
                    if mic.id == voice.selectedSourceMicID {
                        Label(mic.name, systemImage: "checkmark")
                    } else {
                        Text(mic.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                iconCircle(systemName: "mic.fill", active: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Microphone")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(currentMicName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .silkGlassCard(cornerRadius: tileRadius, interactive: true)
        .accessibilityLabel("Microphone: \(currentMicName)")
    }

    /// Like Control Center's Display/Sound sliders: one glass capsule, the chosen level is a
    /// bright pill that slides between positions.
    private var strengthModule: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Noise Removal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            HStack(spacing: 2) {
                ForEach(NoiseStrength.allCases) { level in
                    strengthSegment(level)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
        .padding(10)
        .silkGlassCard(cornerRadius: tileRadius)
        .disabled(!voice.cleanEnabled)
        .opacity(voice.cleanEnabled ? 1 : 0.5)
    }

    @Namespace private var strengthNamespace

    private func strengthSegment(_ level: NoiseStrength) -> some View {
        let selected = voice.strength == level
        return Button {
            voice.strength = level
        } label: {
            Text(level.title)
                .font(.system(size: 12, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.primary.opacity(0.7))
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
