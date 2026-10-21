# Contributing to XcodeFit

Thanks for helping make Xcode storage easier to understand.

## Report an issue

[Open an issue](https://github.com/everettjf/xcodefit/issues) with the app version, macOS and Xcode versions, what you expected, what happened, and steps to reproduce. For size or coverage problems, identify the kind of folder and whether it is a standard or custom location.

Redact user names, private project paths, app identifiers, and signing details before sharing screenshots or logs. Do not upload signing credentials, provisioning profiles, or real release archives.

## Send a pull request

1. Build and run the app using the [development guide](docs/DEVELOPMENT.md).
2. Keep the change focused and explain the resulting user-visible behavior.
3. For core logic changes, add meaningful tests using disposable fixtures and run `swift test`.
4. For new interface text, update all five translations and run `python3 Tools/ValidateLocalizations.py`.
5. For interface changes, inspect both light and dark appearance. Use `--ui-fixture` in Debug builds instead of personal developer data.

Do not test deletion against real Xcode archives, user source code, simulator data, or runtime installations. Preserve cleanup review, protected-location checks, and the distinction between recoverable Trash operations and irreversible simulator removal.

## Areas to help

- Recognizing additional supported Xcode storage layouts, with fixtures and clear cleanup consequences.
- Accessibility, translations, and small native interface improvements.
- Documentation and reproducible bug reports.
- Hardware verification on Intel Macs or the oldest supported macOS version.

For a substantial scanner or cleanup redesign, open an issue with examples before implementing it. Describe how incomplete metadata, unknown paths, active tools, and retained release symbols will be handled.

## Documentation and screenshots

The README and website share screenshots in `web/assets/screenshots/`. Keep matching light/dark images at the same dimensions and use real app captures with isolated test folders. Preserve the visible test-data label, and never present sample sizes as real cleanup results.

Website previews and release preparation are documented in [DEVELOPMENT.md](docs/DEVELOPMENT.md). A documentation-only change does not require rebuilding or republishing the app.

## License

Contributions are provided under the project’s [Apache 2.0 license](LICENSE).
