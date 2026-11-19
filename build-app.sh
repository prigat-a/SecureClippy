#!/bin/zsh
# Builds an arm64-only release of Secure Clipboard and packages it as
# "Secure Clipboard.app" in this folder.
set -euo pipefail
cd "${0:A:h}"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/SecureClipboard"

APP="Secure Clipboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SecureClipboard"
cp SecureClipboard/Info.plist "$APP/Contents/Info.plist"
strip -x "$APP/Contents/MacOS/SecureClipboard"

# Ad-hoc signature so macOS will run it locally.
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"
