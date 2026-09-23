# Packaging Doclin

The build script creates a self-contained `Doclin.app` and ZIP. It uses macOS 13 as the deployment floor. The default build targets the build Mac's architecture; `UNIVERSAL=1` combines Apple silicon and Intel binaries.

## Public release

Developer ID signing requires an Apple Developer Program account and an installed signing identity. These are not included in the source or preview.

```sh
UNIVERSAL=1 SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' ./scripts/build.sh
xcrun notarytool submit dist/Doclin-0.2.0-mac.zip --keychain-profile doclin-notary --wait
xcrun stapler staple dist/Doclin.app
codesign --verify --deep --strict dist/Doclin.app
spctl --assess --type execute --verbose dist/Doclin.app
# Recreate ZIP after stapling.
ditto -c -k --sequesterRsrc --keepParent dist/Doclin.app dist/Doclin-0.2.0-mac.zip
```

Create the notary profile securely using Apple's tooling. Do not put passwords, API keys, or signing certificates in this repository. Increment both bundle version fields in `scripts/build.sh` for releases. Verify both architectures on actual target hardware; a successful cross-compile does not establish Intel runtime behavior.

The app is intentionally unsandboxed because it reads user-owned agent session files and installs user-level Claude hooks. It uses hardened runtime signing, audio-input and speech-recognition entitlements for opt-in dictation. It has no general keyboard monitor and no network listener. macOS permission approval is required for recording and Accessibility insertion.

## Installation and removal

Move the app to Applications before enabling Start at login. Login registration uses `SMAppService.mainApp`.

To remove Doclin: disconnect Claude in the app, disable Start at login, quit, and delete the app. Preferences and the copied helper are in `~/Library/Application Support/Doclin`. The Keychain item uses service `dev.doclin.app` and account `openai-api-key`; remove it in Voice & AI before uninstalling. Existing Claude configuration backups are named `settings.doclin-backup-<UUID>.json` next to Claude's settings.

The name and domain are working branding. Domain registration, trademark clearance, public hosting, paid signing, and publishing have not been performed.
