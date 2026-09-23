## 0.4.5 — Preserve dictation across pauses

Completed speech phrases are accumulated instead of being overwritten by the latest hypothesis. Active-phrase corrections, duplicate callbacks and cumulative results are reconciled. See TRANSCRIPT-QA.md.

## 0.4.4 — Immediate indicator and clean dismissal

Right Command shows the pill immediately; a short sound confirms microphone readiness. Releasing/canceling hides the pill immediately while text finishes in the background, without cycling through completion states. The sound is optional and uses the selected media output. See DICTATION-INDICATOR-QA.md.

## 0.4.3 — Announcements without folder names

Spoken updates now start directly with the result. Local excerpts no longer prepend project or source names; optional AI summaries are instructed to omit identifying prefixes and no longer receive project metadata. Activity retains its visual project label. Universal build, 27 core checks and mocked cloud checks passed; independent review found no missed prefix. Installed preview generated “The missing stage labels are fixed” with no folder prefix.

## 0.4.2 — Faster dictation startup

Audio setup runs off the UI thread and reuses the stopped engine. Right Command starts after 150 ms, and final recognition runs alongside hardware shutdown. Two in-app microphone starts measured 254 ms and 74 ms (excluding shortcut/field capture). Release-to-text timing is now shown in Dictation; a spoken end-to-end speedup is not yet measured. See DICTATION-LATENCY-QA.md.

## 0.4.1 — Insertion at your cursor

Clipboard-enabled dictation now uses normal Paste and checks the actual field before reporting success. Click your input, hold Right Command, speak, then release to insert the finished transcript. Dictation settings also include an eight-second insertion diagnostic for an empty external field. See INSERTION-QA.md for verification and remaining limits.

# Dictation UI update — 0.4.0

Dictation now has a persistent floating pill: setup guidance before recording, a microphone waveform and live text while listening, a processing state, and explicit insertion/copy/error results. Click the microphone to start, click stop to finish, or hold and release Right Command. The panel preserves the destination app's focus. Dictation settings include a clearly labeled UI-only preview and a toggle to hide/show the pill.

When permissions are missing, the pill identifies the next setup step rather than leaving an unresponsive shortcut. It refreshes permission status automatically. Local transcription displays partial text; cloud transcription appears after recording finishes.

# Doclin 0.3 — natural voice built in

The default notification voice is now Kokoro af_heart, running locally inside the app. No API key, subscription, Python, or additional installation is needed. Updates default to 15 words, normal speaking speed, and 55% volume. Right Command remains the dictation shortcut.

The bundle contains the voice model and a separate native speech helper. Text passes privately through stdin; temporary audio is deleted. Cancellation stops synthesis, and generation checks reject late results. Mac speech is the fallback for missing/failed/timed-out synthesis. Explicit Mac voice selections and optional OpenAI speech are still available.

Apple silicon: macOS 13+. Intel: built-in Kokoro requires macOS 15.5+; older supported Macs use Apple speech. The app is still a locally signed preview; Developer ID signing and notarization are needed for smooth public distribution.

See vendor/voice/README.md for pinned runtime/model provenance, licenses, and corresponding source archives.

---

# Doclin

A native Mac menu-bar app that speaks one short update when Codex or Claude Code finishes a response. Working brand: **doclin.dev**.

## Run the preview

1. Unzip `dist/Doclin-0.2.0-mac.zip` and move **Doclin.app** into Applications.
2. Open Doclin. It lives in the menu bar; closing the window keeps announcements running.
3. Click **Preview voice** to hear the local voice.
4. Codex desktop and CLI sessions in `~/.codex/sessions` are observed automatically. Only new events are announced; historical completions are skipped.
5. In **Connections**, click **Connect Claude Code**, then restart existing Claude Code sessions. This adds only Doclin's two hooks and preserves other settings. Disconnect removes only Doclin hooks.
6. Keep Wispr Flow for dictation. If you also run Heard, pause its speech to avoid duplicate announcements.

No API key is needed. Local mode reads a short excerpt; it does not pretend to intelligently summarize long responses. For AI summaries and/or AI-generated speech, save your own OpenAI API key in **Voice & AI**, then enable the desired switches. Keys are stored in macOS Keychain, never in configuration or the app bundle.

This preview is ad-hoc signed. It is **not yet notarized**. Another Mac may require approval in System Settings → Privacy & Security. Public distribution should use a Developer ID signed and notarized build; see [PACKAGING.md](PACKAGING.md).

## What is implemented

- Native SwiftUI window and menu-bar controls; no Electron, Python, Node, or runtime dependency for recipients.
- Codex desktop/CLI completion and new-turn detection from local session lifecycle records.
- Claude Code `Stop` / `UserPromptSubmit` integration through a bundled native helper.
- Mac speech with voice, volume, and speed controls.
- Optional GPT-4o mini summaries and GPT-4o mini TTS voice, directly through OpenAI.
- A configurable 15–25 word cap; one speaker at a time; newest pending update per task.
- Cancellation when a new turn begins, old queue expiry, bounded queue and history, duplicate suppression, subagent filtering.
- Pause, stop, preview, excluded project folders, and macOS login-item registration.
- Offline defaults, network failure fallback, and no telemetry.

