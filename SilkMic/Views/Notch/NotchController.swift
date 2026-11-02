// SilkMic/Views/Notch/NotchController.swift
import AppKit
import DynamicNotchKit
import SwiftUI
import os

/// Opens the Clean Mic panel from the MacBook notch: hover (or click) the notch and the panel
/// drops down with a springy animation; it closes when the pointer leaves it.
///
/// Only active on a built-in screen with a hardware notch (top safe-area inset plus both auxiliary
/// areas). Macs without a notch and external displays keep using the menu-bar icon.
@MainActor
final class NotchController {
    static let enabledKey = "silkmic.notchPanel"

    private let logger = Logger(subsystem: "app.silkmic.SilkMic", category: "Notch")
    private let voice: VoiceController
    private var triggerPanel: NSPanel?
    private var notch: DynamicNotch<NotchVoiceView, EmptyView, EmptyView>?
    private var isOpen = false
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            rebuild()
        }
    }

    init(voice: VoiceController) {
        self.voice = voice
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
        // The Settings toggle writes the same UserDefaults key.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isEnabled != (self.triggerPanel != nil || Self.notchScreen() == nil) else { return }
                self.rebuild()
            }
        }
        rebuild()
        // silkmic://open-notch (used by scripts/screenshots.sh): show the panel for a few seconds.
        showObserver = NotificationCenter.default.addObserver(forName: .silkMicOpenNotch, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.showBriefly() }
        }
    }

    private var showObserver: NSObjectProtocol?

    private func showBriefly() async {
        guard isEnabled, !isOpen else { return }
        await open()
        closeTask?.cancel()
        closeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            await self?.close()
        }
    }

    // MARK: - Geometry

    /// The built-in screen that has a hardware notch, if any.
    static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.safeAreaInsets.top > 0
                && screen.auxiliaryTopLeftArea != nil
                && screen.auxiliaryTopRightArea != nil
        }
    }

    /// The notch cut-out in screen coordinates, measured (never hard-coded).
    static func notchRect(on screen: NSScreen) -> NSRect? {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let height = screen.safeAreaInsets.top
        let x = screen.frame.minX + left.width
        let width = screen.frame.width - left.width - right.width
        guard width > 0, height > 0 else { return nil }
        return NSRect(x: x, y: screen.frame.maxY - height, width: width, height: height)
    }

    // MARK: - Trigger window over the notch

    private func rebuild() {
        triggerPanel?.orderOut(nil)
        triggerPanel = nil
        guard isEnabled, let screen = Self.notchScreen(), let rect = Self.notchRect(on: screen) else { return }

        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        let view = NotchTriggerView(frame: NSRect(origin: .zero, size: rect.size))
        view.onHover = { [weak self] hovering in self?.triggerHover(hovering) }
        view.onClick = { [weak self] in self?.toggle() }
        panel.contentView = view
        panel.orderFrontRegardless()
        triggerPanel = panel
        logger.info("Notch panel trigger ready (\(Int(rect.width))x\(Int(rect.height)))")
    }

    private func triggerHover(_ hovering: Bool) {
        if hovering {
            closeTask?.cancel()
            // A short delay so a pointer passing over the menu bar does not pop the panel.
            openTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                await self?.open()
            }
        } else {
            openTask?.cancel()
            scheduleCloseIfAway()
        }
    }

    private func toggle() {
        Task { @MainActor in isOpen ? await close() : await open() }
    }

    // MARK: - Panel

    private func open() async {
        guard !isOpen, let screen = Self.notchScreen() else { return }
        isOpen = true
        let notch = DynamicNotch(hoverBehavior: [.keepVisible, .hapticFeedback]) { [voice] in
            NotchVoiceView(voice: voice)
        }
        // Springy drop-down with a little bounce; Reduce Motion falls back to a plain ease.
        notch.transitionConfiguration.openingAnimation = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.42, dampingFraction: 0.62)
        self.notch = notch
        await notch.expand(on: screen)
        scheduleCloseIfAway()
    }

    private func close() async {
        guard isOpen else { return }
        isOpen = false
        await notch?.hide()
        notch = nil
    }

    /// Closes once the pointer is neither on the notch nor on the open panel.
    private func scheduleCloseIfAway() {
        closeTask?.cancel()
        closeTask = Task { @MainActor [weak self] in
            while let self, self.isOpen, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                let overTrigger = self.triggerPanel.map { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? false
                if !(self.notch?.isHovering ?? false) && !overTrigger {
                    await self.close()
                    return
                }
            }
        }
    }
}

/// Invisible view over the notch that reports hover and clicks.
final class NotchTriggerView: NSView {
    var onHover: ((Bool) -> Void)?
    var onClick: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Content of the notch panel: microphone, output and Clean Mic on clear, water-like glass over
/// the black notch background, sized for the notch.
struct NotchVoiceView: View {
    let voice: VoiceController

    var body: some View {
        VoiceCardView(voice: voice, showsOutput: true)
            .frame(width: 340)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .background(NotchGlassLight())
            .environment(\.silkGlassStyle, .clear)
            .environment(\.colorScheme, .dark)
    }
}

/// Faint light under the tiles so the clear glass has something to bend; the panel stays black.
private struct NotchGlassLight: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if !reduceTransparency {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Ellipse().fill(Color.white.opacity(0.07))
                        .frame(width: size.width * 0.7, height: size.height * 0.6).blur(radius: 30)
                        .offset(x: -size.width * 0.18, y: -size.height * 0.12)
                    Ellipse().fill(SilkPalette.violet.opacity(0.10))
                        .frame(width: size.width * 0.6, height: size.height * 0.5).blur(radius: 36)
                        .offset(x: size.width * 0.22, y: size.height * 0.2)
                }
                .frame(width: size.width, height: size.height)
            }
            .allowsHitTesting(false)
        }
    }
}
