#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
swift build --product DoclinChecks >/dev/null
BIN="$(swift build --show-bin-path)"
swiftc -parse-as-library -I "$BIN/Modules" "$BIN"/DoclinCore.build/*.swift.o Sources/Doclin/DictationCapture.swift Sources/Doclin/ModernDictation.swift scripts/dictation/benchmark.swift -o "$BIN/dictation-benchmark"
"$BIN/dictation-benchmark" "$1"
