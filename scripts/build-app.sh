#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$project_root/dist/TopDown.app"
contents_path="$app_path/Contents"

swift build --package-path "$project_root" -c release

if [[ -d "$app_path" ]]; then
  rm -r "$app_path"
fi
mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
cp "$project_root/.build/release/TopDown" "$contents_path/MacOS/TopDown"
cp "$project_root/macos/Info.plist" "$contents_path/Info.plist"
codesign --force --deep --sign - "$app_path"

echo "$app_path"
