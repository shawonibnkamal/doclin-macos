# Doclin 0.4.1 insertion repair

The prior app showed "Inserted into ChatGPT" for the user's transcript even though the user reported an empty destination. Direct Accessibility selected-text writes were trusted without readback.

Clipboard-enabled insertion now uses the editor's standard Paste handling, waits for modifier release, and verifies the destination's complete text matches replacement at the captured UTF-16 caret/selection. Direct insertion also requires readback. Dispatched writes are never retried, preventing duplicate text in slow editors. Focus, original value, selection and cancellation are checked before dispatch. No Return or Send is pressed.

The insertion diagnostic uses the same code path and only accepts an empty external field after its explicit eight-second countdown. Nonempty fields are rejected before clipboard or text modification. Cancellation after insertion begins tells the user to check their destination instead of claiming no text was inserted.

Independent review found and resolved diagnostic nonempty-target and cancellation-wording issues. Universal arm64/x86_64 release build and strict signature verification passed. 27 core checks and mocked cloud transport checks passed.

Installed current 0.4.1 at outputs/Doclin/dist/Doclin.app. Re-registered only Doclin's stale Accessibility entry through System Settings; current app reports Microphone, Speech Recognition and Accessibility Allowed, Right Command ready, and clipboard insertion enabled.

Live diagnostic starts its countdown and safely skips when no eligible empty foreground field is found. CUA controls TextEdit in the background, while NSWorkspace identifies com.openai.codex as the foreground app. Raising the TextEdit window through the exposed AX action did not change the foreground app. CUA explicitly refuses access to com.openai.codex, so no alternate UI automation was used. End-to-end foreground insertion and physical Right Command hold remain unverified by automation; do not claim successful live insertion from this test.
