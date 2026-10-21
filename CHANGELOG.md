# Changelog

## 1.0.4 — build 8

- Fix category navigation stretching the split view beyond the window, leaving a blank detail area and clipping the sidebar.
- Let category descriptions adapt to available space during split-view measurement, including window resizing and inspector changes.

## 1.0.3 — build 7

- Replace custom purple/cream app surfaces with native macOS window, sidebar, control and separator colors that follow system light/dark appearance.
- Remove pastel card fills, tinted icon tiles and overview gradients. Keep the mascot, with bamboo-green accents for actions, totals and selection outlines.
- Use system category colors for charts and icons, preserving labels and explicit selected-state checkmarks. Remove obsolete custom color assets.
- Apply the native surfaces to cleanup choices, inspectors and update panels. Cleanup and update-check behavior are unchanged.

## 1.0.2 — build 6

- Add Check for Updates to the XcodeFit menu and Settings, with current version, last successful check, explicit errors, and a release-page link when a newer version is available.
- Check GitHub at launch or when returning to the app, at most daily, with a persistent opt-out and cached release metadata. Manual checks remain available.
- Filter stable downloadable XcodeFit releases in the shared Homebrew tap, compare numeric versions, handle pagination and rate limits, and show a sidebar notice for available updates.
- Localize update controls and messages in all five languages. No file data is sent, and updates are not installed automatically.

## 1.0.1 — build 5

- Refresh the website with bamboo greens, soft ivory surfaces, and a coordinated forest-green dark appearance.
- Align website navigation, demo labels, and sharing copy with the XcodeFit name.
- Publish a new signed and notarized universal build for normal Homebrew upgrades. The app retains its colorful interface, five languages, and Standard/Deep cleanup behavior.

## 1.0.0 — build 4 (colorful checkup)

- Refresh the website with candy-colored stickers, playful rounded type, mint mascot backdrop, hearts/stars, and brighter light/dark palettes.
- Add coordinated adaptive colors to the app: mascot branding, colorful category cards, pastel storage summary, and mint/purple cleanup modes.
- Preserve native readability, reduced-motion behavior, cleanup review, and safety warnings.


## 1.0.0 — build 3 (XcodeFit)

- Rename the app, repository, Xcode project, source paths, bundle ID, Swift package and Homebrew cask to XcodeFit.
- Import legacy language, cleanup settings, protected paths, scan locations and history once, without overwriting current preferences.
- Introduce a friendly chubby claw-hammer icon and a fully redesigned storage checkup website with interactive anatomy, local example report, reduced-motion support and automatic light/dark appearance.
- Add Homebrew token migration from xcodesize to xcodefit. Historical builds retain their original identities.


## 1.0.0 — build 2 (re-release)

- Replace three cleanup tiers with Standard (default) and Deep.
- Exclude archives, detected release symbols and mutable package working copies from Standard cleanup.
- Add per-app/platform/team archive retention previews: keep latest 1/3/5 versions with every build, or explicitly select all unprotected archives.
- Show archive product/symbol size breakdown and local binary/dSYM UUID matching, without assuming upload or backup status.
- Preserve protected and unidentified archives under version rules; require review and acknowledgment before cleanup.
- Update all five app languages and add archive safety tests.


## 1.0.0 — build 1

- Browse Xcode installations, SDKs, build data, caches, archives, simulator devices and runtimes, device support, Swift packages, logs, and documentation.
- Inspect folder sizes, source paths, purpose, ownership, and cleanup consequences. Add custom scan locations and protect folders.
- Review Quick, Standard, or Deep cleanup. Ordinary files move to Trash; supported simulator operations use Apple's `simctl` with additional confirmation.
- Show scan coverage, inaccessible locations, and cleanup history. Deduplicate files and exclude mounted runtime and DeviceFS views.
- Support English (default), Simplified Chinese, Traditional Chinese, Japanese, and Korean.
- Provide a universal macOS application for Apple Silicon and Intel, requiring macOS 14 or later.
