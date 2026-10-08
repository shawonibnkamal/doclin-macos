# Dictation quality — 0.4.6

## Behavior

- macOS 26+ supported hardware/languages use SpeechAnalyzer + SpeechTranscriber. Older Macs/unsupported locales retain the on-device SFSpeechRecognizer path.
- A prepared enhanced session waits without microphone capture. It is consumed only when dictation begins and replenished after completion/cancel.
- Apple speech assets can download once; audio is not uploaded in local mode. No cloud settings are automatically enabled.
- Results are assembled by audio range. Final ranges survive pauses, duplicate callbacks, and late provisional results. Release seals accepted audio before finalization; cancellation rejects later insertion.
- Enhanced startup failure falls back to existing Apple recognition when its existing permission is granted.
- Indicator is 184 × 38 points, with stop, seven level bars, timer, and cancel. It remains nonactivating, appears during the hold, and hides on release/cancel. Transcript/details remain in the app.

## Repeatable audio test

Run `scripts/dictation/benchmark.sh /absolute/path/manifest.json` on macOS 26. Manifest is a JSON array of `{ "id": "sample", "audio": "sample.aiff", "expected": "reference transcript" }`. Audio paths resolve relative to the manifest. The harness feeds each file through the same converter/stream and ModernDictation adapter at real-time speed. It never opens the microphone or sends data to a provider. Results are written to stdout; input audio is retained only where the caller supplied it.

Four synthetic English clips were generated locally with macOS Samantha at 175 words/minute, then replayed on this Apple silicon Mac. This is a synthetic pipeline check, not proof of performance on the user's accent, background noise, AirPods, or Wispr Flow.

| Clip | Session preparation | Release to final | Outcome |
| --- | ---: | ---: | --- |
| Ordinary request | 74 ms | 103 ms | Exact reference transcript |
| Product names | 37 ms | 147 ms | Doclin and Codex misrecognized |
| Negation and payment | 42 ms | 61 ms | Meaning retained; spoken dollars formatted as currency |
| Spoken correction | 36 ms | 55 ms | Minor recognition errors; filler/self-correction retained |

Preparation timings exclude microphone/device startup, shortcut delay, and destination-field capture. Finalization timings exclude cleanup and insertion. The harness reports raw word edit distance; it counts normal formatting differences such as “fifty dollars” versus “$50” as errors. Do not equate this with a semantic accuracy score.

## Remaining gaps

Recognition alone does not provide Wispr-style polishing. Rare product names still need improvement. The existing vocabulary hints are passed to the analyzer, but this sample demonstrates they are not sufficient for enhanced recognition. Cloud cleanup remains opt-in; Apple Intelligence is disabled on this Mac, so no local language-model polishing is claimed. No private recordings or paid API requests were used in this test.

## Verification

- 32 core checks and mocked cloud transcription/cleanup/TTS transports passed.
- Native capture checks: 100 concurrent append/close races, no buffers after release, idempotent close, and canceled queued startup passed.
- Independent review found and resolved early-release loss, missing startup fallback, warmed vocabulary invalidation, shutdown cleanup, and locale reservation exhaustion. Final review found no remaining actionable bugs.
- Universal arm64/x86_64 release build and deep strict signature verification passed; local candidate installed at `dist/Doclin.app`, version 0.4.6. Prior version ZIP retained.
- Native installed app reported enhanced streaming recognition ready. Microphone permission was renewed after its ad-hoc signature changed. In-app microphone startup measured 271 ms; cancel visibly stopped recording without inserting text.
- Native voice preview completed through the current AirPods output using Kokoro; the app marked the preview Spoken. This verifies generation/playback, not a subjective naturalness comparison.
- Preview-indicator action exercised in the native app. Its main-window screenshot excludes the separate floating panel, so a full visual screenshot of the panel is not claimed.
- Right Command and foreground insertion still await renewed macOS Accessibility permission for the current build. Existing System Settings entry is on but the app reports untrusted; old signature requirements remain stale. No physical dictation or Wispr comparison is claimed.
- Local privacy settings preserved: cloud transcription/cleanup remain off. No API key is configured in the installed app. The user was asked whether cloud processing is acceptable; no answer was received during this update.
