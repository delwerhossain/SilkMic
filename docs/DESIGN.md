# Design direction (draft)

Status: draft v1 · 2026-11-01. Logo and final colours follow once the name is chosen (`NAMING.md`). Goal: a look that feels new and clearly its own, not FineTune's or NoNoise's.

## Personality

Calm, quiet, confident. The app's job is to disappear; the UI should feel like a soft, silent space where your voice is clear.

## Visual identity

- **Motif:** a single clean voice wave passing through a soft "hush" shape (circle or rounded drop). Noise = scattered dots that fade away. Used in the logo, menu-bar icon states and the onboarding animation.
- **Colour:** one signature accent, not the system blue and not orange/red (FineTune and NoNoise territory). Candidates: aurora teal (#2ED3B7-ish) or calm violet (#7C6CF2-ish), on neutral graphite/frost glass. Red is reserved for "muted"; amber for "problem".
- **Type:** SF Pro (system) with SF Pro Rounded for big numbers and state labels; Bangla UI uses the system Bangla font.
- **Icons:** SF Symbols for controls; custom template icons only for the menu bar states.

## Menu-bar icon states (template images, 16–18 pt)

| State | Look |
|---|---|
| Clean on | wave inside the hush shape |
| Bypass (clean off) | wave only, thinner |
| Muted | wave with a slash, red tint when the panel is open |
| Problem (no mic / driver missing) | small amber dot |

## Main panel (popover / notch drop-down, ~360 pt wide)

1. **Voice card (hero):** big state ring with live input level; one large toggle "Clean"; strength chips (Light · Balanced · Strong · Max · Auto); current mic chip with a dropdown (priority list, Hi-Fi Saver badge when earbuds are protected); mute button.
2. **Alerts row (only when needed):** "Zoom uses the raw mic → Fix", "Lid closed — using USB mic", "Driver needs repair".
3. **Apps (collapsed by default):** per-app volume/output rows, rebuilt in the new style.
4. **Footer:** Mic Check, Settings, quit.

## Materials and motion

- macOS 26+: Liquid Glass on the panel (`GlassEffectContainer`, one glass layer, content not glass-on-glass). Below 26: `.ultraThinMaterial`. Reduce Transparency: solid surface.
- Motion: short (150–250 ms) spring for the drop-down and state changes; level meter at ≤ 15 Hz; all motion off with Reduce Motion; nothing animates while the panel is closed.

## Notch surface

Click the notch (hardware notch only) to drop the same panel from the notch; it grows out of the notch shape. Menu-bar icon always works; Dynamic Island Macs use the menu bar until tested.

## Accessibility

VoiceOver labels on every control; keyboard navigation through the panel; contrast ≥ 4.5:1 for text on glass (fallback to tinted surface if needed).

## Next steps

1. Name chosen → logo concepts (2–3) → pick one.
2. App icon (macOS 26 layered icon) + menu-bar template set.
3. Panel and onboarding mockups for approval before SwiftUI work.
