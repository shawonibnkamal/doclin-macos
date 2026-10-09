# Doclin 0.4.13 — Faster tab rendering

The app header uses a cached 96-pixel logo instead of repeatedly decoding the original 7,400-pixel artwork. Closed Settings sections no longer construct hidden controls or query system voices; the voice catalog is cached after first use. Unchanged permission polling results no longer trigger redraws. Layout and click targets stay unchanged.

Validation: main-thread sampling during real tab switches before and after, native navigation and Settings controls, universal signed build and strict signature verification, core/cloud checks. Dictation remains paused on the installed Mac. Development-signed preview, not notarized.
