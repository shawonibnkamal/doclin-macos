#!/bin/bash
set -euo pipefail
# User-scoped code-signing trust only. No TLS trust or system trust changes.
SIGNING_ROOT="$HOME/Library/Application Support/Doclin/Signing"
echo 'macOS may require your authentication for this one-time local code-signing setup.'
security add-trusted-cert -r trustRoot -p codeSign \
    -k "$SIGNING_ROOT/doclin-signing.keychain-db" "$SIGNING_ROOT/certificate.pem"
