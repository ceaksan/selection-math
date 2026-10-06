# ADR-002: Explicit shortcut transfer

Status: Accepted

## Context

The user reported that Streamlit cell selections were not added, identified clipping in the automatic-collection button, and asked to send selections with a shortcut instead of automatic mouse tracking. A separate screenshot showed `5.60` being added as `5 + 60`; the parser reproduces this when Turkish formatting is selected.

Streamlit documents its canvas-based Glide Data Grid. The application's existing reader only requested `AXSelectedText`, which is insufficient for a grid cell selection. A shortcut alone does not change that API limitation.

## Decision

Remove automatic mouse monitoring and register explicit system hotkeys through Carbon. Control + Option + A transfers the current selection. First use exposed Accessibility text; when absent, send a Copy command to the original application and read its new clipboard value. Snapshot all clipboard item types before copying and restore only if the clipboard revision still matches the captured revision. Never clear the clipboard merely to detect a copy. Timeout instead of using stale clipboard text.

The same `SelectionTransfer.capture` entry point is used by the registered shortcut and the panel button. It owns the capture generation, serializes captures, checks application focus, and calls the existing calculator session. Tests replace only the OS I/O boundary, not the transfer implementation. Reset invalidates pending results without canceling clipboard cleanup.

Preserve unambiguously dotted decimals such as `5.60` in Turkish mode while retaining valid grouping such as `5.600`. Require an editable preview before accepting OCR output because recognition can omit punctuation. The shortcut route does not require OCR or Screen Recording permission.

## Consequences

### Positive

Each press explicitly adds one selection. Cell content can be transferred using the source app's Copy support. No clipboard history, polling daemon, browser extension, or backend is added. A standard full-width button replaces the clipped custom capsule.

### Negative

Accessibility permission and a functioning Copy action are required. Some applications may reject synthetic keyboard events. Clipboard restoration is best effort: macOS provides no atomic compare-and-swap API, so the revision check cannot eliminate every possible cross-process race. An observed newer clipboard change is never overwritten. If the source loses focus before the new clipboard value is read, the transfer is aborted and no guessed restore is performed. OCR requires review and remains subject to recognition errors.

### Alternatives Considered

Continue automatic mouse capture: rejected by the user's explicit workflow change.

Rely only on Accessibility grid nodes: browser-specific exposure remains variable, while the app's Copy action supplies the actual selected cell data.

OCR as the default: unnecessary recognition errors and screen permission for copyable cell values.

## Files Changed

| Path | Purpose |
| --- | --- |
| `Sources/MathCore/SelectionTransfer.swift` | Explicit transfer entry point and OS I/O boundary |
| `Sources/MathCore/Calculator.swift` | Preserve dotted decimals in Turkish mode |
| `Sources/SelectionMath/SelectionCapture.swift` | Wire explicit transfer and OCR review |
| `Sources/SelectionMath/MacSelectionIO.swift` | Native clipboard and keyboard bridge |
| `Sources/SelectionMath/GlobalHotkeys.swift` | System shortcut registration |
| `Sources/SelectionMath/PanelView.swift` | Shortcut-first controls and OCR preview |
| `Sources/SelectionMath/App.swift` | Remove automatic collection lifecycle |
| `Sources/SelectionMath/Resources/tr.lproj/Localizable.strings` | Updated workflow text |
| `Tests/MathCoreTests/SelectionTransferTests.swift` | Capture-boundary regression tests |
| `Tests/MathCoreTests/CalculatorTests.swift` | Decimal regression |
| `README.md` | Revised workflow and verification limits |

## Sources

- https://docs.streamlit.io/develop/concepts/design/dataframes
- https://github.com/glideapps/glide-data-grid/blob/main/packages/core/src/internal/data-grid/data-grid.tsx

This supersedes the automatic mouse-collection portion of ADR-001. All other architecture remains unchanged.
