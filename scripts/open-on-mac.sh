#!/usr/bin/env bash
# Run on a Mac: opens the Xcode project (fallback to Package.swift)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -d "$ROOT/eDrop.xcodeproj" ]]; then
  open "$ROOT/eDrop.xcodeproj"
elif [[ -d "$ROOT/EyedropTranslate.xcodeproj" ]]; then
  open "$ROOT/EyedropTranslate.xcodeproj"
else
  open "$ROOT/Package.swift"
fi
