# ADR-006: Shortcut registration test boundary

Status: Accepted

## Context

Updating one shortcut unregisters and registers all three actions. Checking only the changed action can silently disable a different action. Tests must enter through AppModel and exercise the real GlobalHotkeys registration and rollback logic without requiring an interactive desktop or claiming a real system shortcut.

## Decision

Inject only the Carbon handler and hotkey registration calls into GlobalHotkeys. Production uses the same Carbon APIs as before. Tests supply opaque fake handles and control operating system failures at that boundary. AppModel saves shortcut settings only when all registrations succeed, including resetting to defaults. A failure attempts to restore the previous set and is returned to Settings; rollback failure is also reported.

## Consequences

### Positive

- Tests cover the model, registration loop, cleanup, persistence, and rollback together.
- Failed updates cannot silently persist a partially registered set.

### Negative

- Carbon registration is not transactional. Another process can claim a combination while it is unregistered, including during rollback. The app reports this condition; it cannot guarantee reacquisition.
- Actual keyboard event delivery still requires interactive verification.

### Alternatives Considered

- Mocking GlobalHotkeys itself would bypass the registration loop and cleanup behavior being tested.
- Registering arbitrary real shortcuts in every test depends on desktop availability and other running applications.

## Files Changed

| Path | Purpose |
| --- | --- |
| `Sources/SelectionMath/GlobalHotkeys.swift` | Injectable Carbon calls with live defaults |
| `Sources/SelectionMath/SelectionCapture.swift` | All-action validation and rollback |
| `Sources/SelectionMath/SettingsView.swift` | Display default-reset failures |
| `Tests/SelectionMathTests/ShortcutTests.swift` | Tests through AppModel with only Carbon mocked |
| `README.md` | Registration limits and verification coverage |