## Build and check

Requires macOS with Swift 5.9+ / Command Line Tools. There are no third-party packages.

```sh
swift run DoclinChecks
./scripts/build.sh
# Optional: build both Apple silicon and Intel slices
UNIVERSAL=1 ./scripts/build.sh
open dist/Doclin.app
```

The test executable deliberately uses a tiny assertion harness so it runs on Command Line Tools installations without XCTest. It checks observable behavior, not UI snapshots. Build outputs are ignored by source control.

## Architecture

`DoclinCore` owns normalized events, queue policy, Codex JSONL parsing/tailing, hook installation, preferences, and the optional OpenAI client. `Doclin` owns AppKit lifecycle, SwiftUI, AVFoundation playback, Keychain, and login items.

Flow: agent completion → normalized event → deduplicate/expire → one-sentence summary or local excerpt → serial speech. A new prompt invalidates pending summary requests and stops playback for that task. Other tasks retain their queued updates.

Codex session files are an internal format, not a guaranteed API. The adapter recognizes explicit lifecycle records observed in Codex desktop on September 7, 2026. Unknown records are ignored. The supported Codex CLI notify payload is also accepted by the helper, but the default setup uses the file watcher to receive cancellation events too.

The helper writes bounded JSON messages atomically into `~/Library/Application Support/Doclin/inbox`. The app consumes and deletes them. The helper drops events while Doclin is closed or paused, and removes stale files. A crash or quit/write race can leave a private file until the next hook invocation or app launch. No local HTTP port is exposed. Claude hook commands always exit successfully and do not write agent-facing output. The helper is copied into Application Support, so moving the app does not break hook paths.

## Privacy and retention

- Local mode makes no network requests. The announcement feature does not record the microphone or intercept keystrokes. Optional dictation needs Microphone and, for insertion, Accessibility access.
- The reader inspects local lifecycle records and final responses; it does not upload transcripts or tool logs.
- Local hook payloads are transient files in a user-private folder. Recent announcements remain only in memory.
- Enabling AI summaries sends the project folder name, at most 600 characters of task context, and at most 8,000 characters of the final response to OpenAI. These may contain sensitive project information. Enabling AI voice sends the spoken sentence.
- OpenAI Responses requests set `store: false`; OpenAI's API data policies still apply. This does not claim zero retention by OpenAI.
- API failures fall back to a local excerpt/voice. Canceled requests may already have reached OpenAI and may still incur charges.
- No Doclin service, account, analytics, or subscription.

## Next distribution milestones

1. Test the preview on other Macs and Codex/Claude versions.
2. Add versioned adapter fixtures and diagnostics for unsupported session formats.
3. Sign with Developer ID, notarize, and test a quarantined download on a clean Mac.
4. Add an update mechanism and publish downloads at the chosen domain when authorized.

Voice dictation is available in 0.2. Agent reply routing, automatic sending, and complete Wispr Flow feature parity are outside this version.

## Dictation (0.2)

Open **Dictation** and turn on **Enable dictation**. Allow Microphone and, for local mode, Speech Recognition. Allow Accessibility if you want automatic insertion into another app. Without Accessibility you can still dictate into Doclin and copy the transcript.

Default shortcut: hold **Right Command** for 0.3 seconds, speak, then release. Quick taps are ignored; pressing another key cancels dictation so normal Command shortcuts remain available. Right Command requires Accessibility permission and passively observes modifier/key-down events without reading or storing typed text. Alternative key combinations use Carbon hotkey registration. A floating indicator shows recording state, elapsed time, and microphone level. Click Cancel to discard a recording. Recordings are limited to 55 seconds locally or 90 seconds with OpenAI; sleep and quit cancel capture.

Local recognition explicitly requires Apple's on-device support for the selected language and never silently falls back to Apple's servers. If the language is unavailable, choose another or select OpenAI transcription. Cloud transcription uses `gpt-4o-mini-transcribe` with the saved API key. Optional cleanup uses `gpt-4o-mini` with `store: false`, preserves the original transcript, and is off by default. Accuracy and cleanup fidelity vary; review important names and meaning before sending.

Automatic insertion requires the original app, focused field, field contents, and text selection to remain unchanged. Password fields and fields without readable snapshots are excluded. Direct Accessibility insertion is attempted first. Optional clipboard fallback requests Paste and leaves the transcript on the clipboard; it never restores potentially unrelated clipboard text on a timer. If insertion is unavailable or focus changed, the text remains in Doclin for manual copying. No Return or Send action is performed.

On-device audio is not written by Doclin. OpenAI-mode audio is briefly saved as a private M4A, read into memory for upload, then deleted. Cancellation removes pending files; crash leftovers are removed at next launch. Dictation transcripts are held only in memory until cleared or quit. Optional cleanup sends the transcript to OpenAI; cloud transcription sends the recording, language hint, and vocabulary. Announcements pause during recording and processing so Doclin does not dictate its own voice.
