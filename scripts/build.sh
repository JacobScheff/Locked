#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

configuration="${1:-Debug}"
case "$configuration" in
    Debug|Release) ;;
    *) printf 'Usage: bash scripts/build.sh [Debug|Release]\n' >&2; exit 2 ;;
esac

if ! command -v xcodebuild >/dev/null 2>&1; then
    printf 'Building Locked requires macOS with Xcode 26.3 or newer.\n' >&2
    exit 1
fi

# Validate only versioned project files, never local build or user data.
git ls-files -z -- '*.plist' '*.entitlements' '*.pbxproj' | xargs -0 plutil -lint

xcodebuild \
    -project Locked.xcodeproj \
    -scheme Locked \
    -configuration "$configuration" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "build/$configuration" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build
