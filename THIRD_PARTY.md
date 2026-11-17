# Third-party components

The code in this repository is MIT-licensed (see [LICENSE](LICENSE)). The
components below are not stored here. The build fetches or builds them from
pinned sources, and a built IPA includes their licence texts under
`Licenses/`.

| Component | Version | Licence | Used for |
|---|---|---|---|
| Mbed TLS | 3.6.7 | Apache-2.0 | TLS for native HTTPS and realtime voice |
| libssh2 | 1.11.1 | BSD-3-Clause | Codex over SSH |
| PocketSphinx + en-US model | 5.0.4 | BSD-2-Clause | Offline dictation fallback |
| Opus | pinned | BSD-3-Clause | Voice codec |
| libsrtp, usrsctp | pinned | BSD-3-Clause | Realtime voice transport |
| libpeer | pinned | MIT | WebRTC peer connection |
| quirc | vendored in `ios/chat/codex/qr/` | ISC | QR code reading for Codex pairing |
| core-js | 3.51.0 | MIT | JavaScript polyfills for the iOS 6 web view |
| Babel | 8.x (build time only) | MIT | JavaScript preparation |
| [Web Port](https://lululab.net/) by lululab | pinned packages in `support/webport-bundle/inputs.json` | Belongs to lululab; its WebKit and LibVLC parts are LGPL/BSD | Embedded modern web engine |

## Not included

- No SDK, official ChatGPT IPA, executable, image, sound or localization
  resource from the official app.
- No account data, session tokens, keys or device identifiers.
- The Sentinel JavaScript modules are OpenAI's code. They are read from
  chatgpt.com at build time and are not part of this repository (see
  [docs/building.md](docs/building.md)). The release IPA contains them, as
  every browser that opens chatgpt.com does.

"ChatGPT", "OpenAI" and the OpenAI logo are trademarks of OpenAI. This project
is not affiliated with OpenAI.
