#!/usr/bin/env bash
# Builds a distributable Disk Clean AI release: universal archive → Developer ID export →
# notarize → staple → zip (for the in-app updater) + drag-to-Applications DMG (for the website).
# Prints the `gh release create` command that publishes both; the app's updater picks up the
# newest GitHub release on postmcp/diskcleanai.
#
#   ./scripts/build-release.sh          # TEAM_ID defaults to 4P833G76XL
#
# Requirements (one-time, see UPDATING.md):
#   • "Developer ID Application" certificate in your login keychain
#   • notarytool credentials stored under $NOTARY_PROFILE:
#       xcrun notarytool store-credentials diskcleanai --apple-id you@example.com --team-id 4P833G76XL
#   • brew install create-dmg
#
# Optional:
#   SKIP_NOTARIZE=1   build and zip without notarizing (local testing only)
#   SKIP_DMG=1        only build the zip
#   OUT=./build       output directory (default ./build)
#   REPO=owner/name   GitHub repository to publish to (default postmcp/diskcleanai)
set -euo pipefail

cd "$(dirname "$0")/.."
TEAM_ID="${TEAM_ID:-4P833G76XL}"
REPO="${REPO:-postmcp/diskcleanai}"
NOTARY_PROFILE="${NOTARY_PROFILE:-diskcleanai}"
OUT="${OUT:-./build}"
SCHEME=DiskCleanAI
PROJECT=DiskCleanAI.xcodeproj
ARCHIVE="$OUT/$SCHEME.xcarchive"
EXPORT="$OUT/export"

rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$OUT"

echo "▸ Archiving (Release)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" archive ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
  -allowProvisioningUpdates -quiet

# The archive is signed with your development certificate; the export re-signs it with
# "Developer ID Application" as ExportOptions.plist requests.
echo "▸ Exporting with Developer ID…"
sed "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/" scripts/ExportOptions.plist > "$OUT/ExportOptions.plist"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$EXPORT" -allowProvisioningUpdates -quiet

APP="$EXPORT/$SCHEME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")
# Same name every release: the website links to releases/latest/download/DiskCleanAI.zip.
ZIP="$OUT/DiskCleanAI.zip"
echo "▸ Built $VERSION (build $BUILD)"

# One universal binary serves Apple silicon and Intel; refuse to ship a single-architecture build.
ARCHS_BUILT=$(lipo -archs "$APP/Contents/MacOS/$SCHEME")
[[ "$ARCHS_BUILT" == *arm64* && "$ARCHS_BUILT" == *x86_64* ]] || { echo "Not universal: $ARCHS_BUILT" >&2; exit 1; }
echo "▸ Universal binary: $ARCHS_BUILT"

codesign --verify --deep --strict "$APP"
echo "▸ Signature OK: $(codesign -dvv "$APP" 2>&1 | grep '^Authority=' | head -1)"

if [[ -z "${SKIP_NOTARIZE:-}" ]]; then
  echo "▸ Notarizing (this usually takes 1–5 minutes)…"
  NOTARY_ZIP="$OUT/notarize-$BUILD.zip"
  ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  rm -f "$NOTARY_ZIP"
  echo "▸ Stapling ticket…"
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose=2 "$APP" 2>&1 | head -2
else
  echo "▸ SKIP_NOTARIZE set — users will get a Gatekeeper warning on first launch of this build."
fi

echo "▸ Zipping…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
SIZE=$(stat -f%z "$ZIP")

DMG="$OUT/DiskCleanAI.dmg"
ASSETS="\"$ZIP\""
if [[ -z "${SKIP_DMG:-}" ]]; then
  ./scripts/make-dmg.sh "$APP" "$DMG"
  ASSETS="$ASSETS \"$DMG\""
  DMG_LINE="  $DMG · $(stat -f%z "$DMG") bytes · sha256 $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
fi

cat <<MSG

✔ $ZIP
  version $VERSION · build $BUILD · $SIZE bytes
  sha256  $SHA
${DMG_LINE:-}

Next — publish it as a GitHub release (the tag must match the app version; keep the asset
names: the updater downloads DiskCleanAI.zip, the website's Download button DiskCleanAI.dmg):
  gh release create v$VERSION $ASSETS --repo $REPO --title "Disk Clean AI $VERSION" --notes-file notes.md

Every running copy offers the update on its next daily check; the website's
Download button follows /releases/latest automatically.
MSG
