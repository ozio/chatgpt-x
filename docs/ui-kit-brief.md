# ChatGPT X UI kit — design brief

The rules every ChatGPT X screen and every kit component follows. Feature code
uses only the kit (`ios/ui`); the kit is the single place where look and
behaviour are defined. The component catalogue with states is `docs/ui-kit.md`;
the approved interactive prototype is `design/uxui/` (open `index.html` via
`python3 design/uxui/tools/serve.py`). This brief is also the design context to
pass along when a non-Claude agent hands a kit task to Claude (see the request
template at the end).

## 1. Platform

- iPhone 5 / iOS 6.1.4 (also 320-pt iPhone 4/4S with a 480-pt screen), portrait,
  @2x. SDK 6.1, ARMv7, Objective-C, MRC (`-fno-objc-arc`), `-Wall -Werror`.
- Kit links only UIKit, Foundation, CoreFoundation, CoreGraphics. QuartzCore
  headers for `CALayer` messages only. No private API, `dlopen`, swizzling,
  WebViews or network code inside the kit. The app owns account, network,
  storage, camera and microphone; components report taps through delegates.
- Everything must render on the device itself; there is no iOS 6 simulator.

## 2. Visual language — iOS 6 "jade glass"

Skeuomorphic iOS 6, recoloured green; it must look like a 2012 Apple app.

| Element | Rule |
| --- | --- |
| Bars | jade glass navigation bar and toolbar (`RCTheme styleNavigationBar:variant:`): jade, graphite for a temporary chat, dark for media. Bar buttons are stock `UIBarButtonItem` (bordered) with `RCGlyph` icons |
| Backgrounds | light linen behind content (`contentBackgroundColor`), dark green linen in the drawer and on welcome/media screens |
| Content | answers are white cards (10-pt radius, `#c7d2cc` stroke, soft shadow); own messages are matte jade bubbles with a swoosh tail — the flat bottom runs into a sharp tip at the bottom right (flat `#2b9f63`, 1-pt `#1e8650` stroke, 1-pt light top edge; nothing scales with height); parts are 8-pt boxes (`RCPartView`) |
| Lists & settings | iOS 6 grouped tables (`styleGroupedTableView`, `styleGroupedCell:position:`), engraved section headers, jade checkmark (`checkmarkAccessoryView`), green selection |
| Controls | `RCButton` (large 44 pt white/green/red/dark; 26-pt pills plain/go/red), `UISwitch` with jade ON, `RCSegmentedControl`, `RCTextSizeSlider`; system `UIAlertView`, `UIActionSheet`, `UIMenuController`, `UIActivityIndicatorView` stay stock |
| Icons | only `RCGlyph` line glyphs (24-pt grid, any size/colour) and glossy tiles (29/40/57 pt, 11 colours). New glyphs are added to `design/uxui/js/icons.js` and regenerated into `RCGlyphData.inc` (`ios/ui/tools/gen-glyphs.cjs`) |
| Logo | the installed app icon's silhouette (`design/app-icon`). Large logos are the bare mark without a tile, border or drop shadow (`RCTheme brandMarkImage:size:grey:` / `drawBrandMark:inRect:grey:`, `rc-mark-*@2x.png`): debossed in the linen (empty chat; light/dark artwork, grey when temporary), white embossed on dark linen (welcome, launch), emerald embossed on light backgrounds. The rounded tile (`appIconImage:`, `rc-app-icon-*`) stays for small app headers and the home screen. Never draw a different mark |
| Status | `RCLampView` shows what the app really observes: ok green, busy amber pulse, warn amber, error red, info blue, off grey |
| Transitions | stock push/modal; switching between whole app states (chat ↔ sign-in) is the iOS 6 card flip `RCFlipChildViewControllers` — from the left when leaving the account, from the right when coming back |
| Feedback | `RCHUD` (done / busy / text), `RCProgressView` (jade/amber, indeterminate barber pole), `RCBannerView` under the bar (warn / error, optional pill) |

Colours, fonts and metrics come only from `RCTheme` (palette accessors,
`bodyFont`, `bodyLineHeight:`, `RCHex`). If a new colour is unavoidable, add a
named accessor to `RCTheme` with its light and dark value — never a literal in a
screen. Typography: system font (Helvetica on iOS 6); body text follows the
five text-size steps XS 14/18, S 15/20, M 16/21 (answers 16/22), L 19/26,
XL 22/29; meta 11–13 pt bold grey; engraved labels on linen (white shadow light,
black shadow dark).

## 3. Behaviour rules

- **Stages.** Features roll out by usefulness 10 → 6 (`RCStage`, prototype
  `features.js`). A component exposes capability flags; the caller sets them from
  `RCStageOn(n)` **and** what the build can really do. A slot never appears as a
  disabled "coming soon" control; the layout of other slots never moves.
- **Honest states.** Show what is true: failed "!" (safe retry) differs from
  unconfirmed "?" (check history); account content that cannot be shown gets
  `RCPartPlaceholderView`, never silently dropped; errors keep the user's draft.
