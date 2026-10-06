# Selection Math design guide

## Direction

A quiet native utility with a visible calculation and a short path from selection to result. The interface is English, regardless of the system language. Number formatting is a separate preference.

The user supplied these visual references:

| Reference | Adopted qualities |
| --- | --- |
| Task panels, three appearance variants | White and charcoal surfaces, softly grouped controls, restrained destructive buttons, compact editable rows |
| Task panel detail | Consistent left alignment, cream content card, small raised controls, generous internal spacing |
| Welcome and shortcut cards | Pastel onboarding hero, rounded keycaps, blue primary action, short explanatory copy, progress dots |

The values below are implementation tokens interpreted from the references, not claimed measurements of their original design files. Use native SwiftUI drawing and SF Symbols. No image runtime, custom font, external UI dependency, or copied third-party logo is required.

## Palette

Offer System, Light, and Dark as a segmented control in Settings and persist the selection locally. Apply it to the whole application through `NSApp.appearance` so AppKit controls and menus match. System follows the macOS appearance setting. Use one light and one charcoal theme; the two dark reference variants are consolidated into a single dark palette.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| canvas | `#FFFFFF` | `#202125` | Window and sheets |
| surface | `#F3F5F6` | `#2C2E34` | Control groups, secondary buttons, operand rows |
| raised | `#FFFFFF` | `#3B3E46` | Keycaps and selected segments |
| text | `#202124` | `#F4F5F7` | Main text and values |
| muted | `#626975` | `#B3B8C2` | Help, source labels, metadata |
| border | `#E5E8EB` | `#484C55` | Thin control boundaries |
| note | `#FAF6E9` | `#32312D` | Calculation result |
| accent | `#006DDB` | `#66B5FF` | Focus, links, active operation |
| action | `#0070DF` | `#0070DF` | White-label primary button |
| danger | `#B9233B` | `#FF8D9C` | Remove and reset |

Primary blue is darker than the reference to keep small white labels legible. Pastel cyan, blue, and lilac washes are decorative and appear only behind the onboarding hero. Do not use gradients behind calculation text or operand rows.

## Layout and type

Default panel: 420 by 740 pt. Minimum window: 400 by 680 pt. Compact view: 320 by 300 pt by default, minimum 280 by 250 pt. Retain the native title bar, close control, resize behavior, and floating-window behavior. The window background uses the canvas token.

Main order: title with compact, settings, and help buttons, cream result card, operation group, operand list, selection actions, number format and manual entry, status. The list scrolls independently so controls remain available. Errors wrap rather than truncate. Reset sits beside the list, separated from the primary add action.

The About section in Settings displays the actual bundle version and build number. Do not hardcode a duplicate release version into a view. Use the shared segmented control instead of pop-up buttons for short option sets, including the number format. Reference images and private local filesystem paths are not included in the project.

| Element | Specification |
| --- | --- |
| Outer padding | 20 pt |
| Section spacing | 16 pt; 8 pt within groups |
| Card radius | 16 pt, continuous |
| Button radius | 10 pt, continuous |
| Main buttons | At least 40 pt high |
| Icon hit area | 28 by 28 pt |
| Window title | System 18 pt, semibold |
| Onboarding title | System 25 pt, semibold |
| Result | System rounded 44 pt, medium, monospaced digits |
| Operand | System rounded 17 pt, medium, monospaced digits |
| Body | System 13 pt |
| Supporting text | System 12 pt; source labels 11 pt |

Use sentence case. Align explanatory text left. Right-align compact actions. Keep all row actions visible, including outside hover, so a recording explains how values can be changed.

## Components and states

Primary button: solid action blue, white semibold label, small shadow, 10 pt corners. Reserve it for Add selection, onboarding Continue, and confirming captured text. Secondary button: neutral surface, main text, subtle border. Destructive button: pale danger fill with danger text. Do not use capsule shapes or layer a custom background on top of a native bordered button.

Pressed buttons darken slightly. Disabled controls lower opacity and do not react. Keyboard focus gets a visible accent outline. Use real SwiftUI Button controls so keyboard and accessibility behavior remain native. Respect Reduce Motion by avoiding decorative animations.

The operation selector uses a neutral well and a raised active segment with an accent symbol. Average, ratio, and percentage change remain in the More menu and are identified in the result heading.

Each operand row contains order, value, source, move up, move down, edit, and remove. Editing replaces the value with a field and explicit Save and Cancel buttons. Validation stays beside the field. Delete is immediate and Reset clears the session using existing behavior.

The result card contains operation name, Copy result, result, and the calculation expression. Empty state shows zero and a selection hint. Arithmetic errors replace the value with a readable explanation.

OCR review uses the same canvas, typography, and button styles. Show editable recognized text and require Add numbers. Never silently accept OCR punctuation.

## Compact view, status, and settings

