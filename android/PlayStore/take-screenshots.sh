#!/bin/bash
# Retake the Play Store screenshots in android/PlayStore/screenshots/ from the app as it is now.
# No phone or emulator needed: the public edition is drawn on this computer with a made-up family.
#
#   ./PlayStore/take-screenshots.sh        (from android/)
#
# One device per run, on purpose (see StoreScreenshotsTest).
set -euo pipefail
cd "$(dirname "$0")/.."
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
[ -x "$JAVA_HOME/bin/java" ] || unset JAVA_HOME
rm -rf PlayStore/screenshots
for device in phone tablet7 tablet10; do
  ./gradlew -q -PstoreScreenshots :app:testPublicDebugUnitTest --tests "*StoreScreenshotsTest.$device"
done
find PlayStore/screenshots -name '*.png' | sort
