# Source checkout setup

Builds no longer require access to a private voice-dependency release.
From the repository root, run:

```sh
python3 scripts/voice/fetch.py
swift run DoclinChecks
SIGN_IDENTITY=- ./scripts/build.sh
```

The dependency script downloads pinned public upstream archives, verifies
checksums, and builds universal voice runtime libraries. See [README](README.md)
and [packaging](PACKAGING.md) for local permissions and public distribution.

Never add API keys, signing identities, generated app bundles, personal session
files or model weights to Git. Model/runtime dependencies are downloaded during
build setup; their notices and source archives are preserved in packaged apps.
