# Selection Math

A local macOS utility that collects numbers from separate selections into a floating calculator. Operands and results stay visible, which makes it suited to screen recordings.

Overview and screenshots: [lab.ceaksan.com/selection-math](https://lab.ceaksan.com/selection-math/)

## Requirements

macOS 14 or later. Building requires the Xcode command line tools with Swift 5.9 or later. There are no third-party dependencies, accounts, network services, or clipboard monitoring.

## Install

1. Download [`SelectionMath.zip`](https://github.com/ceaksan/selection-math/releases/latest/download/SelectionMath.zip) from the latest release, unzip it, and move Selection Math to Applications.
2. The app is not notarized. On first launch macOS blocks it; open System Settings > Privacy & Security and press Open Anyway.
3. Allow Accessibility when asked. Screen Recording is requested the first time you use Capture area.

Releases are signed ad hoc, so macOS can ask for permissions again after an update. If access appears enabled but the app does not see it, remove Selection Math from the Accessibility list and add it again, or run `tccutil reset Accessibility com.ceaksan.selectionmath` and grant it once more.

## Use

1. Open Selection Math. The movable panel stays above ordinary application windows.
2. Grant Accessibility access. Select a cell or text in another application, then press the Add selection shortcut. Repeat for separate selections; existing operands remain visible. Nothing is collected automatically.
3. If Accessibility does not expose the selected text, the app sends Copy to the source application, reads the new clipboard text, and restores the previous clipboard. See [Clipboard handling](#clipboard-handling). For screenshots or cells without Copy support, use Capture area and drag around the numbers. This route requires Screen Recording permission. Review and correct the recognized text before pressing Add numbers.
4. Choose addition, ordered subtraction, multiplication, ordered division, average, ratio, or percentage change.
5. Edit an operand in place, remove it, change its order, undo the last selection, or reset the calculation. With percentage change and exactly two numbers, the swap button next to the formula exchanges first and second. After a reset, the Reset button becomes Undo reset until the next change.

Use the compact view button in the header to shrink the panel to the result, the latest three numbers, and the capture actions. The full view button restores the complete panel.

### Shortcuts

| Action | Default |
| --- | --- |
| Add selection | Control + Option + A |
| Capture area | Control + Option + S |
| Show calculator | Control + Option + P |

Change shortcuts in Settings, from the gear button or the menu bar menu. Each shortcut needs Command, Control, or Option, and two actions cannot share one. Changes and resetting to defaults are saved only when all three shortcuts register successfully. On failure, the app keeps the previous settings and attempts to restore their registrations. If another app also prevents that restore, an error is shown; choose another combination or use the buttons. macOS reserves some combinations without reporting a conflict; those never reach the app. The defaults overlap with VoiceOver commands, so VoiceOver users should choose other combinations.

Closing the panel hides it. Quit from the menu bar menu. Opening the app a second time shows the existing panel.

## Number formats and calculation rules

The initial format matches English-formatted tables: `310,872` is 310872 and `3.71` is a decimal. Switch to the Turkish format for `310.872` and `3,71`. Unambiguously dotted decimals such as `5.60` remain a single decimal in either format; Turkish mode still treats `5.600` as 5600. The format is explicit because a string such as `1,234` is ambiguous. Switching formats affects future captures and editing, never the values already collected.

- Whitespace, line breaks, tabs, and vertical bars separate numbers. In English mode, a comma that does not form a valid thousands group is also a separator.
- Parenthesized numbers are negative, following spreadsheet convention: `(1,234)` is -1234.
- A currency symbol may precede the number, with the sign on either side: `-$1,234.56`, `$-5`, and `($7)` are negative. Exponent notation such as `1e3` is read as 1000.
- Spaces around a sign or inside parentheses preserve negativity: `-  5` is -5 and `( $1,234.56 )` is -1234.56. A tab always separates cells, so a `-` or `$ -` placeholder cell copied from a spreadsheet never negates the next cell. Grouped mantissas retain their format in exponent notation: Turkish `1.234.567e2` is 123456700.
- Number-like fragments that are not plain numbers, such as `Q3`, `1.2K`, or `$1,250K`, are skipped as a whole. The other numbers are added and the status message lists what was skipped.
- An edit is read with the number format that was active when editing began.
- Percentages keep their label and are stored as fractions. Addition, subtraction, and average of percentages display a percentage. A difference between percentages is shown in percentage points (`pp`), and Copy result copies the bare number.
- Mixed scalar and percentage arithmetic uses the numeric values, so `100 + 10%` is `100.1`.

Subtraction and division follow the visible order. Ratio is first / second. Percentage change is (second - first) / first × 100. Ratio and percentage change require exactly two operands. Division by zero and numeric overflow produce an error. Decimal arithmetic avoids binary floating-point artifacts; displayed results round to eight fractional digits.

## Privacy

- Numbers and captured images live in memory only. Screenshots are never saved.
- Logs, readable in Console under the subsystem `com.ceaksan.selectionmath`, contain error identifiers only, never captured text or numbers.
- The app makes no network connections.

### Clipboard handling

Copy result writes the clipboard on request. The Copy fallback uses it temporarily:

- The fallback snapshots every clipboard type, up to 20 MB. If any type cannot be read, the backup would be incomplete, so it copies nothing and suggests Capture area.
- It then sends Command + C using the key that produces C in the active keyboard layout.
- It waits up to 1.5 s for the source application to copy.
- It restores the snapshot whenever the clipboard changed, including non-text results and timeouts. Restored items carry `org.nspasteboard.TransientType`, so clipboard managers do not record them again.
- When the clipboard holds an item marked `org.nspasteboard.ConcealedType`, such as a password manager entry, the fallback stops without copying. Accessibility text selection still works.
- Only the first clipboard change after Copy is trusted. A second change, or a change between reading and restoring, aborts the transfer without adding anything and without overwriting the newer content.
- If restoring fails, the number is still added and the status message says the previous clipboard could not be restored.
- macOS offers no atomic compare-and-swap, so a write by another process that lands instead of the source app's copy cannot be told apart. A copy that arrives after the timeout is not restored, and a focus change during the transfer aborts it without a restore.

## Build and test

```sh
swift test --jobs 2
bash scripts/package.sh
open dist/SelectionMath.app
```

The packaging script builds a universal (arm64 and x86_64) binary, creates a clean app bundle in `dist/`, signs it ad hoc with the hardened runtime, and writes `dist/SelectionMath.zip` for the GitHub release. It is not notarized. Public distribution requires a Developer ID certificate, `codesign --options runtime --sign "Developer ID Application: ..."`, and `xcrun notarytool`. The app cannot run in the App Sandbox because it posts keyboard events and reads other applications through Accessibility.

macOS ties Accessibility and Screen Recording permissions to the code signature. Each ad hoc rebuild can require granting them again. Keep the app's path stable.

To inspect text recognition on an existing image without screen capture:

```sh
dist/SelectionMath.app/Contents/MacOS/SelectionMath --ocr-check /absolute/path/to/image.png
```

## Validation boundaries

Automated tests cover parsing, arithmetic, edits, ordering, reset and its undo, selection transfer through an OS I/O test double, pasteboard snapshot and restore on private pasteboards, layout-aware key translation, shortcut validation and storage, status message expiry, and localization coverage. Shortcut update and rollback tests enter through AppModel with only Carbon system calls replaced. Pasteboard and Vision integration tests require working macOS services and may fail in a restricted runner. The following still require interactive verification on a desktop:

- actual shortcut delivery and Copy support in each application
- permission prompts
- region capture on multiple displays
- the compact view and the shortcut recorder
- appearance variants
- visibility in the chosen recording tool

| Behavior | Test |
| --- | --- |
| Copy uses the key that types C on Turkish F, Dvorak, Russian, and US layouts | `testCopyKeyCodeProducesCOnEveryLayout` |
| Non-text copy restores the previous clipboard | `testNonTextCopyRestoresPreviousClipboard` |
| A slow copy within 1.5 s is accepted and restored | `testSlowCopyWithinTimeoutIsAcceptedAndRestored` |
| Concealed clipboard items are never copied over | `testConcealedClipboardRefusesCopyFallback`, `testSnapshotDetectsConcealedItems` |
| An incomplete clipboard backup refuses the Copy fallback | `testSnapshotRefusesAnIncompleteBackup` |
| Restored items are transient; newer clipboard content is kept | `testRestoreWritesSnapshotAsTransientAndSkipsNewerClipboard` |
| A second clipboard write, or one during reading, aborts without restoring | `testSecondClipboardWriteAbortsWithoutRestoring`, `testWriteBetweenReadingAndRestoringAbortsWithoutRestoring` |
| A failed restore is reported with the added selection | `testFailedRestoreIsReportedWithTheAddedSelection` |
| Unchanged clipboard content is never accepted as a new capture | `testCopyTimeoutDoesNotReadOldClipboardNumbers` |
| Reset during Copy restores the clipboard without stale data | `testResetDuringCopyRestoresClipboardWithoutAddingStaleData` |
| Parenthesized numbers are negative | `testParenthesizedNumbersAreNegative` |
| Currency signs and exponents keep their value | `testCurrencySignsAndExponentsKeepTheirValue` |
| Grouped Turkish exponents and spaced negative signs retain their values | `testGroupedTurkishExponentsKeepTheirMagnitude`, `testWhitespacePreservesNegativeSigns` |
| Unreadable fragments next to comma-separated numbers are reported | `testSkippedFragmentsBesideCommaSeparatedNumbersAreReported` |
| Accessibility and Copy captures preserve signs, exponents, and skipped warnings | `testCapturePreservesSpacedSignsExponentsAndSkippedWarnings` |
| Failure of any shortcut rolls back an update or a reset without saving it | `testFailureOfAnotherShortcutRollsBackTheWholeChange`, `testDefaultResetFailurePreservesCustomSettingsAndRegistrations` |
| A failed registration rollback is reported | `testFailedRollbackReportsUnavailableWithoutPersistingTheChange` |
| Unparsed number-like fragments are reported | `testUnreadableNumberLikeTokensAreReportedAsSkipped`, `testCommaBeforeSuffixSkipsTheWholeFragment` |
| A tab after a placeholder sign does not negate the next cell | `testTabAfterPlaceholderSignDoesNotNegateNextCell` |
| Swapping two operands reverses percentage change | `testSwapPairReversesTwoOperandsForPercentageChange` |
| An edit keeps the format it started with | `testEditKeepsTheFormatItStartedWith` |
| Corrupt or invalid shortcuts fall back to defaults; changes persist through the model | `testOutOfRangeStoredShortcutsFallBackToDefaults`, `testSettingAShortcutThroughTheModelRegistersAndPersistsIt` |
| Region selection maps to image pixels; text recognition reads rendered numbers | `testSelectionMapsToImagePixelsOnARetinaScreen`, `testTextRecognitionReadsRenderedNumbers` |
| Dotted decimal remains one operand in Turkish mode | `testDotDecimalRemainsOneNumberInTurkishFormat` |
| Large values keep all digits when displayed | `testLargeDecimalKeepsAllDigitsWhenFormatted` |
| Percentage point results and copied values | `testPercentageArithmetic` |
| Reset can be undone until the next change | `testUndoResetRestoresOperandsOperationAndUndoHistory`, `testUndoResetExpiresAfterTheNextChange` |
| Separate captures, editing, removal, and ordering | `testSeparateCapturesEditRemoveAndReorderThroughSession` |
| Shortcuts require a modifier, reject duplicates, and persist | `testValidationRequiresModifierAndRejectsDuplicates`, `testStoreRoundTripsAndFallsBackOnCorruptData` |
| Shortcut labels follow the keyboard layout | `testLabelsFollowTheKeyboardLayout` |
| Status messages clear without erasing newer ones | `testStatusMessageClearsAfterItsLifetimeWithoutErasingNewerMessages` |

## Design records

- [ADR-001: Native selection calculator](docs/adr/ADR-001-native-selection-calculator.md)
- [ADR-002: Explicit shortcut transfer](docs/adr/ADR-002-explicit-shortcut-transfer.md)
- [ADR-003: English interface and shared native styles](docs/adr/ADR-003-english-reference-based-interface.md)
- [ADR-004: Release hardening, compact mode, and customizable shortcuts](docs/adr/ADR-004-hardening-compact-mode-and-shortcuts.md)
- [ADR-005: Review-driven transfer and parser guarantees](docs/adr/ADR-005-review-driven-transfer-and-parser-guarantees.md)
- [ADR-006: Shortcut registration test boundary](docs/adr/ADR-006-shortcut-registration-test-boundary.md)
- [Design guide](docs/design-guide.md)

## License

[MIT](LICENSE)
