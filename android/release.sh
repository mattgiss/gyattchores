#!/bin/bash
# Build the Android app and publish it as a GitHub release, so phones running
# Obtainium (pointed at this repo) pick it up as an update.
#
#   ./release.sh 0.4.0 "What changed, in a sentence or two."
#
# Must run on the Mac that built the installed copies: updates only install if
# they are signed with the same key (currently ~/.android/debug.keystore).
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:?usage: ./release.sh <version, e.g. 0.4.0> \"notes\"}"
NOTES="${2:-Android build $VERSION}"
TAG="android-v$VERSION"

# versionCode must go up with every release, or Android refuses the update.
CODE=$(( $(grep -oE 'versionCode = [0-9]+' app/build.gradle.kts | grep -oE '[0-9]+') + 1 ))
sed -i '' -E "s/versionCode = [0-9]+/versionCode = $CODE/; s/versionName = \"[^\"]+\"/versionName = \"$VERSION\"/" app/build.gradle.kts

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
./gradlew -q testDebugUnitTest assembleRelease
APK="build/GyattChores-$VERSION.apk"
mkdir -p build && cp app/build/outputs/apk/release/app-release.apk "$APK"

git add app/build.gradle.kts
git commit -q -m "Android $VERSION (versionCode $CODE)"
git push -q origin HEAD
gh release create "$TAG" "$APK" --title "GyattChores Android $VERSION" --notes "$NOTES" --target "$(git rev-parse HEAD)"
echo "Released $TAG (versionCode $CODE)"
