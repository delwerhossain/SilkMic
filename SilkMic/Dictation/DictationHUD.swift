// SilkMic/Dictation/DictationHUD.swift
import AppKit
import SwiftUI

/// Small Liquid Glass pill under the notch (top centre) while dictating: language, live level,
/// "Transcribing…", or an error. Never takes focus, so the text lands in the app you are using.
@MainActor
final class DictationHUD {
    private weak var controller: DictationController?
    private var panel: NSPanel?

    init(controller: DictationController) {
        self.controller = controller
    }

    func show() {
        guard let controller else { return }
        if panel == nil {
            let size = NSSize(width: 230, height: 46)
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: DictationHUDView(controller: controller))
            self.panel = panel
        }
        position()
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            Task { @MainActor in panel?.orderOut(nil) }
        })
    }

    /// Just below the menu bar / notch of the screen with the mouse.
    private func position() {
        guard let panel else { return }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.frame, let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: visible.maxY - size.height - 8))
    }
}

struct DictationHUDView: View {
    let controller: DictationController

    var body: some View {
        HStack(spacing: 10) {
            icon
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if case .listening = controller.phase {
                LevelBars(level: controller.level)
            } else if controller.phase == .transcribing || isPreparing {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 230, height: 46)
        .silkGlassCard(cornerRadius: 23)
        .environment(\.colorScheme, .dark)
    }

    private var isPreparing: Bool {
        if case .preparing = controller.phase { return true }
        return false
    }

    private var label: String {
        switch controller.phase {
        case .idle: return ""
        case .preparing(let lang): return "Starting \(lang.title)…"
        case .listening(let lang): return "Listening · \(lang.title)"
        case .transcribing: return "Writing…"
        case .failed(let message): return message
        }
    }

    @ViewBuilder
    private var icon: some View {
        let failed: Bool = { if case .failed = controller.phase { return true }; return false }()
        Image(systemName: failed ? "exclamationmark.triangle.fill" : "mic.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(failed ? Color(nsColor: .systemOrange) : SilkPalette.violet))
    }
}

/// Five bars that follow the input level.
private struct LevelBars: View {
    let level: Float
    private let weights: [Float] = [0.5, 0.8, 1, 0.8, 0.5]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { i in
                Capsule()
                    .fill(SilkPalette.auroraHorizontal)
                    .frame(width: 3, height: CGFloat(4 + 16 * min(1, level * weights[i])))
            }
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
