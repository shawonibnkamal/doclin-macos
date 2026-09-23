# 0.4.4 — Smooth dictation indicator

Right Command arms the nonactivating pill immediately. The existing 150 ms chord guard still gates microphone capture; quick taps and Command chords dismiss the pill without a start cue or capture. The pill stays the same size during startup/recording. Finish, release, cancel, and final resolution hide it before status changes; permission polling and the four-second status reset cannot reopen it. Main-window status/transcript remain available after processing.

A quiet generated 70 ms start cue plays only after microphone startup succeeds, on the selected media output. It can be disabled in Dictation settings. Cancellation and output changes stop it. No new network/model/API dependency.

Review fixed disarm events incorrectly hiding button-started recordings and dismissing an armed pill without canceling its pending activation. Indicator ownership now limits disarm to a real right-Command hold; dismiss cancels pending activation and requires key release before rearming.

Universal build and existing core/cloud checks passed. Native UI checks and physical shortcut limitations are recorded below.

Installed 0.4.4. Native preview visibly showed one Listening panel and disappeared after its preview interval; no processing/result panel was shown. Current Accessibility entry refreshed and shortcut reports ready. Microphone and Speech authorization requested for rebuilt binary; system approval prompts cannot be automated. Physical key hold and audible startup cue are not yet verified in this build.
