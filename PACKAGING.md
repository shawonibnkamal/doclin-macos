# Packaging Doclin

## Local preview

From a fresh clone, run `python3 scripts/voice/fetch.py` first. Then:

```sh
swift run DoclinChecks
SIGN_IDENTITY=- ./scripts/build.sh
open .build/preview-dist/Doclin.app
```

`UNIVERSAL=1` combines Apple silicon and Intel main app slices. The speech
helper/runtime is universal. Cross-compilation does not prove Intel playback.
The app targets macOS 13; enhanced speech needs supported macOS 26 devices and
languages, and the bundled Intel voice runtime requires macOS 15.5+.

An ad-hoc rebuild changes macOS's designated code requirement and can invalidate
Microphone/Accessibility grants. The script refuses ad-hoc output into the
installed `dist` directory. Default candidate output never replaces daily use.

## Stable local identity

`scripts/signing/setup-local.py` creates a dedicated encrypted Keychain outside
the repo. `scripts/signing/trust-local.sh` requests user-scoped code-signing
trust and may require macOS authentication. This setup is optional and for the
builder's Mac only; it is not Developer ID signing or notarization.

When no explicit `SIGN_IDENTITY` is supplied, builds reuse that local config if
present. Signing failures abort. Signed output defaults to `.build/signed-dist`.
Verify designated requirements match across changed builds before claiming
permission persistence. Switching away from an old ad-hoc identity may require
one permission renewal. Never publish private certificates, keys or passwords.

## Public downloads

Source publication and trusted binary distribution are separate milestones.
A public app download needs an Apple Developer Program account, Developer ID
Application certificate, and notarization credentials. None are in this repo.

```sh
UNIVERSAL=1 SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' ./scripts/build.sh
xcrun notarytool submit .build/signed-dist/Doclin-0.4.7-mac.zip --keychain-profile doclin-notary --wait
xcrun stapler staple .build/signed-dist/Doclin.app
codesign --verify --deep --strict .build/signed-dist/Doclin.app
spctl --assess --type execute --verbose .build/signed-dist/Doclin.app
ditto -c -k --sequesterRsrc --keepParent .build/signed-dist/Doclin.app .build/signed-dist/Doclin-0.4.7-mac.zip
```

Inspect the exact ZIP contents before upload. Include the third-party license
texts and corresponding sources already bundled by the build script. Verify a
quarantined download on a clean Mac and test target architectures. Publishing
an unsigned ZIP is not a substitute for those checks.

The app is unsandboxed to read user-owned agent sessions and install user-level
Claude hooks. It uses hardened runtime signing with audio/speech entitlements.
The local/ad-hoc voice helper retains a separate non-hardened policy because
those certificates lack an Apple Team ID. Public Developer ID helper builds
use hardened runtime. No network listener is exposed. Right Command passively
observes modifier/key-down events; it does not store typed key contents.

Move a released app to Applications before enabling Start at login. See
[Privacy](PRIVACY.md) for permissions, cloud options, retention and removal.
