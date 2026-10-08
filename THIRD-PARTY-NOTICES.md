# Third-party components

The Swift application and original supporting scripts are MIT licensed. This
does not relicense the bundled speech components or Apple's system frameworks.

| Component | License | Included notice/source |
| --- | --- | --- |
| Kokoro v1.0 int8 model | Apache-2.0 | `vendor/voice/model/LICENSE` after dependency setup |
| sherpa-onnx v1.13.7 | Apache-2.0 | `vendor/voice/SHERPA-LICENSE`, pinned source archive |
| ONNX Runtime | MIT | `vendor/voice/ONNXRUNTIME-LICENSE`, `ONNXRUNTIME-NOTICES.txt` |
| eSpeak NG | GPL-3.0 | `vendor/voice/ESPEAK-COPYING`, pinned source archive |
| piper-phonemize | MIT | `vendor/voice/PIPER-LICENSE`, pinned source archive |
| Doclin's separate `doclin-voice` helper | GPL-3.0-or-later | `scripts/voice/main.c`, `vendor/voice/ESPEAK-COPYING` |

The voice helper uses the GPL-linked speech runtime. The app invokes the helper
as a separate process through stdin and a WAV file. Preserve all notices and
corresponding source archives when distributing packaged speech components.
The packaging script includes these in `Contents/Resources/ThirdParty`.
See [voice provenance](vendor/voice/README.md) for versions and build references.
