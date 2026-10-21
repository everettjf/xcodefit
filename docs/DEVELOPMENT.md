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

### Interface layout regression checks

In a Debug fixture session, open Overview, then Project Builds and every other category. Repeat with the inspector open and closed, after resizing the window, and in light/dark appearance. The category heading, table (or empty state), sidebar header, and bottom status bar must remain inside the window. Also check a language change through Settings. Select two different rows in succession and confirm the inspector name, ownership, identification, path, and sizes all match the current row. Selectable text must not retain the previous item.

Run the native history layout checks with:

```sh
scripts/check-ui-layout.sh
```

This compiles the actual app views into a separate test executable, uses isolated fixture preferences, and measures empty/populated history at three available content sizes. It asserts that the page starts at the top, fills the width, and meets a status bar anchored to the bottom. It does not scan or clean real developer folders. These checks reject the pre-1.0.6 empty-history layout.

For 1.0.6, all 17 destinations were clicked and captured in dark appearance at the normal window size and in light appearance after maximizing. Each capture was visually checked for header placement, visible rows or a centered empty state, and a bottom-aligned status bar. Populated history, inspector visibility, settings, and archive-retention panels were also inspected. Cleanup execution was also checked with active tools: all five fixture items were skipped and recorded with the running-tools reason. The native Trash integration test separately moved a disposable file into the macOS Trash, verified the recorded destination, and restored it successfully. Screenshots use disposable fixture data; local verification captures are in the ignored `build/ui-review.noindex/` directory.

Category descriptions must accept the split view's proposed height. Giving them a vertically fixed size can inflate the split view's minimum height during narrow-width measurement and move its contents outside the visible window.

For 1.0.4/1.0.5, the blank-category failure was reproduced before the fix. All 17 sidebar destinations, search/empty results, name sorting, inspector toggling, nested folder browsing, adding-location dialogs/cancellation, protection/removal, Standard selection/review, Deep archive retention/review/acknowledgment, cleanup results/history, settings/language switching, and light/dark navigation were exercised with disposable fixtures. Execution correctly skipped cleanup while Xcode was running. Actual Trash operations remain covered by the core tests; real simulator/runtime deletion was not exercised.

`Tools/GenerateIcon.swift` reproduces the native AppIcon asset catalog.

## Prepare a release

`scripts/build-release.sh` builds a Universal executable and packages two separately signed, notarized, and stapled apps:

- `XcodeFit-<version>-arm64.zip`: Apple Silicon only (`arm64`).
- `XcodeFit-<version>.zip`: Universal (`arm64` + `x86_64`). The existing unsuffixed name remains for compatibility with older download and update-check clients.

Each ZIP is extracted for signature, notarization ticket, Gatekeeper and architecture checks. This is package validation, not Intel runtime or compatibility testing. Intel execution is untested; do not describe it as verified support. `SHA256SUMS` covers both packages. The script does not publish anything and does not run runtime tests by default. Set `RUN_TESTS=1` only when you explicitly want to run the core tests as well.

To add an Apple Silicon package from an existing signed app without rebuilding or changing the Universal package:

```sh
scripts/build-release.sh --arm64-from /path/to/XcodeFit.app
```

The app version must match the project. Output goes into a new `dist/<version>-arm64/` directory. Thinning invalidates the original signature, so the arm64 app is signed and notarized again. Never overwrite the original Universal ZIP; merge both checksums when publishing the additional asset.

Provide a `NOTARY_KEYCHAIN_PROFILE`, or `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_SPECIFIC_PASSWORD` in the environment. `SIGNING_IDENTITY` can select a particular Developer ID identity; otherwise the first available Developer ID Application identity is used. Never commit credentials. Release versions come from `MARKETING_VERSION` in the Xcode project. The Homebrew cask is mirrored under `packaging/homebrew/Casks/xcodefit.rb`.

Keep release numbers and versioned ZIP paths out of the README and website. Download and release-note links use the stable XcodeFit-filtered release list in the shared Homebrew repository. Update the Homebrew cask for each release; do not use that repository’s global latest-release URL, since other apps publish there too.

## Website

The product website is a dependency-free static site in `web/`. GitHub Actions deploys only that directory to GitHub Pages when its contents change on `main`. To preview locally:

```sh
python3 -m http.server 8080 --directory web
```

The website follows the system light/dark appearance automatically using CSS, including live preference changes without a reload. Both themes include the product preview, installation command, and browser theme colors.

The interactive product preview uses illustrative data; it never scans a visitor’s computer. The website loads no third-party scripts, fonts, or analytics.

