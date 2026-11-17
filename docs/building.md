# Building ChatGPT X

ChatGPT X is Objective-C with manual retain/release (MRC). It is built with Theos
against the iOS 6.1 SDK for armv7 and links only public iOS 6 frameworks.

> [!NOTE]
> Today the build is reproducible on the maintainer's machine. It is not yet a
> one-command build for a fresh clone. Several pinned third-party inputs live in an
> ignored `.artifacts/` directory, and recipes for some of them are not in the
> repository yet. The table below says which inputs have a script and which don't.
> Help with turning the rest into scripts is very welcome.

## Toolchain

- macOS with Xcode command-line tools, GNU make (`gmake`), Python 3.9+ and Node.js 20+.
- [Theos](https://theos.dev) at `~/theos`, or set `THEOS`, with the
  `iPhoneOS6.1.sdk` and a legacy cctools/ld64 that can still link armv7 for
  iOS 6. `make toolchain` installs this pinned setup, and `make toolchain-doctor`
  checks it (see [development.md](development.md)).
- `ldid` for fake signing. AppSync Unified on the phone accepts the result.
- `tools/`: run `npm ci --ignore-scripts` there once. Babel and core-js are
  used at build time to prepare JavaScript for the iOS 6 web view.

## Pinned inputs in `.artifacts/`

Every input is pinned by SHA-256, and the build stops if a hash does not match.

| Input | Used for | How to get it |
|---|---|---|
| Mbed TLS 3.6.7, armv7 archive and config | Native HTTPS and TLS 1.3 | Build Mbed TLS 3.6.7 for armv7/iOS 6 with `support/native-api/transport/mbed-user-threaded.h` as the user config. No script yet. |
| Public root certificates (`system-public-roots.pem`) | TLS trust store shipped in the app | Export a current public root bundle. No script yet. |
| libssh2 1.11.1, armv7 | Codex over SSH | Build libssh2 against the Mbed TLS above. No script yet. |
| PocketSphinx 5.0.4 + en-US model | Offline dictation fallback | `python3 support/revisit5asr/build.py` (downloads the pinned release) |
| Opus, libsrtp, usrsctp, libpeer | Realtime voice | Base libraries: no script yet. Final archive: `python3 support/voice-realtime/build.py --target armv7` |
| WebPort runtime | Modern web engine for sign-in and web pages | `python3 scripts/webport-bundle.py` (downloads the pinned packages listed in `support/webport-bundle/inputs.json`) |
| Two chatgpt.com JavaScript files | The Sentinel module | See below. |

### The Sentinel module

To send a message, chatgpt.com requires the browser to run its Sentinel checks.
ChatGPT X does not reimplement or bypass them. At build time,
`support/sentinel-minimal/extract.mjs` reads two public JavaScript files that
chatgpt.com serves to every browser. It copies four modules from them unchanged
and wraps them in a small loader. The app then runs these modules in its web view,
exactly as a browser would.

These files are OpenAI's code. They are **not** stored in this repository, and the
IPA you build contains them only for your own use. The build pins exact file
hashes. When chatgpt.com ships new versions, the pins and the module names in
`extract.mjs` must be updated.

## Build

```bash
make phone-build
```

This runs `scripts/build-chat.py`. The script copies every source file it uses
into a snapshot, compiles that snapshot with Theos and adds the resources (web
engine, models, licences, localizations). Then it verifies the Mach-O (armv7,
iOS 6.0 minimum, SDK 6.1, public frameworks only) and writes a deterministic
`ChatGPTX.ipa` to `.artifacts/phone-theos-20261110/ordinary<N>/`.

Each build gets the next build number (`CFBundleVersion`). Build numbers never go
down, and the installer refuses to downgrade.

## Install

See [Device workflow](device.md) for USB installs during development, or the
README for installing an IPA by hand.
