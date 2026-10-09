# Doclin 0.4.13 — Responsive controls

The whole settings header now expands on one click, with consistent 44-point targets, hover/pressed feedback, and separate child controls. Doclin accepts the first click when its window is in the background. Full-width tab targets remain.

The header caches a 96-pixel logo instead of repeatedly decoding the original 7,400-pixel artwork. Closed sections no longer construct hidden controls or query voices, and unchanged permission polling does not trigger redraws.

Verification: native tab/row/nested-control audit, disabled controls and persisted switches, before/after main-thread sampling, universal build and strict signature validation, core/cloud checks and independent review. Dictation remains paused on the installed Mac. Development-signed preview, not notarized.
