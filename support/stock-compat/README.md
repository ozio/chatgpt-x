# Stock UIWebView compatibility resources

Research only. Production keeps OR6ChatWebPreparation and the existing web
session/history/native transport. No account, service, collector, proof search
or challenge VM is used by this layer's fixtures.

Build pinned local resources (no download/install):

    node support/stock-compat/build-resources.mjs --output .artifacts/stock-compat-20261111/resources

Then run independent host checks under OS deny-network:

    /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' node support/stock-compat/verify.mjs --output .artifacts/stock-compat-20261111/host-new

The existing prototype-login/tools lock pins core-js3.51.0; vendor-lock.json
additionally pins the selected transitive module bytes and complete MIT notice.
Only the selected modules are bundled; no npm postinstall is run. The generated
resource and original license notices go into the separate research IPA.
syntax-check.mjs additionally rejects block-level function declarations: modern
ES5 parsers accept this extension, but stock iOS 6 rejects it in strict code.
The host verification includes the formerly missed syntax as a negative control.

runtime.js supplies a missing UTF8 TextEncoder/encodeInto and performance.now.
Encoding replaces lone UTF16 surrogates, avoids partial scalar writes and checks
the receiver through core-js internal state. Native crypto and native encoders
or clocks are preserved. Missing performance.now uses real webkitNow if present,
otherwise clamped elapsed Date.now: coarse, nondecreasing, not native high
resolution. No navigation timeOrigin, UA, screen, navigator or DOM is fabricated.
The layer records only implementation metadata and identity-preservation flags.

Symbol/JSON integration requires reviewed Object/JSON wrappers, not just new
globals. The probe records replacements and only permits its explicit standard
wrapper allowlist; unknown replacements fail. Original Function.prototype.toString
is restored after core-js initialization and remains unchanged: added shims show
their real JavaScript source. Native source camouflage is not exposed.

ES5 Symbol is emulated. typeof Symbol.iterator need not be "symbol"; this
must not be faked. Successful semantic iteration and real API presence must be
reported separately from native-Symbol availability. Old-iOS Promise uses
core-js's supported scheduler fallback; native microtask equivalence for every
timing scenario is not asserted.

compat-fixtures.js exports __OR6CompatFixtures.start() ("started"/"conflict")
and take() (JSON: phase, checks, failures, firstFailure, asyncSettled, coreReady).
Known failure enums are identity, map, set, iterator, url, utf8, clock, core,
promise and promise_timeout, plus the empty string. It tests actual standard
semantics and restricted core.b/core.e/core.c(no-proof or missing-input) paths.
The Object/JSON wrappers also have Symbol-key, descriptor and serialization
fixtures. Those core exports are called; collector/normal preparation, valid proof
search and challenge VM are never called. Results contain no header values.

Host verification strips modern globals in fresh Node realms, compares2513
UTF16 cases and small encodeInto buffers against the native encoder, checks
idempotence/native preservation and deliberately missing/broken controls.
This is not a substitute for old-JSC execution. The stock-preparation app owns
the physical before/after runtime and engine observations.

After building a fresh stock-preparation IPA, run exactly one local device check:

    python3 support/stock-compat/device-check.py --package BUILD_DIR --output NEW_RECEIPT_DIR

The driver checks current source and phone identity, captures the actual installed
production build, runs the independent probe once, removes that probe, and resumes
the same production conversation/draft. It checks production bytes and WebPort
settings before and after. An unresolved pending checkpoint prohibits replay;
inspect that checkpoint instead of launching a second attempt blindly.
