#!/usr/bin/env bash
# Wraps a signed, notarized DiskCleanAI.app in a drag-to-Applications disk image, then signs,
# notarizes and staples the image itself. Called by build-release.sh; can also be run alone:
#
#   ./scripts/make-dmg.sh build/export/DiskCleanAI.app build/DiskCleanAI.dmg
#
# Requires `brew install create-dmg`. The first run may ask to let Terminal control Finder —
# that is how the window layout (icon positions, background) gets saved into the image.
#
# Optional:
#   SKIP_NOTARIZE=1   sign but do not notarize the image (local testing only)
set -euo pipefail

cd "$(dirname "$0")/.."
APP="${1:?usage: make-dmg.sh path/to/DiskCleanAI.app output.dmg}"
DMG="${2:?usage: make-dmg.sh path/to/DiskCleanAI.app output.dmg}"
TEAM_ID="${TEAM_ID:-4P833G76XL}"
NOTARY_PROFILE="${NOTARY_PROFILE:-diskcleanai}"
command -v create-dmg >/dev/null || { echo "create-dmg not found: brew install create-dmg" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Disk Clean AI.app"

echo "▸ Building disk image…"
rm -f "$DMG"
create-dmg \
  --volname "Disk Clean AI $VERSION" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --background scripts/dmg/background.tiff \
  --window-pos 200 140 --window-size 660 400 \
  --icon-size 128 --text-size 13 \
  --icon "Disk Clean AI.app" 165 200 \
  --app-drop-link 495 200 \
  --hide-extension "Disk Clean AI.app" \
  --no-internet-enable \
  "$DMG" "$STAGE" >/dev/null

IDENTITY=$(security find-identity -v -p codesigning | grep -o "\"Developer ID Application: [^\"]*($TEAM_ID)\"" | head -1 | tr -d '"')
[[ -n "$IDENTITY" ]] || { echo "No Developer ID Application identity for $TEAM_ID in the keychain" >&2; exit 1; }
codesign --sign "$IDENTITY" --timestamp "$DMG"

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
  echo "▸ Notarizing disk image…"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" 2>&1 | head -2
fi
