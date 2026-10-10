# Doclin 0.4.21 — Custom-word dictation

On macOS 26, dictation now uses Apple’s vocabulary-aware DictationTranscriber. Custom words are passed to its on-device analysis context. A generated-audio recognition check correctly transcribed Doclin, Codex and Claude; hints improve recognition but do not guarantee every pronunciation. Older macOS versions keep the existing on-device recognizer with vocabulary hints.

Also includes the cyan recording indicator and a more responsive microphone meter. Spoken updates still stop when dictation begins.

Universal macOS 13+ development-signed preview, not Apple notarized. Website traffic analytics are separate from the Mac app, which has no telemetry.
