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


## 0.4.7 candidate — selectable voices and local signing

- Added Bella (2), Michael (16), and Isabella (22); retained Heart (3). IDs match the pinned model's upstream speaker map. No new models or cloud processing.
- Generated four non-silent, distinct WAVs from one public sentence. Audio duration: 4.78–5.42 seconds. Cold generation: 5.5–6.85 seconds. No latency improvement is claimed.
- Invalid speakers (-1, 99, abc, 2x) fail before synthesis.
- Synthesis adds sentence-ending punctuation without rewriting content.
- A failed chosen local voice keeps the update in Activity instead of silently switching to a Mac voice. Explicit Mac selections remain available.
- Universal preview built separately; installed bundle untouched. 33 core checks, mocked cloud transports, signature verification, and independent review passed.
- Bella becomes the default for old automatic voice settings; explicit Heart/Mac selections are preserved and tested. Native UI candidate uses isolated QA preferences outside the repo with announcement sources disabled. Bella picker and real preview invoked; outcome recorded separately.
- Persistent local certificate/key created in a private dedicated encrypted Keychain outside the repo. Trust request is user-scoped to code signing only; an initial application-constrained trust attempt did not produce a usable signing identity. macOS authentication remains pending; signed cross-build identity retention is unverified. Scripts do not add system-wide or TLS trust.

- Native candidate preview completed through MacBook Pro Speakers and was marked Spoken with Bella. Temporarily making only the QA helper non-executable produced Voice unavailable, retained the update in Activity, and did not start a Mac voice; helper permissions restored and signature reverified. The status badge was corrected to show Unavailable for a missing chosen neural voice.
