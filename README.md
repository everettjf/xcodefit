# XcodeFit

<img src="web/assets/app-icon.png" width="112" alt="XcodeFit’s friendly claw-hammer mascot">

**A little checkup. A lighter Xcode.**

[Website](https://xnu.app/xcodefit/) · [Download](https://github.com/everettjf/homebrew-tap/releases/tag/xcodefit-v1.0.0) · [Apache 2.0](LICENSE)

A friendly native macOS storage checkup for Xcode. See which parts are taking space, understand their purpose, and clean with care. SwiftUI, AppKit and Foundation; no third-party runtime dependencies. English by default, with Simplified Chinese, Traditional Chinese, Japanese, Korean, and a Follow System option in Settings → Language.

## Install

```sh
brew install --cask everettjf/tap/xcodefit
```

[Download and release notes](https://github.com/everettjf/homebrew-tap/releases?q=xcodefit&expanded=true). Source code is public under Apache 2.0. Release binaries are distributed through the Homebrew tap.

Requires macOS 14 or later. The release application supports Apple Silicon and Intel, is signed with Developer ID, and is notarized by Apple. Homebrew updates are available with `brew upgrade --cask xcodefit`. Reinstall when replacing a build with the same 1.0.0 version number.

## Upgrading from XcodeSize

The project, app, and Homebrew cask are now **XcodeFit**. The tap includes a cask rename from `xcodesize` to `xcodefit`. For an existing installation, run:

```sh
brew update
brew reinstall --cask everettjf/tap/xcodefit
```

The new app imports language, cleanup settings, custom scan locations, protection, and cleanup history from the previous preference domain once. Existing XcodeFit preferences are never overwritten. The old domain is kept intact for recovery; ordinary upgrades do not zap preferences. Historical releases retain their original names.

## Run from source

Open `XcodeFit/XcodeFit.xcodeproj`, select the **XcodeFit** scheme and run on **My Mac**. The deployment target is macOS 14; development and live verification were performed with Xcode 27.1 on macOS 27.

```sh
xcodebuild -project XcodeFit/XcodeFit.xcodeproj -scheme XcodeFit \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/XcodeFit.app
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

Translations live in `XcodeFit/XcodeFit/Core/Resources/Localizable.xcstrings`. The app and Swift package tests compile the same catalog. Retained DeviceSupport versions and project protection roots use structured metadata, never translated display strings.

All five first-release languages cover every catalog entry, including purpose descriptions, cleanup consequences, irreversible-operation acknowledgments, and error messages. Traditional Chinese uses Taiwan-oriented terminology. System matching includes Traditional Chinese preferences such as Taiwan and Hong Kong.

Suggested additions, not yet shipped: German (`de`), French (`fr`), Spanish (`es`), and Brazilian Portuguese (`pt-BR`). Arabic and Hebrew would require a separate right-to-left layout pass, particularly for paths, tables and cleanup review.

```sh
python3 Tools/ValidateLocalizations.py
```

## Two cleanup modes

| Mode | Scope |
| --- | --- |
| Standard (default) | Regenerable compiler caches, old logs and idle build/index data. Archives, release symbols, source working copies, and device/test state are excluded. A build folder containing dSYMs is excluded as a whole. |
| Deep | Adds recent rebuildable data and explicit manual choices for archives, dependencies with source working copies, device support, simulators, runtimes, and inactive Xcode installations. |

Defaults: retain logs for 30 days and use a 90-day idle threshold. Settings affect recommendations. Modification time is labeled as such, never presented as proof of last use. Irreplaceable data is never selected by **Select Recommended**.

Deep mode's **Manage Archives** previews rules to keep the latest 1, 3, or 5 numeric marketing versions per bundle ID, platform, and signing team, retaining **every build** of each version. Missing identity, unknown versions and protected paths stay. The default rule keeps 3 versions. **Remove all unprotected archives** explicitly includes unidentified archives, but still honors protection and scan/cleanup eligibility; it does not delete exported symbols outside those archives. Rules only change the selection. The cleanup review and acknowledgment are still required.

Archive details show products, release symbols (dSYMs and legacy BCSymbolMaps), and remaining data as parts of the archive total. **Check Symbol UUIDs** runs local `xcrun dwarfdump --uuid` on discovered Mach-O files in Products and dSYMs, including frameworks/extensions and architectures. It reports missing matches and incomplete checks, without claiming upload or backup verification. The app does not infer whether a build was distributed or is still supported. Keep all distributed builds you still need to symbolicate, even when a newer version exists. See [Apple's debugging information guidance](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information).

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
  XcodeFit/XcodeFit/Core/*.swift Tools/ScanAudit.swift -o build/scan-audit
build/scan-audit build/scan-report.json
```

Debug builds can launch with `--ui-fixture` to generate a separate disposable test tree and isolated preferences for UI inspection. The status bar labels fixture data explicitly. Release builds ignore this argument. Cleanup still rechecks the real tool environment.

```sh
open build/Build/Products/Debug/XcodeFit.app --args --ui-fixture
```

`Tools/GenerateIcon.swift` reproduces the native AppIcon asset catalog.

## Prepare a release

`scripts/build-release.sh` runs the tests, builds both CPU architectures, signs with Developer ID and hardened runtime, submits to Apple, staples the ticket, and verifies the exact app extracted from the final ZIP. It writes `dist/<version>/XcodeFit-<version>.zip` and `SHA256SUMS`; it does not publish anything.

Provide a `NOTARY_KEYCHAIN_PROFILE`, or `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_SPECIFIC_PASSWORD` in the environment. `SIGNING_IDENTITY` can select a particular Developer ID identity; otherwise the first available Developer ID Application identity is used. Never commit credentials. Release versions come from `MARKETING_VERSION` in the Xcode project. The Homebrew cask is mirrored under `packaging/homebrew/Casks/xcodefit.rb`.

## Website

The product website is a dependency-free static site in `web/`. GitHub Actions deploys only that directory to GitHub Pages when its contents change on `main`. To preview locally:

```sh
python3 -m http.server 8080 --directory web
```

The website follows the system light/dark appearance automatically using CSS, including live preference changes without a reload. Both themes include the product preview, installation command, and browser theme colors.

The interactive product preview uses illustrative data; it never scans a visitor’s computer. The website loads no third-party scripts, fonts, or analytics.

## License

Copyright 2026 XcodeFit contributors. Licensed under the [Apache License, Version 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
