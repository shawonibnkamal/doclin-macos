# Dictation preview verification — 0.2.1

## Implemented

- Right Command hold with 300ms activation, quick-tap suppression, chord cancellation, and passive event monitoring requiring Accessibility. Alternative shortcuts use Carbon.
- Optional local, strictly on-device Apple speech recognition with live partial text and microphone level.
- Optional OpenAI transcription and filler/punctuation cleanup using the existing Keychain key.
- Non-activating floating recording indicator, cancel, timeout, and sleep/quit cleanup.
- Speech announcement suppression during dictation and processing.
- Original-field insertion with focus, contents, selection, and secure-field guards.
- Explicit optional clipboard paste fallback. Leaves the transcript on the clipboard rather than racing a delayed paste by restoring old content.
- Editable last transcript, original-text restore, manual copy, vocabulary and language settings.

## Passed

- 27 core checks plus mocked cloud transport checks.
- Existing announcement/Claude settings preservation regression checks.
- New dictation tests: no overlapping recordings, one completion only, late-callback rejection after cancellation, no summary-style truncation of dictation, preservation of URLs/code/paragraphs, cleanup omission/number checks, binary multipart body construction, and separate offline-default preferences.
- Mocked API checks: transcription endpoint/model/content type, multiline transcript decoding, 401 failure, successful cleanup, and incomplete-cleanup refusal.
- Independent adversarial review and follow-up review. Findings about timed clipboard restoration, missing field snapshots, and canceled asynchronous jobs were fixed.
- Universal Apple silicon + Intel build; strict local code-signature validation.
- Native UI: Dictation screen rendered, previous Carbon shortcut registered successfully; v0.2.1 Right Command selection and Accessibility-required state verified in the native app, permission state correctly reported, and on-device English availability detected.

## Live verification boundary

Microphone, Speech Recognition, and Accessibility must be granted by the user in macOS. At packaging time, the live microphone-to-text and cross-app insertion checks are pending those grants. Mocked transport checks are not a live OpenAI transcription or accuracy measurement. No paid API requests were made.

The app remains ad-hoc signed and unnotarized. Rebuilding with an ad-hoc signature may require renewed macOS permission approval; a stable Developer ID release is the distribution milestone.

Right Command review boundary: deterministic shortcut tests pass. Independent modifier review found unregister could lose a release callback; unregister now cancels an active hold before removing monitors. Physical-key recognition still awaits Accessibility permission.
