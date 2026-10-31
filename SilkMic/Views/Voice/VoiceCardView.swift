// SilkMic/Views/Voice/VoiceCardView.swift
import SwiftUI

/// Top card of the menu-bar popup and the notch panel: Clean Mic on/off, noise strength and
/// the source mic, on a Liquid Glass card with the silk aurora.
struct VoiceCardView: View {
    @Bindable var voice: VoiceController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            strengthChips
            sourceMicRow
        }
        .padding(12)
        .silkGlassCard(cornerRadius: 16, tint: SilkPalette.violet.opacity(voice.cleanEnabled ? 0.16 : 0.04), interactive: true)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: voice.cleanEnabled)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: voice.strength)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(voice.cleanEnabled ? AnyShapeStyle(SilkPalette.aurora) : AnyShapeStyle(Color.primary.opacity(0.1)))
                    .frame(width: 32, height: 32)
                    .shadow(color: voice.cleanEnabled ? SilkPalette.fuchsia.opacity(0.45) : .clear, radius: 8)
                Image(systemName: voice.cleanEnabled ? "waveform" : "waveform.slash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(voice.cleanEnabled ? Color.white : DesignTokens.Colors.textSecondary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: voice.cleanEnabled && !reduceMotion)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(voice.cleanEnabled ? "Clean Mic" : "Clean Mic off")
                    .font(DesignTokens.Typography.voiceState)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(voice.cleanEnabled ? "Noise removed in every app" : "Your voice passes through unchanged")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Spacer()
            Toggle("Clean Mic", isOn: $voice.cleanEnabled)
                .toggleStyle(.switch)
                .tint(SilkPalette.violet)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel("Clean Mic")
        }
    }

    private var strengthChips: some View {
        HStack(spacing: 6) {
            ForEach(NoiseStrength.allCases) { level in
                strengthChip(level)
            }
        }
        .disabled(!voice.cleanEnabled)
        .opacity(voice.cleanEnabled ? 1 : 0.45)
    }

    private func strengthChip(_ level: NoiseStrength) -> some View {
        let selected = voice.strength == level
        return Button {
            voice.strength = level
        } label: {
            Text(level.title)
                .font(DesignTokens.Typography.strengthChip)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? Color.white : DesignTokens.Colors.textSecondary)
                .background {
                    if selected {
                        Capsule().fill(SilkPalette.auroraHorizontal)
                            .shadow(color: SilkPalette.violet.opacity(0.45), radius: 6, y: 2)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.07))
                    }
                }
                .scaleEffect(selected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.title) noise removal")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var sourceMicRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 11))
                .foregroundStyle(SilkPalette.aurora)
            Picker("Source mic", selection: $voice.selectedSourceMicID) {
                ForEach(voice.sourceMics, id: \.id) { mic in
                    Text(mic.name).tag(mic.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .accessibilityLabel("Source mic")
        }
    }
}
