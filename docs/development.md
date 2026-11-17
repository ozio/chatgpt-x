# Development guide

The quick path from a fresh Mac to a change running on an iOS 6 iPhone. It is
written for people and for AI agents alike. For the rules see
[AGENTS.md](../AGENTS.md) and [CONTRIBUTING.md](../CONTRIBUTING.md).

## 1. Toolchain: Theos for iOS 6

iOS 6 needs an old SDK and an old linker, which current Xcode no longer has.
`tools/theos/` installs a user-local, pinned setup:

| Piece | Pin |
|---|---|
| Theos | commit in `tools/theos/pins.json` |
| iPhoneOS 6.1 SDK | archive checked by SHA-256 |
| cctools-port (`ld64-956.6`) | built natively for Apple Silicon, targets `arm-apple-darwin11` |

```bash
make toolchain          # once: installs into ~/theos (or $THEOS)
make toolchain-doctor   # checks pins, SDK, linker and ldid; prints THEOS_LEGACY_ENV_OK
source tools/theos/env.sh   # exports THEOS and THEOS_LEGACY_PREFIX for manual gmake runs
```

You need macOS on Apple Silicon, full Xcode, Homebrew (for `ldid` and GNU
`make`), Python 3 and Node.js. Then run `npm ci --ignore-scripts` in `tools/`.

The app also needs the pinned third-party inputs in `.artifacts/`. See
[building.md](building.md).

## 2. The phone

- An iPhone on iOS 6, jailbroken, with OpenSSH and **AppSync Unified** (which
  provides `appinst`) installed from Cydia (`https://cydia.akemi.ai/`).
- USB to the Mac, an `iproxy` tunnel for SSH, and `.private/phone.json` with the
  SSH alias. See [device.md](device.md).
- `scripts/phone.py` accepts exactly one device identity (`EXPECTED`, currently
  `iPhone5,2` / iOS 6.1.4). Change it for your phone.

## 3. The everyday loop

```bash
make phone          # build current source → install → verify the running app
make phone-screen   # native screenshot (path printed as JSON)
```

1. Edit the code.
2. Run `make phone`. It builds a new numbered IPA, backs up the app's data, installs
   it, checks the installed bytes and waits until the app is running and signed in.
3. Take a screenshot and look at it. To navigate, take a fresh screenshot and tap
   coordinates from it, in the 640×1136 pixel space:

   ```bash
   python3 scripts/phone.py screen --output /tmp/s1
   python3 scripts/phone.py tap --observation /tmp/s1/deployment.json --x 48 --y 84 --output /tmp/t1
   ```

   Each observation is single-use. `swipe` and `longpress` work the same way.

Install rules the tool enforces: no downgrades, no update while a send is in
progress, and an unsent draft must be preserved with `--draft-file`. The first
install of a bundle ID needs a manual sign-in on the phone. Agents never type
passwords or codes; ask the user to sign in.

## 4. Where things go

| To add… | Put it in |
|---|---|
| A request to the service | An operation in `ios/api/…` (provider and policy) and its JSON schema in `support/<module>/contracts.json` |
| A screen | `ios/ui/priority*/` or `ios/chat/`, built only from kit `RC*` components |
| A new control or visual state | The kit, `ios/ui/RC*.h/m`, plus a gallery page in `ios/ui/gallery/` and an entry in `docs/ui-kit.md` |
| Text | `OR6L(@"English")` → `ios/localization/Resources/{en,ru}.lproj/Client.strings`; kit text `RCL()` → `Kit.strings` |
| A feature status change | `docs/feature-map.md` and `docs/feature-map.json` |

Keys are English sentences. A translation may be shorter than its key; change the
value in both languages instead of editing the key in code.

## 5. The kit gallery (ChatGPTXKit)

A separate offline app (`io.ozio.chatgptx.kit`) shows every kit component in
every state, at stages 6–10, in light and dark themes and at all five text sizes.
It never contacts the network.

```bash
source tools/theos/env.sh
cd ios/ui/gallery-app && gmake clean package messages=yes
```

Build in a scratch copy of `ios/ui`, because Theos leaves `.stamp`/`.o` files next
to the sources. Make an IPA from `.theos/_/Applications/ChatGPTXKit.app` (wrap it
as `Payload/ChatGPTXKit.app`). The gallery ships no `Kit.strings`, so copy
`ios/localization/Resources/{en,ru}.lproj/Kit.strings` into the app if you want
the Russian text. Install it with `appinst` over SSH, then open a page:

```bash
ssh iphone-usb "appinst /var/tmp/ChatGPTXKit.ipa"
ssh iphone-usb "su mobile -c \"uiopen 'chatgptxkit://page/Form?stage=7&dark=1'\""
```

Routes: `chatgptxkit://page/<Name>[?stage=6…10][&size=0…4][&open=N][&dark=0|1]`.
`phone.py`'s `Phone` class (`copy`, `remote`, `capture`) can drive these steps
from Python. A Home Screen screenshot after `uiopen` means the gallery crashed:
read `/var/mobile/Library/Logs/CrashReporter/LatestCrash-ChatGPTXKit.plist`.
Use the gallery to check a component before you wire it into the app.

## 6. Checking your work

Report three levels separately:

1. **Offline:** the build passes (`make phone-build`), the gallery page renders, and
   fixtures pass.
2. **Live on a modern host:** a minimal, paced request to the real service, if
   one is needed.
3. **On the phone:** installed with `make phone` and checked with screenshots.

Then commit following [CONTRIBUTING.md](../CONTRIBUTING.md#commits).

## 7. Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Wrong pin` from the doctor | `~/theos` is at another revision. Use a separate `THEOS` directory. |
| `source drift` from `extract.mjs` | The pinned chatgpt.com files changed or are missing (see building.md). |
| `Refusing to downgrade` | A newer build is installed. Build again; build numbers only go up. |
| `Prior install has an unresolved outcome` | Run `make phone-check PHONE_ARGS='--package … --launch'` to reconcile. |
| `App reported service stop` | A rate limit or security challenge. Stop live work and investigate offline. |
| Home screen instead of the app | The app crashed. Check the device log; a crash shows as the Home Screen in screenshots. |
