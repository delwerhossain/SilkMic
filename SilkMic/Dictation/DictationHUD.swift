// SilkMic/Dictation/DictationHUD.swift
import AppKit
import SwiftUI

/// Wispr Flow–style pill at the bottom centre of the screen while dictating: a live waveform
/// while listening, animated dots while writing, a short message on errors. Never takes focus,
/// so the text lands in the app you are using.
@MainActor
final class DictationHUD {
    private weak var controller: DictationController?
    private var panel: NSPanel?
    private static let size = NSSize(width: 172, height: 40)

    init(controller: DictationController) {
        self.controller = controller
    }

    func show() {
        guard let controller else { return }
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .statusBar
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: DictationHUDView(controller: controller))
            self.panel = panel
        }
        position()
        guard let panel, !panel.isVisible || panel.alphaValue < 1 else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            Task { @MainActor in panel?.orderOut(nil) }
        })
    }

    /// Bottom centre of the screen with the mouse, just above the Dock.
    private func position() {
        guard let panel else { return }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: visible.midX - Self.size.width / 2, y: visible.minY + 18))
    }
}

struct DictationHUDView: View {
    let controller: DictationController

    var body: some View {
        HStack(spacing: 8) {
            badge
            Group {
                switch controller.phase {
                case .listening:
                    Waveform(level: controller.level)
                case .preparing, .transcribing:
                    WritingDots()
                case .failed(let message):
                    Text(message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                case .idle:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .frame(width: 172, height: 40)
        .background(Capsule().fill(Color.black.opacity(0.88)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
    }

    /// Language tag (EN / বাং) in a violet dot; orange on errors.
    @ViewBuilder
    private var badge: some View {
        let failed: Bool = { if case .failed = controller.phase { return true }; return false }()
        let language: DictationLanguage? = {
            switch controller.phase {
            case .preparing(let l), .listening(let l): return l
            default: return nil
            }
        }()
        ZStack {
            Circle().fill(failed ? Color(nsColor: .systemOrange) : SilkPalette.violet)
            if failed {
                Image(systemName: "exclamationmark").font(.system(size: 11, weight: .bold))
            } else if let language {
                Text(language == .english ? "EN" : "বাং").font(.system(size: 9, weight: .bold, design: .rounded))
            } else {
                Image(systemName: "mic.fill").font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
    }
}

/// Bars that follow the input level, with a gentle idle motion so the pill feels alive.
private struct Waveform: View {
    let level: Float
    private let shape: [Float] = [0.35, 0.6, 0.85, 1, 0.85, 0.6, 0.35, 0.55, 0.8, 0.55]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(shape.indices, id: \.self) { i in
                    let wobble = Float(0.5 + 0.5 * sin(t * 9 + Double(i) * 0.8))
                    let height = 3 + 20 * CGFloat(min(1, max(0.08, level * shape[i] * (0.65 + 0.35 * wobble))))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: height)
                }
            }
            .frame(height: 24)
        }
    }
}

/// Three dots pulsing while the transcript is written.
private struct WritingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * (0.5 + 0.5 * sin(t * 6 - Double(i) * 0.9)))
                }
            }
        }
    }
}
