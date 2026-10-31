// SilkMic/Views/Voice/VoiceCardView.swift
import SwiftUI

/// Top card of the menu-bar popup: Clean Mic on/off, noise strength and the source mic.
/// First version; the full redesign follows docs/DESIGN.md in Phase 3.
struct VoiceCardView: View {
    @Bindable var voice: VoiceController

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: voice.cleanEnabled ? "waveform.badge.checkmark" : "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(voice.cleanEnabled ? DesignTokens.VoiceState.clean : DesignTokens.VoiceState.bypass)
                    .frame(width: 22)
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
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityLabel("Clean Mic")
            }

            HStack(spacing: 6) {
                ForEach(NoiseStrength.allCases) { level in
                    strengthChip(level)
                }
            }
            .disabled(!voice.cleanEnabled)
            .opacity(voice.cleanEnabled ? 1 : 0.5)

            HStack(spacing: 6) {
                Image(systemName: "mic")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
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
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.Brand.mark.opacity(0.08))
        )
    }

    private func strengthChip(_ level: NoiseStrength) -> some View {
        let selected = voice.strength == level
        return Button {
            voice.strength = level
        } label: {
            Text(level.title)
                .font(DesignTokens.Typography.strengthChip)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.06))
                )
                .foregroundStyle(selected ? Color.white : DesignTokens.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.title) noise removal")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
