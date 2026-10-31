// SilkMic/Views/Settings/Tabs/AboutTab.swift
// Modified by Delwer Hossain, 2026: SilkMic branding, upstream credits, GPL notices, Acknowledgements.
import AppKit
import SwiftUI

@MainActor
struct AboutTab: View {
    @State private var showAcknowledgements = false

    private var versionShort: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    private var yearText: String {
        let startYear = 2026
        let currentYear = Calendar.current.component(.year, from: .now)
        return startYear == currentYear ? "\(startYear)" : "\(startYear)-\(currentYear)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)

                Text("SilkMic")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Version \(versionShort) (\(buildNumber))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("Clean voice, smart audio for Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                AboutLinkChip(
                    label: "Star on GitHub",
                    icon: "star",
                    hoverIcon: "star.fill",
                    hoverColor: .yellow,
                    url: DesignTokens.Links.repository,
                    isPrimary: true
                )
                Button {
                    showAcknowledgements = true
                } label: {
                    Label("Acknowledgements", systemImage: "doc.text")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            footer
                .padding(.top, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showAcknowledgements) {
            AcknowledgementsView()
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("© \(yearText) Delwer Hossain")
                Text("·")
                Button {
                    NSWorkspace.shared.open(DesignTokens.Links.license)
                } label: {
                    Text("GPL-3.0, no warranty")
                }
                .buttonStyle(.plain)
                Text("·")
                Button {
                    NSWorkspace.shared.open(DesignTokens.Links.repository)
                } label: {
                    Text("Source code")
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 4) {
                Text("Built on")
                Button("FineTune") { NSWorkspace.shared.open(DesignTokens.Links.fineTune) }
                    .buttonStyle(.plain)
                Text("by Ronit Singh and")
                Button("NoNoise Mac") { NSWorkspace.shared.open(DesignTokens.Links.noNoise) }
                    .buttonStyle(.plain)
                Text("by ivalsaraj")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }
}

/// Full third-party notices and licence texts shipped inside the app bundle.
@MainActor
struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    private static func load(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "\(name).txt is missing from the app bundle."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Acknowledgements")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Self.load("Acknowledgements"))
                    Text(Self.load("LICENSE-GPL-3.0"))
                }
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 560, height: 520)
    }
}
