# Developing XcodeFit

[Back to XcodeFit](../README.md) · [Contribution guide](../CONTRIBUTING.md)

Run commands from the repository root.

## Run from source

Open `XcodeFit/XcodeFit.xcodeproj`, select the **XcodeFit** scheme and run on **My Mac**. The deployment target is macOS 14; development and live verification were performed with Xcode 27.1 on macOS 27.

```sh
xcodebuild -project XcodeFit/XcodeFit.xcodeproj -scheme XcodeFit \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/XcodeFit.app
```

The app has App Sandbox disabled to inspect developer folders and invoke installed Apple tools. Release builds are Developer ID signed and notarized; the source build command above produces an unsigned development build. No administrator helper is installed.

## Interface languages

English is the source and default interface language, including scanning, purpose descriptions, cleanup review, and protection messages. Settings → Language offers English (`en`), 简体中文 (`zh-Hans`), 繁體中文 (`zh-Hant`), 日本語 (`ja`), 한국어 (`ko`), and Follow System. Unsupported system languages fall back to English. Clicking Done applies the choice and starts a fresh scan so cached descriptions use one language consistently. Names, paths, project identities and external tool output are preserved verbatim; history keeps messages from the language used when the operation ran.

Translations live in `XcodeFit/XcodeFit/Core/Resources/Localizable.xcstrings`. The app and Swift package tests compile the same catalog. Retained DeviceSupport versions and project protection roots use structured metadata, never translated display strings.

All five first-release languages cover every catalog entry, including purpose descriptions, cleanup consequences, irreversible-operation acknowledgments, and error messages. Traditional Chinese uses Taiwan-oriented terminology. System matching includes Traditional Chinese preferences such as Taiwan and Hong Kong.

Suggested additions, not yet shipped: German (`de`), French (`fr`), Spanish (`es`), and Brazilian Portuguese (`pt-BR`). Arabic and Hebrew would require a separate right-to-left layout pass, particularly for paths, tables and cleanup review.

```sh
python3 Tools/ValidateLocalizations.py
```

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

