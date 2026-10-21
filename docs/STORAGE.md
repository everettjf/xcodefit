# Storage, cleanup, and measurement

[Back to XcodeFit](../README.md)

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

## Check for updates

Use **XcodeFit → Check for Updates…** or **Settings → Software Updates**. The app checks public GitHub release metadata at launch or when returning to the app, at most once a day. You can turn automatic checks off; manual checks always remain available. No file data is sent, and updates are never installed automatically.

A newer stable XcodeFit version appears in the sidebar and update panel, with a link to its release page and Homebrew upgrade instructions. Cached release information and the last successful check survive restarts. Checks filter XcodeFit tags and downloadable ZIP assets from the shared `everettjf/homebrew-tap` repository, handle pagination, and distinguish network/rate-limit errors from an up-to-date result. This does not use the shared repository’s global latest-release pointer.

