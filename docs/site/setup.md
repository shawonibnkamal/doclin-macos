# Install Doclin

[Download Doclin for Mac](https://github.com/shawonibnkamal/doclin-macos/releases/download/v0.4.15/Doclin-0.4.15-mac.zip).

1. Unzip the download and move **Doclin.app** to Applications.
2. Open **Settings → Dictation** and enable dictation.
3. Allow Microphone and Accessibility when prompted, then click **Refresh**.
4. Focus a text field, hold Right Command, speak, and release.

This is a preview build without Apple notarization. macOS may block opening it.
Use System Settings → Privacy & Security to review the blocked app. Do not
turn off Gatekeeper. Build from source if you prefer to inspect it first.

## Requirements

macOS 13 or later. Enhanced local recognition requires supported macOS 26
hardware and language. Earlier systems use Apple's on-device recognizer and
may need Speech Recognition permission. Intel Macs older than macOS 15.5 should
choose a macOS voice under **Settings → Voice**.

## If words do not appear

Check the transcript in Doclin and copy it. Under **Settings → Dictation → Troubleshooting**,
refresh permissions or run the insertion check. Review names, numbers, and
meaning before sending. Doclin never presses Send or Return.

## Build from source

```sh
git clone https://github.com/shawonibnkamal/doclin-macos.git
cd doclin-macos
python3 scripts/voice/fetch.py
swift run DoclinChecks
SIGN_IDENTITY=- ./scripts/build.sh
open .build/preview-dist/Doclin.app
```

Use a current Apple development toolchain with the macOS 26 SDK. Python 3 is
needed for dependency setup, not to run the packaged app. Ad-hoc source rebuilds
can require permission renewal.
