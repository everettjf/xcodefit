# Upgrading from XcodeSize

[Back to XcodeFit](../README.md)

The project, app, and Homebrew cask are now **XcodeFit**. The tap includes a cask rename from `xcodesize` to `xcodefit`. For an existing installation, run:

```sh
brew update
brew reinstall --cask everettjf/tap/xcodefit
```

The new app imports language, cleanup settings, custom scan locations, protection, and cleanup history from the previous preference domain once. Existing XcodeFit preferences are never overwritten. The old domain is kept intact for recovery; ordinary upgrades do not zap preferences. Historical releases retain their original names.
