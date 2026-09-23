# Preview verification

Build: Doclin 0.1.0, September 7, 2026.

## Automated checks

Run `swift run DoclinChecks` from this directory. The current suite has 20 core checks plus mocked cloud transport checks. Coverage includes:

- Duplicate completions, newest-per-task queueing, new-turn cancellation, delayed stale events, queue expiry and size limits.
- Markdown/code/URL cleanup, a spoken word cap, and preserving a failed result in local excerpts.
- Observed Codex desktop event shapes, child-agent exclusion, unknown timestamps, and ignored tool outputs.
- Actual incremental file watching: fresh start/completion delivery without replaying existing history; partial JSON line buffering.
- Claude event normalization, preserved unrelated settings, idempotent hook setup/removal, malformed-settings refusal, and shell-safe helper paths.
- Producer retention: no message collection while Doclin is closed, paused, disabled, or has a stale heartbeat.
- Preference persistence.
- OpenAI request serialization, explicit `store: false`, response parsing, HTTP 401 handling, and speech endpoint routing using a mock transport. No real API key or paid provider call was used.

## Native app checks

The packaged app was launched and inspected through its native accessibility tree and screenshots on the build Mac.

- Activity, Connections, Voice & AI layouts rendered correctly.
- Voice preview reached `Spoken` through the native speech completion callback.
- A native Claude hook fixture reached the app and reached `Spoken`.
- A same-session `UserPromptSubmit` after playback began changed the item to `New message` and stopped that announcement.
- Pause changed the visible state; preview was refused while paused; resume restored listening.
- Normal Command-Q quit removed the heartbeat, and a native hook invoked afterward collected no payload.
- Heartbeat stayed fresh while a native menu was held open for more than six seconds.
- Claude hook installation succeeded. Removing only Doclin's additions from the resulting JSON produced the exact canonical hash of the original settings. Existing hooks were preserved.
- The live Codex adapter attached to recent user sessions without replaying historical completions.

## Review fixes

An independent review identified inactive-app hook retention, restored expiry initialization, and heartbeat starvation during menu tracking. These were fixed with live-process/heartbeat gating, producer cleanup, preference initialization, and a common-mode heartbeat timer. Playback status was also corrected after interruption.

## Limits of this verification

- The universal executable is cross-built for Apple silicon and Intel. Runtime QA here covers the build Mac only; a clean Intel Mac has not been tested.
- Native playback callbacks confirm that macOS completed playback. Speaker audibility and subjective voice quality were not independently recorded.
- The Claude hook was exercised with a controlled payload; existing Claude sessions need restarting to load newly installed hooks.
- Codex's actual session event format and attachment were verified. A controlled fresh-file integration test covers completion delivery; this document does not claim a second real Codex task was launched for QA.
- AI summary and voice APIs are implemented and mock-tested, but require the user's own API key for live provider verification.
- No Developer ID signing identity is installed on this Mac. The preview is ad-hoc signed, not notarized. Public download/clean-machine Gatekeeper QA remains a release milestone.
