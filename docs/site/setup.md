# Build and set up Doclin

The Mac app is available as an early source preview. It requires macOS,
Python 3 for dependency setup, and a current Apple development toolchain with
the macOS 26 SDK. Enhanced recognition needs supported macOS 26 hardware and
language; older systems use Apple's on-device recognizer.

```sh
git clone https://github.com/shawonibnkamal/doclin-macos.git
cd doclin-macos
python3 scripts/voice/fetch.py
swift run DoclinChecks
SIGN_IDENTITY=- ./scripts/build.sh
open .build/preview-dist/Doclin.app
```

The dependency script downloads pinned public speech components and checks
their hashes. Python is not needed to run a packaged app.

## Start dictating

1. Open **Dictation** and enable dictation.
2. Allow Microphone access. Allow Accessibility for Right Command and insertion,
   then click Refresh. The older recognizer also needs Speech Recognition access.
3. Focus a text field, hold **Right Command**, speak, and release.
4. If the destination did not accept your words, copy the transcript from Doclin.

You can dictate into Doclin and copy manually without Accessibility. Alternative
shortcuts are available if another dictation app uses Right Command. The enhanced
recording limit is five minutes; legacy local recognition is limited to 55 seconds.

## Listen to your agents

Codex session files are observed locally; only fresh completions are announced.
Connect Claude Code in **Connections** to add Doclin's marked hooks. Existing
sessions may need restarting. Pause other narration apps to avoid duplicates.

Local voices can sound robotic. Try the available Kokoro or macOS voices in
**Voice & AI**. On Intel Macs older than macOS 15.5, choose a macOS voice.
Optional OpenAI speech sends spoken text to OpenAI and requires your own API key.

## Preview limitations

Public signed/notarized downloads are not available yet. Ad-hoc rebuilds can
invalidate previous macOS permission grants. Keep daily use on a stable signed
build. Actual Intel playback and clean-Mac installation need further testing.

[Full packaging instructions](https://github.com/shawonibnkamal/doclin-macos/blob/main/PACKAGING.md)
