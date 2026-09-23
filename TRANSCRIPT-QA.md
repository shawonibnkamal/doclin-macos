# 0.4.5 transcript retention

Observed code unconditionally replaced partial with bestTranscription.formattedString on every callback. This can discard earlier utterances when a subsequent result contains only the current phrase. The user reported a long dictation inserting only its final two words; no historical audio or callback trace exists to prove the exact sequence or recover lost speech.

TranscriptBuffer preserves completed utterances, revises the active hypothesis, uses metadata/timestamps to distinguish utterances, and rebases cumulative results only with evidence covering the buffered transcript or the original speech timestamp. Final callbacks are marked complete even without metadata. One buffer is created per recognition task; existing lifecycle cancellation and insertion guards remain.

31 core checks plus mocked cloud checks pass, including four new regression scenarios: pauses and final-only short tail; active corrections/cumulative updates; duplicate metadata-less callbacks/cumulative finals; intentional repetition of an earlier phrase without erasing history. Independent review found and resolved two duplication cases and a prefix-repetition data-loss case. Universal build and strict signatures pass.

0.4.5 installed. Existing Accessibility permission refresh is awaiting macOS Touch ID approval. Long physical dictation and foreground insertion are not yet verified on this build. No new cloud calls or retained recordings.
