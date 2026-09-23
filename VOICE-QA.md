# Local voice verification — 0.3.0

- Real Kokoro int8 af_heart synthesis succeeded on Apple silicon: 4.94 seconds of audio generated in 6.69 seconds including cold process/model startup.
- Actual LocalVoice process wrapper: successful RIFF output, 100 early helper exits, cancellation of a running helper, and empty scratch directory after each run.
- Fixed independent review finding: after a successful process launch only terminationHandler owns continuation completion, even if the helper exits before stdin writing completes.
- Worker generation checks run after synthesis and before playback; canceled, expired, muted, and superseded events cannot play late.
- Helper has a 15-second timeout and forced termination after 2 more seconds if needed. Mac speech fallback remains available.
- Universal app/helper/dylib compilation and strict code-signature validation.
- Intel runtime minimum verified from Mach-O metadata; Intel before macOS 15.5 is explicitly routed to Apple speech. Intel execution not tested on this Apple silicon host.
- No paid API calls made. Microphone dictation still requires macOS permissions and is separate from this TTS change.

Packaged helper signing failure was reproduced (ad-hoc Team ID mismatch), then fixed: the ad-hoc helper is signed without hardened library validation; Developer ID builds keep it hardened. Main app remains hardened, with explicit nested signing and no recursive re-signing. Real packaged-helper synthesis then passed in 4.16 seconds.