The compact view keeps the operation menu, Copy result, the result, the latest three numbers with remove buttons, and a row with Add selection, Capture area, Undo last selection, and Reset. It hides the operand editor, number format, manual entry, and appearance controls. The full view button restores the previous layout. The mode persists.

Status messages occupy a fixed 44 pt slot so the layout never jumps. Messages clear after 4 s and errors after 8 s; a newer message is never cleared by an older timer. Messages are also posted as VoiceOver announcements. After a reset, the Reset button (trash icon in the compact view) becomes Undo reset for as long as the cleared calculation can be restored, independent of the message.

When average, ratio, or percentage change is active, the More button shows that operation's symbol in the raised, accent style used by the main segments.

Settings is a sheet titled Settings with three sections: Shortcuts (one recorder per shortcut and Restore defaults), Appearance (System, Light, Dark), and About (app version, author, and links to the website, GitHub profile, X profile, and source code). Section titles use 12 pt semibold muted text; links sit in a surface group with a trailing arrow. A recorder in progress uses the primary style and reads Type shortcut. Esc cancels. Validation messages appear under the shortcut list in the danger color.

## Onboarding

Use three steps within the panel, with progress dots and an always-available Skip action. Store only completion in UserDefaults. Reopen using the header help button. Skipping never grants permissions and never blocks manual entry.

1. Welcome: a sum tile in a pastel hero. Explain gathering numbers from different places.
2. Access: explain Accessibility for text and cell selection. Offer Allow access when not granted; show the current real permission status when granted. Continue remains available. Screen Recording is requested only when Capture area is used.
3. Shortcut: show Control, Option, and A keycaps. Explain selecting a value, pressing the shortcut, and repeating. Start calculating opens the working panel.

Show shortcuts from the stored settings and the active keyboard layout; never hardcode a combination in copy or keycaps. Do not request all permissions at launch. Do not show fabricated permission success or an automatic capture demo that changes the user's operands.

## English copy

Use Add selection, Capture area, Numbers, Reset, Number format, Enter numbers, and Copy result consistently. Use brief actionable error messages. App-owned interface strings must resolve through the English resource bundle even on a Turkish macOS installation. Source application names and system error descriptions may come from macOS.

## App icon

The icon pairs a blue mathematical sigma with four selection corners on a white porcelain-style tile. The same icon serves light and dark desktop backgrounds. Keep the menu bar symbol monochrome for native menu bar contrast.

Source: `Assets/AppIcon.png`, a 1254 by 1254 PNG with alpha, generated with the built-in image_gen tool. The packaging script derives the standard 16, 32, 128, 256, and 512 pt icon sizes at 1x and 2x using sips. A Python 3 standard-library helper packages those PNG bytes into `AppIcon.icns` without editing the images. The app declares this resource through CFBundleIconFile. Keep the source alpha and do not stretch the aspect ratio.

The local iconutil command rejected the valid PNG iconset. The packer uses the PNG representation identifiers documented in [Pillow's ICNS reader](https://pillow.readthedocs.io/en/stable/_modules/PIL/IcnsImagePlugin.html); Pillow itself is not a dependency. Validate the output with macOS sips and verify the signed app bundle.

Generation prompt:

> Use case: logo-brand. Asset type: production macOS app icon for Selection Math, a small native utility that collects selected numbers and performs arithmetic. Create ONE finished icon, square 1024x1024 composition, not a presentation sheet. A premium quiet macOS icon: a front-facing soft white porcelain rounded-square tile occupying 84% of the canvas width and height, centered, with continuous superellipse corners, very restrained bevel, soft short ambient shadow. On the tile, a bold substantial blue mathematical capital sigma summation symbol, optically centered, strongly legible at 32 pixels. Around the sigma, four short blue right-angle selection-corner marks forming an implied square selection area, with ample whitespace separating them from the sigma and tile edge. Use saturated azure blue #0070DF with subtle cyan highlight, white #FFFFFF and very pale cool gray. The blue symbol and corner marks have a small tactile raised depth similar to finely crafted native macOS productivity app icons, never glossy chrome or glass. Symmetric upright geometry, no perspective tilt. Refined soft studio lighting from upper left, crisp silhouettes. Transparent pixels outside the tile and its short soft shadow. No text, no letters other than the mathematical sigma, no wordmark, no numbers, no calculator buttons, no cursor, no decorative objects, no watermark. Prioritize simple recognizability on both light and charcoal backgrounds; avoid elaborate detail. Entire icon contained with generous transparent margins.

## Verification

Verify localized key coverage, onboarding step bounds and completion behavior, existing calculation tests, selection transfer tests, and screen-capture permission regression tests. Build one app at a time after approval. Validate bundled English resources and code signing.

Interactive review on the user's desktop is required for light/dark appearance, minimum window size, keyboard focus, actual permission dialogs, OCR sheet, and recording visibility. Compilation and automated tests alone do not establish visual fidelity.
