# ADR-003: English interface and shared native styles

Status: Accepted

## Context

The user supplied three local visual references and requested a design guide, corresponding layout/button/color/onboarding changes, and an English application. Existing SwiftUI views use dispersed indigo styles and Turkish resources. The selection shortcut was confirmed working by the user.

## Decision

Keep native SwiftUI and AppKit. Introduce shared adaptive colors and button styles in DesignSystem.swift and apply them to the calculator, rows, OCR review, and onboarding. Follow the reference interpretation in [the design guide](../design-guide.md). Add three optional onboarding steps, with a UserDefaults completion flag and a replay control. Resolve app-owned strings from the English bundle independently of number formatting and OS locale.

No new runtime dependencies. No changes to the calculation or selection-transfer protocol. Include the already-tested screen permission fix in the next package; actual macOS permission recovery still needs desktop validation.

## Consequences

### Positive

One native visual vocabulary covers every application screen. English UI does not alter Turkish number parsing. Onboarding explains existing shortcuts and requests Accessibility only after an explicit action.

### Negative

The completion preference persists locally in UserDefaults. Both appearance variants and the first-run flow need interactive verification. Ad-hoc signing can still require permission renewal after an update.

### Alternatives Considered

A webview UI adds a second rendering stack with no benefit to the existing native capture workflow. A literal copy of the reference onboarding would advertise unsupported customizable shortcuts. Retaining Turkish as an OS-selected interface language conflicts with the user's English-only request.

## Decision gate

| Criterion | Assessment |
| --- | --- |
| Benefit | Consistent readable controls and explicit first-run guidance. |
| Necessity | Implements the requested references and English interface. |
| Burden | Small shared styles and onboarding view; existing calculation logic remains reusable. |
| Conflict | Replaces earlier indigo/Turkish presentation consistently. |
| Performance | Native shapes, SF Symbols, no bitmap assets or continuous animation. |
| Security | No additional data collection or automatic permission requests. |
| Bottleneck | No new service or background work. |
| Currency | Uses SwiftUI/AppKit APIs in the installed macOS SDK. |

## Files changed

| Path | Purpose |
| --- | --- |
| `docs/design-guide.md` | Reference mapping and component specifications |
| `Sources/SelectionMath/DesignSystem.swift` | Adaptive tokens, buttons and keycaps |
| `Sources/SelectionMath/OnboardingView.swift` | Optional three-step introduction |
| `Sources/SelectionMath/PanelView.swift` | Calculator and OCR presentation |
| `Sources/SelectionMath/App.swift` | English lookup and panel configuration |
| `Sources/SelectionMath/Resources/en.lproj/Localizable.strings` | English interface |
| `Package.swift` | English default localization |
| `Info.plist` | English development region and release version |
| `Tests/SelectionMathTests/InterfaceTests.swift` | Localization and onboarding validation |
