# ADR-004: Release hardening, compact mode, and customizable shortcuts

Status: Accepted

## Context

A review before the first public release found defects at the macOS integration boundary, each reproduced by a test before it was fixed:

- The Copy fallback posted virtual key code 8, the physical ANSI C position, with Command. On Turkish F that key produces V and on Dvorak J, so the app sent Paste or an unrelated command to the source application.
- Clipboard restoration ran only when the copied value was text. A non-text copy, or a copy that arrived after 600 ms, left the copied content on the clipboard.
- One unreadable pasteboard type made the snapshot fail, which disabled the Copy fallback for that clipboard.
- The snapshot and restore cycle also copied concealed password manager items and wrote them back with a new change count.
- Accounting negatives such as `(1,234)` were added as positive values.

Interface review found that the 400 by 680 pt minimum panel covers most of a laptop screen during recordings. Status messages never cleared. Reset could not be undone. The fixed Control + Option shortcuts collide with the VoiceOver modifier.

## Decision

- Resolve the Copy key code from the active keyboard layout with `UCKeyTranslate` under the Command modifier. Fall back to ANSI C only when no layout data is available. Keep keystroke delivery instead of pressing the menu item through Accessibility: the user verified keystroke delivery in canvas grids, and a menu press does not reach pages that listen for keydown.
- Wait up to 1.5 s for the copy.
- Restore the snapshot whenever the clipboard revision changed after Copy, including non-text results and timeouts.
- Mark restored items with `org.nspasteboard.TransientType` so clipboard managers do not record them twice.
- Refuse the Copy fallback when the clipboard holds `org.nspasteboard.ConcealedType`. Accessibility text selection continues to work.
- Skip pasteboard types that cannot be read instead of failing the whole snapshot.
- Treat a parenthesized number as negative, matching spreadsheet convention.
- Add a compact panel mode that shows the result, the latest operands, and capture actions. Persist the mode.
- Clear status messages automatically. Offer Undo after Reset until the next change.
- Store three shortcuts in UserDefaults with the existing defaults. Record them in a settings sheet. Require Command, Control, or Option. Reject duplicates. Revert when registration fails. Display shortcuts with the active keyboard layout's key labels.
- Allow one running instance. A second launch shows the existing panel through a distributed notification and exits.
- Log failures with `os.Logger`. Error identifiers are public. Captured numbers and text are never logged.
- Build arm64 and x86_64 and sign with the hardened runtime. Release distribution still requires a Developer ID certificate and notarization.

## Consequences

### Positive

- The Copy fallback is safe on non-QWERTY layouts.
- The previous clipboard returns in every path where this app caused the change and no newer change was observed.
- Password manager items are never rewritten.
- VoiceOver users and users of conflicting apps can move the shortcuts.
- The compact mode keeps recordings readable.

### Negative

- A copy that arrives after 1.5 s still replaces the clipboard without restoration.
- A clipboard write by another process within the copy window is indistinguishable from the source app's Copy, because macOS offers no atomic compare-and-swap.
- A parenthesized year in prose becomes negative. Undo and edit remain available.
- The universal build roughly doubles compile time and binary size.
- Shortcut text in the interface and README now depends on stored settings.

### Alternatives Considered

- **Press Edit > Copy through Accessibility.** Layout independent, but it bypasses keydown handlers in web grids, the verified primary use case.
- **Refuse the Copy fallback on non-QWERTY layouts.** Safe, but it removes the feature for those users.
- **Fixed alternative shortcuts.** Any fixed combination can still collide with another app.

## Files Changed

| Path | Purpose |
| --- | --- |
| `Sources/MathCore/SelectionTransfer.swift` | Restore policy, timeout, concealed refusal |
| `Sources/MathCore/Calculator.swift` | Parenthesized negatives, formatter cache, percentage point text, reset undo |
| `Sources/SelectionMath/KeyboardLayout.swift` | Layout-aware key translation |
| `Sources/SelectionMath/Shortcuts.swift` | Shortcut model, validation, persistence, display |
| `Sources/SelectionMath/GlobalHotkeys.swift` | Configurable registration |
| `Sources/SelectionMath/MacSelectionIO.swift` | Layout-aware Copy, tolerant snapshot, transient restore |
| `Sources/SelectionMath/SelectionCapture.swift` | Element timeout, logging, message lifecycle, shortcuts |
| `Sources/SelectionMath/ScreenCapture.swift` | Cancel region selection when the overlay loses key status |
| `Sources/SelectionMath/App.swift` | Single instance, compact sizing, Edit menu, cached resources |
| `Sources/SelectionMath/PanelView.swift` | Compact mode, message slot, reset undo, menu state |
| `Sources/SelectionMath/SettingsView.swift` | Shortcut recorder |
| `Sources/SelectionMath/OnboardingView.swift` | Keycaps from stored shortcuts |
| `Sources/SelectionMath/Resources/en.lproj/Localizable.strings` | New copy |
| `scripts/package.sh` | Clean bundle, universal binary, hardened runtime |
| `Tests/**` | Regression tests for each defect |
| `README.md`, `docs/design-guide.md` | Updated behavior and limits |
