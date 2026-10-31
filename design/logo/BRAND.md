# SilkMic logo — usage guide

Chosen 2026-11-01: **Hush Capsule** — a mic capsule with one calm wave cut through it. Idea in one line: *your voice, with the noise taken out.*

## Files

| File | Use |
|---|---|
| `final/silkmic-symbol.svg` | Master symbol (black, two solid pieces, no strokes) |
| `final/silkmic-symbol-color.svg` | Symbol in Silk Violet |
| `final/silkmic-lockup-color.svg` | Symbol + wordmark on light backgrounds |
| `final/silkmic-lockup-dark.svg` | Symbol + wordmark on dark backgrounds |
| `final/silkmic-lockup-black.svg` | One-colour lockup |
| `export/` | Black, white, mono, square, app-icon SVGs; favicon set (`favicon.ico`, PNGs, webmanifest, `<head>` snippet) |
| `menubar/state-*.svg` | Draft menu-bar states: clean, bypass, muted, problem (wired in Phase 2) |
| `../../silkMicIcon.icon` | macOS app icon (Icon Composer; white glass capsule on violet) |

## Colour

| Name | HEX | RGB | Use |
|---|---|---|---|
| Silk Violet | `#6E56CF` | 110, 86, 207 | Brand colour, symbol, app icon, accents |
| Lavender | `#B9A9FF` | 185, 169, 255 | Symbol and accents on dark backgrounds |
| Deep Violet | `#3E2C8F` | 62, 44, 143 | Pressed states, gradient end |
| Graphite | `#17151F` | 23, 21, 31 | Wordmark on light, dark backgrounds |
| Mute Red | system red | – | Muted state only |
| Alert Amber | system orange | – | Problem state only |

## Wordmark

"SilkMic" set in **Manrope Bold** (SIL Open Font License), tracking −20 units, converted to outlines. Never retype it in another font.

## Rules

- **Clear space:** at least the capsule's width on every side.
- **Minimum size:** symbol 12 px tall (menu bar uses 18 pt); lockup 96 px wide.
- **Backgrounds:** violet symbol on white/light; lavender or white symbol on graphite/dark; white symbol on violet.
- **Don't:** rotate, stretch, outline, add shadows or gradients to the symbol (the app icon's glass is the only exception), change the wave, or place the violet symbol on busy photos.

## Tests run

Rendered at 256/64/32/16 px and in the menu bar size (18 px); audit score 98/100; one-colour, reversed and violet versions checked. Trademark clearance is **not** done (see `docs/NAMING.md`).
