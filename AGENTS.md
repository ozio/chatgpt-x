# Instructions for AI agents

These rules apply to every agent working in this repository, including Claude,
Codex, Gemini and Grok. Read [CONTRIBUTING.md](CONTRIBUTING.md) first; it applies
to you as well.

**Start here:** [docs/development.md](docs/development.md) covers the Theos iOS 6
toolchain, building, installing on the iPhone (`make phone`), screenshots and
taps, and the kit gallery. [docs/building.md](docs/building.md) lists the build
inputs. [docs/device.md](docs/device.md) describes the install tooling.

## Scope and safety

- Work on the current branch. Commit only when asked. Don't create branches or
  pull requests unless asked.
- Keep the iPhone 5 / iOS 6 target (armv7, iOS 6.0 minimum, SDK 6.1, MRC, public
  frameworks only).
- Use only the user's existing ChatGPT account. Don't substitute a separate API
  account for acceptance.
- Protect the account and session. Prefer offline fixtures. Before any live check,
  set a small explicit budget of requests and attempts, run sequentially and reuse
  the existing session. Never do bulk activity, repeated sign-ins, session resets,
  parallel authentication or retry loops without a limit. Treat rate limits,
  security challenges, unusual-activity warnings and repeated sign-in failures as
  stop signals. If an experiment could put account access at risk, explain the
  risk and agree on a bounded plan with the user first.
- Never commit or print credentials, tokens, device identifiers or personal data.
  Private state, pairing credentials, TLS keys and test conversations stay in the
  git-ignored `.private/` and `.artifacts/`.
- Never add assets, strings or code copied or decompiled from the official app.
  You may use the official binary only as a behavioural reference; see
  CONTRIBUTING.md and the `rea` skill.

## Device

The device workflow is `make phone` (see [docs/device.md](docs/device.md)). When an
app change is ready, install it on the connected phone and check it there, unless
the user says otherwise. Keep the current unsent draft and the existing session.
Resolve the current USB UDID and identity before each install, and leave other
apps alone. Report offline checks, live checks on a modern host and checks on the
phone separately.

## UI: only the kit

Every screen, control and visual element is built only from the kit in `ios/ui`
(`RC*`, `RCTheme`, `RCGlyph`, `RCStage`). Before choosing how to present a feature,
read [docs/ui-kit-brief.md](docs/ui-kit-brief.md) and [docs/ui-kit.md](docs/ui-kit.md),
then find the example for that exact scenario in the kit gallery and in the
prototype `design/uxui/`, and reuse it. A missing native `RC*` class does not mean
the design is missing: port the prototype example into the kit.

Any agent may fix small UI bugs, make small layout or platform adaptations, wire
existing controls and do routine kit maintenance.

New controls, changes to global kit properties (theme, typography, shared metrics
or behaviour), screen redesigns and substantial interaction design are delegated
to Claude:

- **If you are Claude**, implement the design in the kit itself. Follow the brief:
  gallery page, `RCL()` English keys with Russian in `ru.lproj/Kit.strings`,
  light and dark themes, stages, VoiceOver and iOS 6 checks. Update
  `docs/ui-kit.md`, then use the component.
- **If you are not Claude**, hand the design task to Claude through any available
  channel, using the "Kit request" template from the brief. Wait for the result,
  review it and integrate it. If no channel exists, save the request as
  `docs/ui-kit-requests/<date>-<topic>.md`, tell the user, and continue with the
  independent parts of the work.

## Feature map

`docs/feature-map.md` and `docs/feature-map.json` describe every feature of the
official app and its status here. When your change alters a feature's status,
update both files in the same commit.

## Commit messages

Follow the format in CONTRIBUTING.md:

```
<area>: <imperative summary, at most 72 characters>

<why, what changed, and what was verified: offline / live / phone>
```

- Areas: `chat`, `codex`, `voice`, `kit`, `api`, `auth`, `l10n`, `build`,
  `device`, `docs`, `design`.
- One logical change per commit. Don't mix unrelated work that happens to be in
  the working tree. Stage only your own files.
- Use the imperative mood, with no trailing period, and no build numbers or dates
  in the summary.
- Don't add `Co-Authored-By:` or other attribution trailers.
