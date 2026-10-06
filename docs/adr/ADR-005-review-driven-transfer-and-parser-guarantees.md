# ADR-005: Review-driven transfer and parser guarantees

Status: Accepted. Supersedes the "skip unreadable pasteboard types" decision in [ADR-004](ADR-004-hardening-compact-mode-and-shortcuts.md).

## Context

An external review of version 0.4.0 found seven issues. Each one was reproduced by a test before it was fixed:

1. **Lost signs and missing values.** Currency-signed values such as `-$1,234.56` lost their sign. Exponent notation such as `1e3` was dropped without notice.
2. **Format change during editing.** An operand being edited was parsed with the format active when the user saved, not the format the draft was written in.
3. **Wrong clipboard write accepted.** After the source application's copy changed the clipboard, a second, unrelated clipboard write could be accepted as the selection. The old clipboard was then written over it.
4. **Incomplete clipboard backup.** The snapshot skipped pasteboard types it could not read, and a failed restore was not reported.
5. **Crash from corrupt shortcut settings.** A stored shortcut with an out-of-range key code passed validation and crashed label rendering.
6. **Undo reset disappeared too early.** The Undo button for Reset disappeared with the status message, although the cleared calculation was still restorable.
7. **Test gaps.** Screen capture and shortcut registration lacked tests beyond their error paths.

## Decision

- **Number parsing.**
  - Accept an optional currency symbol before the number, with the sign either before or after it: `-$5`, `$-5`, `($5)`. Accept exponent notation.
  - Report number-like fragments that do not parse (for example `Q3`, `1.2K`) as skipped. The operands that do parse are still added, and the user is told what was skipped. The user chose this over rejecting the whole selection.
- **Editing.** An edit is parsed with the number format that was active when editing began.
- **Copy fallback.**
  - Record the first clipboard revision observed after Copy. A different second revision aborts the transfer without restoring, because the newer write belongs to someone else.
  - A revision change between reading the text and restoring also aborts.
- **Clipboard backup and restore.**
  - Refuse the Copy fallback when any pasteboard type cannot be read. A partial backup cannot be restored faithfully, and the user chose data protection over availability.
  - A capture reports whether the clipboard was restored, and the interface warns when it was not.
- **Shortcut settings.** Stored and recorded shortcuts must use a key code below 128 and only the supported modifiers. Invalid stored values fall back to the defaults.
- **Undo reset.** Reset turns into Undo reset while the list is empty and the cleared calculation can be restored, independent of status messages.
- **Tests.** Add tests for crop geometry, text recognition on a rendered image, and shortcut changes entering through `AppModel`. A successful ScreenCaptureKit capture still needs interactive verification, because `SCShareableContent` cannot be constructed in tests.

## Consequences

### Positive

- No value changes sign, and no number-like fragment disappears without notice.
- A clipboard write by another process is no longer added, and it is never overwritten.
- A clipboard that cannot be fully saved is left untouched.
- Corrupt shortcut settings cannot crash the app.

### Negative

- A source application whose single copy changes the clipboard twice now fails the Copy fallback.
- Clipboards holding promised or unreadable data, such as some file copies, disable the Copy fallback until the clipboard changes. Accessibility text and Capture area still work.
- Labels such as `Q3` produce a skipped notice.
- A parenthesized year still becomes negative, as decided in ADR-004.

### Alternatives Considered

- **Reject a selection that contains unparsed number-like fragments.** Rejected by the user, because it blocks common selections such as table rows with labels.
- **Keep skipping unreadable types and warn after the fact.** Rejected because the clipboard data would already be lost.

## Files Changed

| Path | Purpose |
| --- | --- |
| `Sources/MathCore/Calculator.swift` | Currency, exponent, skipped fragments, `Acceptance`, edit format |
| `Sources/MathCore/SelectionTransfer.swift` | Single-revision rule, read race abort, `CaptureOutcome` |
| `Sources/SelectionMath/MacSelectionIO.swift` | Refuse incomplete snapshots |
| `Sources/SelectionMath/Shortcuts.swift` | Key code and modifier validation |
| `Sources/SelectionMath/SelectionCapture.swift` | Outcome messages |
| `Sources/SelectionMath/PanelView.swift` | Persistent Undo reset, edit format |
| `Sources/SelectionMath/ScreenCapture.swift` | Testable crop geometry |
| `Tests/**` | Regression tests for each item |
| `README.md`, `docs/design-guide.md` | Updated rules and limits |
