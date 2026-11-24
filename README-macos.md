# NuGet Package Explorer on macOS

This fork builds the cross-platform Uno Platform version of NuGet Package Explorer (the same code that
powers [nuget.info](https://nuget.info)) as a native macOS app.

## Install

Requires the .NET SDK pinned in `global.json` and Xcode command line tools (for `swift`).

```sh
git clone https://github.com/tomludd/NuGetPackageExplorer.git
cd NuGetPackageExplorer
scripts/install-macos.sh            # installs to ~/Applications
```

The script:

1. Publishes `Uno/NuGetPackageExplorer` for `net10.0-desktop` as a self-contained `.app` (arm64 or x64).
2. Wraps it in a small AppleScript launcher app. Finder opens documents by sending an Apple Event that
   the Uno macOS host does not handle, so the launcher receives it and starts the real app with the
   file path as a command-line argument.
3. Registers `.nupkg` and `.snupkg` and makes the app their default, so double-clicking a package
   opens it.

Run it again after pulling to update.

## Changes from upstream

- `NuGetPackageExplorer.WinUI.csproj` targets only `net10.0-desktop`, so the build needs neither the
  Windows SDK nor the WebAssembly workload.
- A launch argument wrapped in quotes (a path containing spaces) is unquoted before it is opened.
- The Uno macOS `.app` launcher starts the runtime without passing on the process arguments, so on
  macOS the app reads the file path from the native process arguments (`_NSGetArgv`) instead.

Some features are still unimplemented in the Uno build and may show "not implemented" errors.
