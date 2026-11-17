#!/bin/bash
# Build the Play Store bundle: the public edition (everything on the phone, no sync), signed with
# the upload key. Upload the .aab it prints in the Play Console; Play re-signs it for phones.
#
#   ./play-bundle.sh
#
# Needs ~/.android/gyattchores-upload.properties (or GYATTCHORES_UPLOAD_PROPERTIES) pointing at
# the upload keystore. Keep that keystore and its password backed up somewhere other than this
# Mac: if it's lost, Play can reset the upload key, but only after a support request.
#
# The family edition is not for Play: it keeps going out through ./release.sh and Obtainium.
set -euo pipefail
cd "$(dirname "$0")"
PROPS="${GYATTCHORES_UPLOAD_PROPERTIES:-$HOME/.android/gyattchores-upload.properties}"
[ -f "$PROPS" ] || { echo "No upload key: $PROPS is missing." >&2; exit 1; }

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
./gradlew -q testPublicDebugUnitTest bundlePublicRelease
AAB=app/build/outputs/bundle/publicRelease/app-public-release.aab

# Refuse a bundle that isn't signed with the upload key (a debug-signed bundle is rejected by Play).
OWNER=$("$JAVA_HOME/bin/keytool" -printcert -jarfile "$AAB" | grep -m1 Owner)
case "$OWNER" in *"Android Debug"*) echo "Signed with the debug key, not the upload key." >&2; exit 1;; esac

VERSION=$(grep -oE 'versionName = "[^"]+"' app/build.gradle.kts | cut -d'"' -f2)
CODE=$(grep -oE 'versionCode = [0-9]+' app/build.gradle.kts | grep -oE '[0-9]+')
OUT="build/DOYOURWORK-play-$VERSION-$CODE.aab"
mkdir -p build && cp "$AAB" "$OUT"
echo "$OUT  (version $VERSION, versionCode $CODE, $OWNER)"
