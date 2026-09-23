# Audio output repair — 0.3.3

Observed: regular media output was AirPods Pro while the default system-sound output was MacBook Pro Speakers. Previous code left AVAudioPlayer routing implicit and called AVSpeechSynthesizer.speak directly for fallback. A prior check of the system default alone did not establish actual app output.

All audio now uses a player explicitly configured with the current regular output device UID from Core Audio. Configuration is verified after prepareToPlay and the default is checked again before play. Mac fallback is rendered into private scratch audio and uses the same player path. Device-change notification cancels the current announcement and clears queued speech. Failed playback is no longer labeled Spoken.

Verified on this Mac: explicit player configuration selects AirPods; rendered Mac fallback and silent playback both retain AirPods UID. Native v0.3.3 Voice & AI screen shows AirPods. User's paused preference preserved; no audible test or output-device switching performed. Disconnect race behavior reviewed in code, not physically tested. Universal package and strict signature checks pass.

Independent review caught double-applied Mac fallback volume; rendering now uses volume 1 and volume preference is applied only by the player. Ticket guards and scratch cleanup reviewed without further blockers.
