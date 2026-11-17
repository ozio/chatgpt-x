# Contributing to ChatGPT X

Thanks for helping. ChatGPT X is a fan project: a native ChatGPT client for iOS 6.
Before you start, read the disclaimer in the [README](README.md). Contributions
must follow it too.

## Ground rules

- **No original assets, strings or decompiled code.** Don't copy images, sounds,
  localization strings or code from the official ChatGPT app or its binaries into
  this repository. Write your own implementation and your own texts. You may
  observe how the official app behaves, but write the code yourself.
- **Protect accounts.** Test with your own account. Prefer offline fixtures.
  Make live requests few and paced, and never write retry loops, stress tests or
  bulk actions. Treat rate limits, security challenges and "unusual activity"
  warnings as a signal to stop and investigate offline. Never bypass service
  controls.
- **Never put credentials, session tokens, device identifiers (UDID, serial),
  personal data or real conversation content into commits, fixtures, logs or
  screenshots.** Private state belongs in the git-ignored `.private/` and
  `.artifacts/`.
- **iOS 6 first.** Target armv7, iOS 6.0, SDK 6.1 and manual retain/release, and
  use only public iOS 6 frameworks. Don't assume APIs from iOS 7 or later.

## Project layout

| Path | What it is |
|---|---|
| `ios/chat/` | App controllers: root, conversation, session, coordinator, Codex screens |
| `ios/api/` | Client request layer. `OR6APICore` routes named operations to providers. The `priority*` and `revisit*` folders are feature modules. |
| `ios/auth/` | Web session, sign-in page and keychain storage |
| `ios/ui/` | The UI kit (`RC*` classes), feature screens and the kit gallery app |
| `ios/voice/`, `ios/webport/` | Realtime voice runtime and the embedded web engine loader |
| `ios/localization/` | `Client.strings` (app) and `Kit.strings` (UI kit), English and Russian |
| `ios/standalone/chat-app/` | Theos project for the app itself |
| `support/` | Operation contracts (JSON schemas) shipped in the app and build helpers |
| `scripts/` | Build (`build-chat.py`) and device tooling (`phone.py`) |
| `design/` | Icon sources and the HTML prototype of every screen (`design/uxui/`) |
| `docs/` | Building, device workflow, UI kit and the feature map |
| `tests/` | Fixtures compiled only into acceptance builds |

The `OR6` and `RC` prefixes are historical and stay as they are for now.

## Picking something to work on

[docs/feature-map.md](docs/feature-map.md) lists every feature of the current
official iOS app and its status in ChatGPT X. It is not a roadmap, only a map of
what exists and what is open. Good first tasks:

- 🔧 **Client API only**: the request layer exists, so the work is a screen built
  from the kit.
- 🟡 **Partial**: finish the missing states.
- ⬜ **Not implemented**: start from the operation contract and the screen in the
  prototype.

When a status changes, update both `docs/feature-map.md` and
`docs/feature-map.json` in the same commit.

## Comparing with the official app

To see how a feature really behaves (which requests it makes, which states and
errors it handles, what the screen flow is), study the official app on your own
device or from your own copy of its binary.

Agents and contributors who use Claude Code will find the **`rea` skill**
(reverse-engineer-anything) useful. Point it at the real ChatGPT binary you
legally own to trace a feature, list its screens and states, and compare versions.
Use what you learn only as a behavioural reference. Then write the implementation,
the strings and the UI here yourself, and don't commit dumps, decompiled output,
symbol lists or extracted resources.

## UI: only the kit

Every screen is built from the UI kit in `ios/ui` (`RC*` classes, `RCTheme`,
`RCGlyph`, `RCStage`). Don't add ad-hoc views, colours, fonts or icons in feature
code.

1. Find the screen in the prototype (`design/uxui/`) and the matching kit
   component in [docs/ui-kit.md](docs/ui-kit.md).
2. Reuse the kit's example for that exact scenario. A missing native class doesn't
   mean the design is missing: port it from the prototype into the kit.
3. Kit strings go through `RCL()` with English keys and Russian in
   `ru.lproj/Kit.strings`. App strings go through `OR6L()` in `Client.strings`.
   Every new string needs both languages.
4. Check light and dark themes, all five text sizes and VoiceOver.

New controls and changes to the visual language need design work. Describe them
first with the "Kit request" template in [docs/ui-kit-brief.md](docs/ui-kit-brief.md).

## Building and testing

See [docs/building.md](docs/building.md) and [docs/device.md](docs/device.md).
Keep these three kinds of check separate and say which ones you ran:

1. **Offline:** the build passes, plus fixtures and gallery pages.
2. **Live on a modern host:** a minimal, paced request against the real service.
3. **On a real iOS 6 phone:** the change is installed and checked on the device.

## Commits

Use one logical change per commit. Format:

```
<area>: <imperative summary, at most 72 characters>

<why the change is needed and what it changes; wrap at 72>
```

Areas: `chat`, `codex`, `voice`, `kit`, `api`, `auth`, `l10n`, `build`, `device`,
`docs`, `design`. Examples:

```
kit: add side menu visibility settings
codex: replace device check with connection status row
docs: regenerate feature map after projects work
```

- Use the imperative mood ("add", "fix", "remove"), with no trailing period.
- The body says what was verified: offline, live or on the phone.
- AI agents follow [AGENTS.md](AGENTS.md) and add no attribution trailers.
- Never commit `.private/`, `.artifacts/`, IPAs, keys or anything personal.

## Pull requests

Describe the user-visible change, link the feature-map rows it affects and
attach screenshots taken with the **English** interface. Mention any limits that
remain.
