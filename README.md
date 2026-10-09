<p align="center"><img src="docs/assets/doclin-logo.png" width="112" alt="Doclin logo"></p>

# Doclin

Local dictation and spoken updates for your Mac. Hold Right Command, speak,
then release to put words into the field you were using. A small pill shows
recording activity. Doclin can also read short updates from Codex and Claude Code.

**Dictation stays on your Mac by default. No Doclin account, subscription,
telemetry, or hosted service.** Optional OpenAI features send selected audio or
text only when you enable them. See [Privacy](PRIVACY.md).

Doclin is an early preview. We do not claim better accuracy than Wispr Flow.
Names, spoken corrections, and insertion into some editors still need work.
See [dictation checks and limitations](DICTATION-QUALITY-QA.md).

## Download for Mac

[Download Doclin 0.4.16](https://github.com/shawonibnkamal/doclin-macos/releases/download/v0.4.16/Doclin-0.4.16-mac.zip).
Unzip, move Doclin.app to Applications, and enable dictation on the Dictation page. Allow Microphone
and Accessibility, then hold Right Command in a text field to speak.

This is a certificate-backed preview without Apple notarization. macOS may
block opening it. Review the blocked app in System Settings → Privacy & Security;
do not disable Gatekeeper. Clean-Mac installation remains unverified.

## Build from source

Requires macOS, Python 3 for dependency setup, and Apple's Command Line Tools.
Use a current Xcode toolchain/macOS 26 SDK to compile enhanced transcription.
The app targets macOS 13+. Enhanced dictation requires supported macOS 26
hardware and language; earlier systems use Apple's on-device recognizer.
Bundled neural speech on Intel requires macOS 15.5+.

```sh
python3 scripts/voice/fetch.py
swift run DoclinChecks
SIGN_IDENTITY=- ./scripts/build.sh
open .build/preview-dist/Doclin.app
```

Dependency setup downloads pinned public speech runtimes, a model, and their
source archives. It verifies SHA-256 checksums. These files are excluded from
Git. Python is not needed by people running a packaged app.

The source build is an ad-hoc preview. Rebuilding it can invalidate macOS
permission grants. Keep daily use on a stable certificate-backed build; see
[packaging and signing](PACKAGING.md). The downloadable preview is not notarized. Do not disable Gatekeeper to install Doclin.

## Use dictation

1. Open **Dictation**, enable dictation, and grant Microphone access under **Settings → Troubleshooting**.
2. Grant Accessibility for Right Command and automatic insertion, then Refresh.
   The older recognizer also needs Speech Recognition permission.
3. Focus a text field, hold **Right Command**, speak, then release.
4. If the destination changes or insertion fails, copy the retained transcript
   from Doclin. Doclin never presses Send or Return.

You can also start from Doclin and copy manually without Accessibility.
Alternative shortcuts are available if another dictation app uses Right Command.
The recording limit is five minutes with enhanced recognition, 55 seconds with
legacy local recognition, and 90 seconds with optional OpenAI transcription.

The Dictation and Agent updates tabs list the last 30 entries from this session.
Copy or edit dictated text there. Histories stay in memory and clear on quit.
Settings uses a category sidebar with aligned rows for configuration, permissions, connections, and voice previews. Enabled toggles stay on the main Dictation and Agent updates pages.

## Spoken agent updates

Codex desktop/CLI session files are observed locally. Only fresh completions
are announced. Connect Claude Code in **Settings → Agents** to add Doclin's two
hooks; unrelated hooks and settings are preserved. Existing sessions may need
restarting. Pause other narration apps to avoid duplicate speech.

Local updates use short excerpts, not AI-written summaries. Kokoro voices run
inside the app; macOS voices are selectable. Voice quality is subjective and
the current local voices may sound robotic. OpenAI summaries and speech are
optional and require your own API key, stored in macOS Keychain.

## Development

`DoclinCore` owns event parsing, queue policy, preferences, integration hooks,
and opt-in cloud requests. `Doclin` owns the native UI, audio, permissions,
transcription, and insertion. No local network listener is exposed.

```sh
swift run DoclinChecks
# Build both architectures; Intel runtime still needs actual hardware testing.
UNIVERSAL=1 SIGN_IDENTITY=- ./scripts/build.sh
```

Codex session files are an internal format and may change. Unknown records are
ignored. A successful build does not prove real dictation quality or insertion
in every app. See the checked-in QA documents for measured scope.

## License

The main app is [MIT licensed](LICENSE). Bundled components retain their own
licenses, and the separate GPL-linked voice helper is GPL-3.0-or-later.
See [third-party notices](THIRD-PARTY-NOTICES.md).
