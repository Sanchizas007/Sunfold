#!/bin/bash
#
# Shoots the App Store screenshot set: every screen, every locale, no taps.
#
#     Tools/screenshots.sh              # all locales
#     Tools/screenshots.sh en           # just one
#
# Output lands in screenshots/<locale>/ at 1320x2868 — the 6.9" size App Store
# Connect requires. The demo seeder (DEBUG only, launch-argument gated) fills
# the store first, so the frames show a month of history rather than an empty
# app. Every date is relative to launch, so a retake is never stale.
#
# The device is the 6.9" one on purpose: Apple accepts a single 6.9" set and
# scales it down for the smaller sizes, so this is the only set that has to
# exist.
set -euo pipefail

DEVICE="${SUNFOLD_DEVICE:-iPhone 17 Pro Max}"
BUNDLE="app.sunfold"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="${SUNFOLD_DERIVED:-$ROOT/.build/screenshots}"
OUT="$ROOT/screenshots"

# Sheets over the timer (phases, protocols) are shot by asking the timer to
# open them on launch, which is why they are screens here and not tabs.
SCREENS=(timer phases history weight protocols settings)

if [ $# -gt 0 ]; then LOCALES=("$@"); else LOCALES=(en uk ru); fi

locale_id() {
    case "$1" in
        en) echo "en_US" ;;
        uk) echo "uk_UA" ;;
        ru) echo "ru_RU" ;;
        *)  echo "$1" ;;
    esac
}

UDID=$(xcrun simctl list devices available \
    | grep -F "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "No available simulator named '$DEVICE'." >&2; exit 1; }
echo "==> $DEVICE  $UDID"

echo "==> Building"
xcodebuild -project "$ROOT/Sunfold.xcodeproj" -scheme Sunfold -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" build >/dev/null

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Sunfold.app"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP"

# A clean, plausible status bar. Apple rejects shots of a half-empty battery
# and a carrier name that is really "Simulator".
xcrun simctl status_bar "$UDID" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3

for locale in "${LOCALES[@]}"; do
    mkdir -p "$OUT/$locale"
    index=1
    for screen in "${SCREENS[@]}"; do
        xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
        xcrun simctl launch "$UDID" "$BUNDLE" \
            -SunfoldDemoData -SunfoldDemoScreen "$screen" \
            -AppleLanguages "($locale)" -AppleLocale "$(locale_id "$locale")" >/dev/null
        # The seed writes on the main actor before the first frame; the wait is
        # for the sheet presentation animation, which no launch flag skips.
        sleep 3
        file=$(printf "%s/%s/%02d-%s.png" "$OUT" "$locale" "$index" "$screen")
        xcrun simctl io "$UDID" screenshot --type png "$file" 2>/dev/null
        echo "    $locale/$(basename "$file")"
        index=$((index + 1))
    done
done

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
echo "==> Done: $OUT"
