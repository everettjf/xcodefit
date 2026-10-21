#!/bin/bash
set -euo pipefail

# Packaging does not run runtime tests by default. Publishing is a separate step.
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
version=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);/\1/p' XcodeFit/XcodeFit.xcodeproj/project.pbxproj | head -1)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected a semantic MARKETING_VERSION' >&2; exit 1; }
source_app=""
if [[ $# -eq 2 && "$1" == '--arm64-from' ]]; then
  source_app="$2"
  [[ -d "$source_app" ]] || { echo 'The source app does not exist' >&2; exit 1; }
  source_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")
  [[ "$source_version" == "$version" ]] || { echo 'Source app version does not match the project' >&2; exit 1; }
  codesign --verify --deep --strict "$source_app"
  lipo "$source_app/Contents/MacOS/XcodeFit" -verify_arch arm64
  release_dir="$root/dist/$version-arm64"
elif [[ $# -eq 0 ]]; then
  release_dir="$root/dist/$version"
else
  echo 'Usage: scripts/build-release.sh [--arm64-from /path/to/XcodeFit.app]' >&2
  exit 1
fi
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
if [[ "${RUN_TESTS:-0}" == '1' ]]; then swift test; fi
mkdir -p "$release_dir"
verify_dir=$(mktemp -d "${TMPDIR:-/tmp}/xcodefit-release-verify.XXXXXX")
trap 'rm -rf "$verify_dir"' EXIT

package_variant() {
  local variant="$1" input_app="$2" app="$release_dir/$1/XcodeFit.app"
  local suffix="" result="$release_dir/notarization-$1.json"
  if [[ "$variant" == 'arm64' ]]; then suffix='-arm64'; fi
  mkdir -p "$(dirname "$app")"
  ditto "$input_app" "$app"
  if [[ "$variant" == 'arm64' ]]; then
    if [[ "$(lipo -archs "$app/Contents/MacOS/XcodeFit")" != 'arm64' ]]; then
      lipo "$app/Contents/MacOS/XcodeFit" -thin arm64 -output "$app/Contents/MacOS/XcodeFit.arm64"
      mv "$app/Contents/MacOS/XcodeFit.arm64" "$app/Contents/MacOS/XcodeFit"
    fi
    [[ "$(lipo -archs "$app/Contents/MacOS/XcodeFit")" == 'arm64' ]] || { echo 'Expected an arm64-only executable' >&2; exit 1; }
  else
    lipo "$app/Contents/MacOS/XcodeFit" -verify_arch arm64
    lipo "$app/Contents/MacOS/XcodeFit" -verify_arch x86_64
  fi
  cp LICENSE "$app/Contents/Resources/LICENSE"
  cp NOTICE "$app/Contents/Resources/NOTICE"
  codesign --force --options runtime --timestamp --sign "$signing_identity" "$app"
  codesign --verify --deep --strict "$app"
  local notary_archive="$release_dir/XcodeFit-$version$suffix-notary.zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$notary_archive"
  xcrun notarytool submit "$notary_archive" "${notary_credentials[@]}" --wait \
    --output-format json > "$result"
  python3 - "$result" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
print('Notarization:', result.get('status'), 'ID:', result.get('id'))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; no distributable archive created')
PY
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=4 "$app"
  local archive="$release_dir/XcodeFit-$version$suffix.zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
  mkdir -p "$verify_dir/$variant"
  ditto -x -k "$archive" "$verify_dir/$variant"
  local extracted="$verify_dir/$variant/XcodeFit.app"
  codesign --verify --deep --strict "$extracted"
  xcrun stapler validate "$extracted"
  spctl --assess --type execute --verbose=4 "$extracted"
  if [[ "$variant" == 'arm64' ]]; then
    [[ "$(lipo -archs "$extracted/Contents/MacOS/XcodeFit")" == 'arm64' ]]
  else
    lipo "$extracted/Contents/MacOS/XcodeFit" -verify_arch arm64
    lipo "$extracted/Contents/MacOS/XcodeFit" -verify_arch x86_64
  fi
  (cd "$release_dir" && shasum -a 256 "XcodeFit-$version$suffix.zip" >> SHA256SUMS)
  echo "Package ready: $archive ($variant)"
}

if [[ -n "$source_app" ]]; then
  package_variant arm64 "$source_app"
else
  xcodebuild -project XcodeFit/XcodeFit.xcodeproj -scheme XcodeFit \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$root/build/distribution" \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
    ENABLE_HARDENED_RUNTIME=YES build > "$release_dir/build.log" 2>&1
  source_app="$root/build/distribution/Build/Products/Release/XcodeFit.app"
  package_variant universal "$source_app"
  package_variant arm64 "$source_app"
fi
cat "$release_dir/SHA256SUMS"