- **Appearance.** Every component supports light and dark (`RCTheme isDark`,
  observe `RCThemeAppearanceDidChangeNotification`) and the text size
  (`RCThemeTextSizeDidChangeNotification`). Bars, bubbles, banners, drawer and
  sheets keep their look in dark.
- **Language.** Kit strings are written in English through `RCL(@"…")`; every
  new string gets its Russian value in `ios/localization/Resources/ru.lproj/Kit.strings`
  (`python3 scripts/kit-strings-en.py "$PWD"`). App strings use `OR6L` with en/ru in
  `Client.strings`. No bare Cyrillic literal in `ios/ui/*.m`, `ios/ui/gallery/*.m` or app UI files.
- **Accessibility.** Every control has a VoiceOver label, hint where useful,
  correct traits (button, link, header, selected, not enabled) and, for app
  automation, an `accessibilityIdentifier` in the `chat.*` namespace.
- **Touch.** Targets at least 44 × 44 pt (or padded hit areas); long press shows
  the system menu; destructive actions confirm with a red action-sheet button.

## 4. iOS 6.1.4 pitfalls (device-verified — always use the helpers)

| Problem | Use |
| --- | --- |
| Multi-line `UILabel` with plain `text` drops or clips the word at a line break | `RCLabelSetText`, measure with `RCMeasureText` |
| `UITextView -setText:` turns `\n` into spaces | set `attributedText` |
| Attributed text in `UITextView` with the system font draws in Times; an empty text view returns `nil` from `-font` | `RCTextViewAttributes(font, colour)` / `RCTextViewFont` |
| A layer taller/wider than 2048 pt (4096 px) is not drawn at all | no `drawRect` on views that can grow; stretchable images (`RCTheme imageForKey:…capInsets:`); long text in `RCTextStackView` |
| ₽ is missing from iOS 6 fonts | `RCDisplayText` for display, keep the original for copy/send |
| No Auto Layout use, no `estimatedRowHeight`, no `NSLayoutManager` | frame layout with `-heightForWidth:`; cache heights; window long lists |
| `UIBarButtonItem` has no `accessibilityIdentifier` on iOS 6 | identify the screen/control another way |
| `resizableImageWithCapInsets:` tiles by default; a tiled image in a `UIImageView` that keeps resizing crashed UIKit (EXC_BAD_ACCESS in a CA commit) | only `RCTheme imageForKey:…capInsets:` (stretch mode) |
| Adding subviews inside `-layoutSubviews` of a view UIKit is walking | create subviews in `init`; guard `layoutSubviews` while deallocating |
| A strings table present only in `en.lproj` is used even on a Russian iPhone (fallback to the development region) | ship `Kit.strings` in both `en.lproj` and `ru.lproj` (`scripts/kit-strings-en.py`) |

Performance: configure reused cells without rebuilding unchanged content
(equality checks in setters), never measure hundreds of rows before the first
frame, keep main-thread work per frame small (target < 16 ms; checked < 40 ms
worst case on iPhone 5).

## 5. Definition of done for a kit component

1. `RCName.h/.m` in `ios/ui`, listed in `RCKit.mk`; public header comment says
   what it is (prototype selector), its states and its delegate.
2. Properties + delegate, no app/network logic; honest states; stage flags.
3. Light/dark, all five text sizes, `RCL` English strings + Russian localization, VoiceOver.
4. A ChatGPTXKit gallery page (or section) showing every state, gated by stage,
   reachable by `chatgptxkit://page/<Name>`.
5. Type-checks against the iOS 6.1 SDK with `-Wall -Werror`; ChatGPTXKit builds;
   `python3 tests/chat-ui9/verify.py` and `python3 tests/localization/verify.py`
   pass when the app uses it.
6. Checked on the iPhone (screenshots through the gallery route; real touches with
   `tests/phone-touch/touch.py` where it matters; open and leave its gallery page); `docs/ui-kit.md` updated, including what was not verified.

## Kit request (template for handing a task to Claude)

Use this when you are not Claude and the task involves implementing a new
control, changing global library properties, or other substantial artistic or
UI/UX design work (see `AGENTS.md`). Small bug fixes, minor adaptations, wiring
existing controls and routine maintenance may be done independently, including
focused kit fixes and small state/property/callback changes that preserve the
established design. A missing state or property alone does not require Claude.

Send the design task to Claude through any channel you have, for example a
delegation tool or the `claude` CLI run in this repository. Use more effort for
complex UI/UX design, broad changes or difficult tradeoffs. If no channel exists, save it as
`docs/ui-kit-requests/<YYYYMMDD>-<topic>.md` and stop only the part requiring
Claude. Routine fixes and independent work may continue.

```markdown
# Kit request: <component or property>

Project: this repository (read AGENTS.md,
docs/ui-kit-brief.md, docs/ui-kit.md first).

## Feature that needs it
<what the app screen does, which stage (10…6), which Core operation backs it>

## What is missing in the kit
<new component / new state / new property / new delegate callback>

## Expected look and behaviour
<prototype reference: design/uxui file + selector or screen; states; texts in
Russian; light/dark; text sizes; VoiceOver; stage flag>

## Data in / events out
<properties the app will set; delegate callbacks it needs>

## Done when
<gallery page/route, build and checks from the brief's definition of done>
```
