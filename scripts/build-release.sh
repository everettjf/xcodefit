#!/bin/bash
set -euo pipefail

# Build and notarize locally. Publishing is a separate, explicit step.
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
version=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);/\1/p' XcodeSize/XcodeSize.xcodeproj/project.pbxproj | head -1)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected a semantic MARKETING_VERSION' >&2; exit 1; }
release_dir="$root/dist/$version"
[[ ! -e "$release_dir" ]] || { echo "Release output already exists: $release_dir" >&2; exit 1; }
signing_identity="${SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"
[[ -n "$signing_identity" ]] || { echo 'A Developer ID Application identity is required' >&2; exit 1; }
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  notary_credentials=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
else
  : "${APPLE_ID:?Set APPLE_ID or NOTARY_KEYCHAIN_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
  : "${APPLE_SPECIFIC_PASSWORD:?Set APPLE_SPECIFIC_PASSWORD}"
  notary_credentials=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_SPECIFIC_PASSWORD")
fi

python3 Tools/ValidateLocalizations.py
swift test
mkdir -p "$release_dir"
xcodebuild -project XcodeSize/XcodeSize.xcodeproj -scheme XcodeSize \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$root/build/distribution" \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
  ENABLE_HARDENED_RUNTIME=YES build > "$release_dir/build.log" 2>&1
app="$release_dir/XcodeSize.app"
ditto "$root/build/distribution/Build/Products/Release/XcodeSize.app" "$app"
cp LICENSE "$app/Contents/Resources/LICENSE"
codesign --force --options runtime --timestamp --sign "$signing_identity" "$app"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/XcodeSize" -verify_arch arm64
lipo "$app/Contents/MacOS/XcodeSize" -verify_arch x86_64
notary_archive="$release_dir/XcodeSize-$version-notary.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$notary_archive"
xcrun notarytool submit "$notary_archive" "${notary_credentials[@]}" --wait \
  --output-format json > "$release_dir/notarization.json"
python3 - "$release_dir/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
print('Notarization:', result.get('status'), 'ID:', result.get('id'))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; no distributable archive created')
PY
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=4 "$app"
archive="$release_dir/XcodeSize-$version.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
# Verify the exact packaged app, including its stapled ticket.
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/xcodesize-release-verify.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT
ditto -x -k "$archive" "$verify_dir"
codesign --verify --deep --strict "$verify_dir/XcodeSize.app"
xcrun stapler validate "$verify_dir/XcodeSize.app"
spctl --assess --type execute --verbose=4 "$verify_dir/XcodeSize.app"
(cd "$release_dir" && shasum -a 256 "XcodeSize-$version.zip" > SHA256SUMS)
echo "Release ready: $archive"
cat "$release_dir/SHA256SUMS"
