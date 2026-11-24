#!/usr/bin/env bash
# Builds the Uno (Skia) desktop head of NuGet Package Explorer as a self-contained
# macOS .app bundle and installs it to ~/Applications (or the folder given as $1).
#
# Usage: scripts/install-macos.sh [install-dir]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="${1:-$HOME/Applications}"
project="$repo_root/Uno/NuGetPackageExplorer/NuGetPackageExplorer.WinUI.csproj"
app_name="NuGet Package Explorer.app"

case "$(uname -m)" in
  arm64) rid="osx-arm64" ;;
  x86_64) rid="osx-x64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# Nerdbank.GitVersioning needs the full history to compute the version height.
if [ "$(git -C "$repo_root" rev-parse --is-shallow-repository)" = "true" ]; then
  echo "Shallow clone detected, fetching full history..."
  git -C "$repo_root" fetch --unshallow
fi

# The .app bundler needs a version before GitVersioning has set one, so read it from version.json.
version="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([0-9.]*\).*/\1/p' "$repo_root/version.json" | head -1)"

echo "Publishing NuGet Package Explorer $version for $rid..."
dotnet publish "$project" \
  -c Release \
  -f net10.0-desktop \
  -r "$rid" \
  --self-contained \
  -p:PackageFormat=app \
  -p:ApplicationDisplayVersion="$version" \
  -p:ApplicationVersion="$version"

built_app="$repo_root/artifacts/publish/NuGetPackageExplorer.WinUI/release_net10.0-desktop_$rid/$app_name"
if [ ! -d "$built_app" ]; then
  echo "Expected app bundle not found: $built_app" >&2
  exit 1
fi

# Finder opens documents with an Apple Event the Uno macOS host ignores, so the installed app is an
# AppleScript wrapper that receives it and starts the real app (inside it) with the path as argument.
echo "Building the launcher app..."
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
wrapper="$work_dir/$app_name"
osacompile -o "$wrapper" "$repo_root/scripts/macos/launcher.applescript"
cp -R "$built_app" "$wrapper/Contents/Resources/"
cp "$built_app/Contents/Resources/icon.icns" "$wrapper/Contents/Resources/applet.icns"

plist="$wrapper/Contents/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$plist"; }
# Replaces a top-level key, whether or not the applet template already has it.
pb_put() { pb "Delete :$1" 2>/dev/null || true; pb "Add :$1 $2 ${3:-}"; }
pb_put CFBundleIdentifier string info.nuget.nugetpackageexplorer.launcher
pb_put CFBundleName string "NuGet Package Explorer"
pb_put CFBundleShortVersionString string "$version"
pb_put CFBundleVersion string "$version"
pb_put CFBundleDocumentTypes array
pb_put UTImportedTypeDeclarations array
i=0
for ext in nupkg snupkg; do
  uti="org.nuget.$ext"
  pb "Add :UTImportedTypeDeclarations:$i dict"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeIdentifier string $uti"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeDescription string NuGet package (.$ext)"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeConformsTo array"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeConformsTo:0 string public.zip-archive"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeTagSpecification dict"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeTagSpecification:public.filename-extension array"
  pb "Add :UTImportedTypeDeclarations:$i:UTTypeTagSpecification:public.filename-extension:0 string $ext"
  pb "Add :CFBundleDocumentTypes:$i dict"
  pb "Add :CFBundleDocumentTypes:$i:CFBundleTypeName string NuGet package (.$ext)"
  pb "Add :CFBundleDocumentTypes:$i:CFBundleTypeRole string Viewer"
  pb "Add :CFBundleDocumentTypes:$i:LSHandlerRank string Owner"
  pb "Add :CFBundleDocumentTypes:$i:LSItemContentTypes array"
  pb "Add :CFBundleDocumentTypes:$i:LSItemContentTypes:0 string $uti"
  i=$((i + 1))
done

# Editing Info.plist invalidates the applet's ad-hoc signature, so sign it again.
codesign --force --sign - "$wrapper"

mkdir -p "$install_dir"
rm -rf "${install_dir:?}/$app_name"
cp -R "$wrapper" "$install_dir/"
installed="$install_dir/$app_name"

echo "Registering .nupkg/.snupkg and making the app their default..."
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$lsregister" -f "$installed"
# The inner app must not compete for the file types or show up as a second app.
"$lsregister" -u "$installed/Contents/Resources/$app_name" 2>/dev/null || true
swift "$repo_root/scripts/macos/set-default-app.swift" "$installed" nupkg snupkg

echo "Installed: $installed"
echo "Start it with: open -a \"NuGet Package Explorer\" (or double-click a .nupkg)"
