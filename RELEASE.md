# Open-source preview release

Doclin provides local dictation and spoken agent updates on macOS. Local-mode
recordings stay on the user's Mac. Optional OpenAI transcription, cleanup,
summary and speech explicitly send selected content to OpenAI.

The main app is MIT licensed; bundled components retain their own licenses.
The separate voice helper is GPL-3.0-or-later. This is a source preview, not a
notarized binary release. Build/setup instructions are in README.md.

Release preparation verified a dependency-restored source checkout, SHA-256
checks for downloaded archives and model/source/header files, 33 core checks
plus mocked cloud checks, and universal packaging. Actual Intel hardware,
clean-Mac installation, broad editor insertion, and accuracy parity with other
dictation products remain unverified. No claim of Wispr Flow superiority is made.

Public binary downloads require Developer ID signing, notarization and a clean
Mac download test. Private signing credentials and runtime user data are excluded
from the source release.
