# ADR-001: Native selection calculator

Status: Accepted for the first local prototype

The automatic collection portion is superseded by [ADR-002](ADR-002-explicit-shortcut-transfer.md). Native architecture and calculation semantics remain accepted.

## Context

The user needs a standalone macOS application that collects non-adjacent numbers from different applications, displays operands and results during screen recordings, and supports reset, individual removal, and editing. Clipboard stacking failed because it hid the accumulated values and had no visible calculation controls. The user selected the standalone macOS scope over a browser extension or a feature embedded in one project.

This is a new directory without an existing ADR template or prior ADRs.

## Decision

Use Swift, AppKit NSPanel, and SwiftUI with no third-party dependencies. Read exposed selections through macOS Accessibility. Collection is opt-in; explicit capture remains available. Use ScreenCaptureKit and Vision for user-selected image regions where the source application does not expose selected text. All processing remains on-device and in memory.

Use Foundation Decimal for calculations and an explicit English/Turkish number-format setting. Keep operations and operands in one observable session shared by all input routes. Reset increments a generation token so in-flight captures cannot repopulate a reset session. The panel presents the operands in calculation order and allows editing, deletion, and reordering.

## Consequences

### Positive

Native window and Accessibility APIs fit the macOS-wide requirement. The visible panel makes the calculation reviewable. Region capture supports canvas-rendered tables without silently modifying the clipboard. No backend, package registry runtime, or external service is required.

### Negative

Accessibility and Screen Recording permissions require user interaction. Native selection support depends on the source application. OCR can misread numbers and must remain visible and editable. macOS-only code requires a Mac to build and test. A local ad-hoc build is not a notarized distributable release. Measured memory and CPU figures are not yet available.

### Alternatives Considered

Browser extension: narrower platform reach than the user's selected scope.

OpenClip extension: the verified clipboard stack does not provide the persistent, editable operand panel required here.

Webview desktop shell: adds a runtime/bridge while selection and capture still require native macOS APIs. No dependency-size comparison is claimed; this prototype uses Apple's SDK directly.

## Decision Gate

| Criterion | Assessment |
| --- | --- |
| Benefit | Visible operands and operations for non-adjacent selections during recording. |
| Necessity | Clipboard stacking did not satisfy the workflow. |
| Burden | One native app, a pure calculation module, and no external service. |
| Conflict | New standalone project; no existing application architecture is changed. |
| Performance | Event-driven selection reads; screenshot/OCR only on explicit request. Actual resource use remains unmeasured. |
| Security | Permission-gated local reads, no network, no persistent screenshots. |
| Bottleneck | One capture at a time and a bounded operand count. |
| Currency | APIs checked against the installed macOS SDK and Apple's documentation. npm trends and Bundlephobia are not applicable. |

## Files Changed

| Path | Purpose |
| --- | --- |
| `Package.swift` | Native app, calculation module, and tests |
| `Sources/MathCore/Calculator.swift` | Parser, operations, and editable session |
| `Sources/SelectionMath/App.swift` | App lifecycle and floating panel |
| `Sources/SelectionMath/PanelView.swift` | Visible operands and calculation controls |
| `Sources/SelectionMath/SelectionCapture.swift` | Permission-gated selection capture |
| `Sources/SelectionMath/ScreenCapture.swift` | Explicit region capture and local OCR |
| `Sources/SelectionMath/Resources/tr.lproj/Localizable.strings` | Turkish interface strings |
| `Tests/MathCoreTests/CalculatorTests.swift` | Behavioral verification |
| `scripts/package.sh` | Local app packaging and signing |
| `README.md` | Setup, semantics, and verification limitations |
