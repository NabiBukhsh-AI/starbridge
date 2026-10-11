#!/bin/bash
# Builds the widget extension and its helper (Package.swift) for arm64 and x86_64, unsigned, into
# widgets/build: StarbridgeWidgets.appex and starbridge-widgets. scripts/widgets.cjs puts them in the
# app and signs them. Needs Xcode's macOS SDK.
# Usage: build.sh <app bundle id> <short version> <bundle version> <App Group>, from the app's Info.plist.
set -euo pipefail
cd "$(dirname "$0")"
id=$1 short=$2 version=$3 group=$4
out=build
rm -rf "$out" && mkdir -p "$out"
flags=(-c release --arch arm64 --arch x86_64 --scratch-path "$out/spm")
swift build "${flags[@]}"
bin=$(swift build "${flags[@]}" --show-bin-path)
appex="$out/StarbridgeWidgets.appex/Contents"
mkdir -p "$appex/MacOS" "$appex/Resources"
cp "$bin/StarbridgeWidgets" "$appex/MacOS/StarbridgeWidgets"
cp "$bin/starbridge-widgets" "$out/starbridge-widgets"
sed -e "s/BUNDLE_ID/$id.widgets/" -e "s/SHORT_VERSION/$short/" -e "s/BUNDLE_VERSION/$version/" -e "s/APP_GROUP/$group/" Info.plist > "$appex/Info.plist"
plutil -lint "$appex/Info.plist" >/dev/null
cp ../../android/app/src/main/res/font/google_sans_flex.ttf "$appex/Resources/GoogleSansFlex.ttf"
