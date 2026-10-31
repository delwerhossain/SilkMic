// SilkMic/Views/DesignSystem/SilkGlass.swift
import AppKit
import SwiftUI

// SilkMic look: Liquid Glass surfaces (macOS 26+) over a soft "silk aurora" glow.
// Older macOS gets system materials; Reduce Transparency gets solid surfaces.

enum SilkPalette {
    /// Vivid violet → fuchsia → sky: the SilkMic aurora.
    static let violet = Color(red: 123 / 255, green: 97 / 255, blue: 255 / 255)    // #7B61FF
    static let fuchsia = Color(red: 225 / 255, green: 92 / 255, blue: 255 / 255)   // #E15CFF
    static let sky = Color(red: 76 / 255, green: 201 / 255, blue: 240 / 255)       // #4CC9F0
    static let rose = Color(red: 255 / 255, green: 95 / 255, blue: 162 / 255)      // #FF5FA2

    static let aurora = LinearGradient(colors: [violet, fuchsia, sky], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let auroraHorizontal = LinearGradient(colors: [violet, fuchsia], startPoint: .leading, endPoint: .trailing)
    static let mutedGradient = LinearGradient(colors: [Color(nsColor: .systemRed), rose], startPoint: .leading, endPoint: .trailing)
}

/// Soft coloured light behind glass so the translucency picks up the brand colours.
struct AuroraGlow: View {
    var intensity: Double = 1
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if reduceTransparency {
            Color.clear
        } else {
            let strength = (colorScheme == .dark ? 0.32 : 0.22) * intensity
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Circle().fill(SilkPalette.violet.opacity(strength))
                        .frame(width: size.width * 0.9).blur(radius: 60)
                        .offset(x: -size.width * 0.35, y: -size.height * 0.35)
                    Circle().fill(SilkPalette.fuchsia.opacity(strength * 0.8))
                        .frame(width: size.width * 0.7).blur(radius: 70)
                        .offset(x: size.width * 0.4, y: -size.height * 0.15)
                    Circle().fill(SilkPalette.sky.opacity(strength * 0.6))
                        .frame(width: size.width * 0.8).blur(radius: 80)
                        .offset(x: size.width * 0.1, y: size.height * 0.45)
                }
                .frame(width: size.width, height: size.height)
            }
            .allowsHitTesting(false)
        }
    }
}

/// Real Liquid Glass for a whole window or panel background (AppKit `NSGlassEffectView`).
@available(macOS 26.0, *)
struct GlassEffectBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 16
    var tint: NSColor? = nil

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        view.tintColor = tint
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.cornerRadius = cornerRadius
        view.tintColor = tint
    }
}

extension View {
    /// A Liquid Glass card (macOS 26+), material card before that, solid with Reduce Transparency.
    @ViewBuilder
    func silkGlassCard(cornerRadius: CGFloat = 14, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(SilkGlassCardModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    /// Popup / panel background: aurora glow under Liquid Glass (or the popover material before 26).
    func silkPanelBackground(cornerRadius: CGFloat = 24) -> some View {
        modifier(SilkPanelBackgroundModifier(cornerRadius: cornerRadius))
    }
}

private struct SilkGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content.background(shape.fill(Color(nsColor: .controlBackgroundColor)))
        } else if #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}

private struct SilkPanelBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor))
        } else if #available(macOS 26.0, *) {
            // Native macOS panel material (like Control Center and System Settings) for solid
            // contrast; the Liquid Glass lives on the tiles inside, not on the whole panel.
            content
                .background(Color.popupBackgroundOverlay)
                .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
        } else {
            content
                .background(Color.popupBackgroundOverlay)
                .background(AuroraGlow(intensity: 0.7))
                .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
        }
    }
}
