# Device workflow

During development the app is built on the Mac and installed over USB on a
jailbroken iPhone connected to it. `scripts/phone.py` drives everything. These
`make` targets wrap it:

```bash
make phone            # build current source, install, verify
make phone-build      # build only
make phone-install    # install the latest verified build, then verify
make phone-check      # verify installed bytes, process, foreground and app state
make phone-screen     # take a native screenshot
make phone-restart    # one cold launch, keeping a supplied draft
```

`PHONE_ARGS` passes extra flags, for example
`make phone-check PHONE_ARGS='--package /abs/path --launch'`.

## Requirements on the phone

- Jailbreak with OpenSSH.
- AppSync Unified, which provides `/usr/bin/appinst`.
- `uiopen` for launching URLs. A HID touch helper is needed only if you use the
  `tap`, `swipe` and `longpress` commands.

The tool checks for one exact device identity, `iPhone5,2` / iOS 6.1.4 / 10B350,
in `EXPECTED` in `scripts/phone.py`. Change it for your own phone.

## Private configuration

`.private/phone.json` is git-ignored. It holds paths only, never secrets inline:

```json
{"host": "iphone-usb", "sshConfig": "/abs/path/ssh_config", "askpass": "/abs/path/askpass",
 "touchHelper": "/var/root/<dir>/rctouch"}
```

`touchHelper` is the path of the HID touch helper on the phone, used by `tap`,
`swipe` and `longpress`.

The SSH alias must point to loopback through a UDID-bound `iproxy`, use strict
host-key checking and have no ProxyJump or ProxyCommand. Before any install, the
tool reads the USB identity and checks that the phone-side helper reports the same
UDID, hardware and OS.

## What an update does

1. Checks that the package was built from the current source tree. It refuses a
   downgrade and refuses to update while a request or send is in progress.
2. Backs up the app's `Documents` and `Library` privately. If the composer has an
   unsent draft, you must supply it with `--draft-file`. The new build restores it
   once.
3. Writes a checkpoint, installs once with `appinst` and verifies the installed
   bytes against the IPA. If the result of an install is unknown, the tool refuses
   another install until you reconcile it with `phone-check`.
4. Launches the app and waits for a ready, signed-in foreground state. It stops on
   rate limits, security challenges or sign-in errors.

The first install of the bundle ID skips steps 1, 2 and 4, because there is no
session or data yet. You sign in by hand.

The tool never signs in, resets a session, sends a message or changes server
settings. Receipts and screenshots are written to
`.artifacts/phone-theos-20261110/`.

## Touch input for UI checks

```bash
python3 scripts/phone.py tap --observation <screen-run>/deployment.json --x X --y Y
```

Coordinates come from a fresh screenshot (at most 30 s old) in the 640×1136 pixel
space, and the target app must be in the foreground. Each observation can be used
only once, and an input with an unknown outcome is never replayed. `swipe` and
`longpress` follow the same rules.

## Acceptance builds

`--acceptance` builds include test fixtures from `tests/` and require an explicit
`--package` path. They never become the default package. Always finish with an
ordinary build and install.
