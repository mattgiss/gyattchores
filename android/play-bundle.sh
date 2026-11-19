#!/bin/bash
# Build the Play Store bundle: the play flavor (the same app as the github one, with the
# com.doyourwork.app id), signed with the upload key. Upload the .aab it prints in the Play Console; Play re-signs it for phones.
#
#   ./play-bundle.sh
#
# Needs ~/.android/doyourwork-upload.properties (or DOYOURWORK_UPLOAD_PROPERTIES) pointing at
# the upload keystore; the file name and variable from before the rename still work if those are missing. Keep that keystore and its password backed up somewhere other than this
# Mac: if it's lost, Play can reset the upload key, but only after a support request.
#
# The github flavor is not for Play: it keeps going out through ./release.sh and Obtainium.
set -euo pipefail
cd "$(dirname "$0")"
# Same order as app/build.gradle.kts: the new name first, then the legacy one from before the rename.
PROPS=""
for p in "${DOYOURWORK_UPLOAD_PROPERTIES:-}" "$HOME/.android/doyourwork-upload.properties" \
         "${GYATTCHORES_UPLOAD_PROPERTIES:-}" "$HOME/.android/gyattchores-upload.properties"; do
  if [ -n "$p" ] && [ -f "$p" ]; then PROPS="$p"; break; fi
done
[ -n "$PROPS" ] || { echo "No upload key: $HOME/.android/doyourwork-upload.properties is missing." >&2; exit 1; }

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
./gradlew -q testPlayDebugUnitTest bundlePlayRelease
AAB=app/build/outputs/bundle/playRelease/app-play-release.aab

# Refuse a bundle that isn't signed with the upload key (a debug-signed bundle is rejected by Play).
OWNER=$("$JAVA_HOME/bin/keytool" -printcert -jarfile "$AAB" | grep -m1 Owner)
case "$OWNER" in *"Android Debug"*) echo "Signed with the debug key, not the upload key." >&2; exit 1;; esac

# The play flavor's own versionName (see app/build.gradle.kts).
VERSION=$(sed -n '/create("play")/,/^        }/p' app/build.gradle.kts | grep -oE 'versionName = "[^"]+"' | cut -d'"' -f2)
CODE=$(grep -oE 'versionCode = [0-9]+' app/build.gradle.kts | grep -oE '[0-9]+')
OUT="build/DOYOURWORK-play-$VERSION-$CODE.aab"
mkdir -p build && cp "$AAB" "$OUT"
echo "$OUT  (version $VERSION, versionCode $CODE, $OWNER)"
