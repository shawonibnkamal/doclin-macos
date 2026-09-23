# Dictation latency — 0.4.2

The user's live confirmation established that 0.4.1 insertion worked, but both startup and release-to-text felt slow. There was no pre-existing phase timing, so no measured before/after speed claim is made.

Changes:
- Right Command activation delay reduced from 300 to 150 ms; chord cancellation remains.
- Audio device startup/stop moved from MainActor onto a serial user-initiated queue. Reuse the stopped engine and cached recognizer, with no recording while idle.
- Audio tap reduced from 1024 to 512 requested frames.
- Seal audio input and signal endAudio at release, concurrently with slow hardware stop. Appends and sealing share a lock. No partial transcript is promoted to final solely for speed; six-second error fallback remains.
- Canceled sessions close synchronously; queued startup checks closure before setup, prepare, start, and immediately afterward. Closed streams reject buffers.
- Accessibility reads use a 200 ms per-message bound and modifier-release waiting no longer repeatedly reads the full field. Final unchanged-target checks remain before any write.
- In-memory timing displayed for microphone-ready, release-to-final and cleanup/insertion. Timing excludes shortcut debounce; in-app mic tests omit external-field capture.

Contract: existing settings and offline provider remain; missing permissions fail visibly; cancel/late callbacks cannot insert; no added cloud calls, audio history, or idle recording. Previous 0.4.1 zip remains available for rollback; unsigned rebuilds may need their existing macOS permission entries refreshed.

Validation: universal arm64/x86_64 build; strict signature verification; 27 core and mocked cloud checks. Native checks passed 100 concurrent append/close races, idempotent endAudio, no buffers after close, and canceled queued startup skipped. Independent review caught and resolved queued-start cancellation before installation.

Native check command from repository root:

    swiftc Sources/Doclin/DictationCapture.swift Tests/NativeCaptureChecks/main.swift -o /tmp/doclin-capture-check
    /tmp/doclin-capture-check

Apple API reference: https://developer.apple.com/documentation/speech/sfspeechrecognizer/recognitiontask(with:resulthandler:)

Live installed-build verification: current app 0.4.2, renewed existing permissions, Right Command ready. Two real in-app microphone starts measured 254 ms first and 74 ms reused. Both were canceled without insertion. These samples exclude the 150 ms shortcut delay and external target capture and are not a pre/post benchmark. Spoken release-to-final transcription and rapid-release final-syllable accuracy were not measured; user-visible timing now makes those diagnosable on the next actual dictation. No foreground Codex UI automation attempted because that surface is blocked.
