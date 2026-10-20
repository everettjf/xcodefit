# XcodeSize

[Website](https://everettjf.github.io/xcodesize/) · [Download](https://github.com/everettjf/homebrew-tap/releases/tag/xcodesize-v1.0.0) · [Apache 2.0](LICENSE)

A native macOS storage browser for understanding and cleaning Xcode's footprint. SwiftUI, AppKit and Foundation; no third-party runtime dependencies. English by default, with Simplified Chinese, Traditional Chinese, Japanese, Korean, and a Follow System option in Settings → Language.

## Install

```sh
brew install --cask everettjf/tap/xcodesize
```

[Download and release notes](https://github.com/everettjf/homebrew-tap/releases?q=xcodesize&expanded=true). Source code is public under Apache 2.0. Release binaries are distributed through the Homebrew tap.

Requires macOS 14 or later. The release application supports Apple Silicon and Intel, is signed with Developer ID, and is notarized by Apple. Homebrew updates are available with `brew upgrade --cask xcodesize`.

## Run from source

Open `XcodeSize/XcodeSize.xcodeproj`, select the **XcodeSize** scheme and run on **My Mac**. The deployment target is macOS 14; development and live verification were performed with Xcode 27.1 on macOS 27.

```sh
xcodebuild -project XcodeSize/XcodeSize.xcodeproj -scheme XcodeSize \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/XcodeSize.app
```

The app has App Sandbox disabled to inspect developer folders and invoke installed Apple tools. Release builds are Developer ID signed and notarized; the source build command above produces an unsigned development build. No administrator helper is installed.

## Browse

The overview shows allocated storage by function, alongside a native sortable/searchable table and an inspector with each item's purpose, ownership, evidence, path and cleanup impact. Double-click an item to browse its contents without adding nested sizes to the total. Locations can be revealed in Finder or copied. Protect a location to exclude it and its descendants from cleanup; protecting a recognized DerivedData component protects its project data root.

The scanner covers:

- Xcode installations in `/Applications`, `~/Applications`, one nested directory, and the active `xcode-select` installation; Command Line Tools and developer toolchains.
- User and system `Library/Developer` data, including unknown entries presented read-only.
- DerivedData projects, separately classified build products, indexes, packages, logs and shared caches.
- Archives with bundle/version metadata; device support by platform.
- Simulator devices from `simctl`; registered runtime backing images/AssetData, including Cryptex runtime layouts.
- Preview and XCTest devices, developer caches, documentation and diagnostic logs.
- SwiftPM caches and read-only configuration/signing locations.
- Absolute DerivedData/archive locations in Xcode preferences; `.build` and recognized custom DerivedData alongside projects identified by workspace metadata.
- User-added DerivedData collections or single-project roots, archive roots, `.build`, exports and read-only folders.

**Coverage is explicit.** Missing paths, inaccessible items and tool failures appear in Scan Coverage. Arbitrary script outputs, unknown Xcode installations and custom relative paths cannot be universally discovered: add their actual locations. Missing or unreadable storage is never claimed as zero completed storage.

## Interface languages

English is the source and default interface language, including scanning, purpose descriptions, cleanup review, and protection messages. Settings → Language offers English (`en`), 简体中文 (`zh-Hans`), 繁體中文 (`zh-Hant`), 日本語 (`ja`), 한국어 (`ko`), and Follow System. Unsupported system languages fall back to English. Clicking Done applies the choice and starts a fresh scan so cached descriptions use one language consistently. Names, paths, project identities and external tool output are preserved verbatim; history keeps messages from the language used when the operation ran.

Translations live in `XcodeSize/XcodeSize/Core/Resources/Localizable.xcstrings`. The app and Swift package tests compile the same catalog. Retained DeviceSupport versions and project protection roots use structured metadata, never translated display strings.

All five first-release languages cover every catalog entry, including purpose descriptions, cleanup consequences, irreversible-operation acknowledgments, and error messages. Traditional Chinese uses Taiwan-oriented terminology. System matching includes Traditional Chinese preferences such as Taiwan and Hong Kong.

Suggested additions, not yet shipped: German (`de`), French (`fr`), Spanish (`es`), and Brazilian Portuguese (`pt-BR`). Arabic and Hebrew would require a separate right-to-left layout pass, particularly for paths, tables and cleanup review.

```sh
python3 Tools/ValidateLocalizations.py
```

## Three cleanup tiers

| Tier | Recommended scope |
| --- | --- |
| Simple | Regenerable compile caches; old logs and documentation caches |
| Regular | Simple plus idle project build/index/package data and old device support |
| Deep | Regular plus recent regenerable data; archives, devices, runtimes and inactive Xcode installations become explicit manual candidates |

Defaults: retain logs for 30 days, idle threshold 90 days, and retain the two most recently modified device-support entries per platform. Settings affect recommendations. Modification time is labeled as such, never presented as proof of last use. Archives, simulator state, preview/test devices and old installations are not automatically selected.

All cleanup goes through a review sheet. Ordinary files use `FileManager.trashItem`; failure does not fall back to permanent deletion. Devices and registered runtime images use exact UUIDs with `simctl delete` / `simctl runtime delete`, with an additional irreversible-operation acknowledgment. Unsupported system-managed components remain read-only.

The engine rechecks process state, simulator registration, file identity and a recursive metadata fingerprint before each operation, including a second process probe after walking the directory. Active/unknown tooling, booted devices, protected paths, incomplete scans, changed paths, symlinks and overlapping operations are skipped. These checks reduce races but cannot make externally changing directories transactional; quit development tools before cleaning. No apps are forcibly quit and no Trash is emptied.

Records distinguish **moved to Trash**, **removed**, **skipped** and **failed**. Disk availability is observed again but is not attributed entirely to cleanup. Trash recovery depends on the original item still being in Trash; simctl removal has no undo.

## Measurement

Allocated/logical sizes include macOS resource forks using Foundation resource values. Files are deduplicated globally by device/inode; symbolic links and cross-filesystem descendants are not followed. Runtime mounts and DeviceFS views are excluded. APFS cloned extents and snapshots prevent an exact prediction of reclaimable blocks. Container directory metadata is not separately added when its children are independently classified.

## Verification

```sh
swift test
```

Core tests use disposable temporary fixtures. They cover hardlinks, symlinks, resource forks versus `du`, tier behavior, project classification and protection, custom paths, cancellation, file replacement, unknown/active tools, simulator command construction/failure, and the real macOS Trash API followed by restoration of the test fixture. Real simulator/runtime removal is intentionally not performed by tests.

For a read-only live coverage report:

```sh
swiftc -O -swift-version 6 -parse-as-library \
  XcodeSize/XcodeSize/Core/*.swift Tools/ScanAudit.swift -o build/scan-audit
build/scan-audit build/scan-report.json
```

Debug builds can launch with `--ui-fixture` to generate a separate disposable test tree and isolated preferences for UI inspection. The status bar labels fixture data explicitly. Release builds ignore this argument. Cleanup still rechecks the real tool environment.

```sh
open build/Build/Products/Debug/XcodeSize.app --args --ui-fixture
```

`Tools/GenerateIcon.swift` reproduces the native AppIcon asset catalog.

## Prepare a release

`scripts/build-release.sh` runs the tests, builds both CPU architectures, signs with Developer ID and hardened runtime, submits to Apple, staples the ticket, and verifies the exact app extracted from the final ZIP. It writes `dist/<version>/XcodeSize-<version>.zip` and `SHA256SUMS`; it does not publish anything.

Provide a `NOTARY_KEYCHAIN_PROFILE`, or `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_SPECIFIC_PASSWORD` in the environment. `SIGNING_IDENTITY` can select a particular Developer ID identity; otherwise the first available Developer ID Application identity is used. Never commit credentials. Release versions come from `MARKETING_VERSION` in the Xcode project. The Homebrew cask is mirrored under `packaging/homebrew/Casks/xcodesize.rb`.

## Website

The product website is a dependency-free static site in `web/`. GitHub Actions deploys only that directory to GitHub Pages when its contents change on `main`. To preview locally:

```sh
python3 -m http.server 8080 --directory web
```

The interactive product preview uses illustrative data; it never scans a visitor’s computer. The website loads no third-party scripts, fonts, or analytics.

## License

Copyright 2026 XcodeSize contributors. Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
