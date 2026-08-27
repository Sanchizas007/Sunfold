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
#
# The paywall is deliberately NOT in this list. It is shot separately below and
# saved unnumbered: it carries prices, and a store listing that shows a price
# needs a fresh review every time that price changes. It exists only for the
# "review screenshot" field of an in-app purchase.
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

# Takes one screenshot and reports whether it actually caught the screen.
#
# A fixed sleep is not enough and never was: the app can be slow on its first
# launch after install, the seeder writes before the first frame, and a sheet
# slides in on its own schedule. Waiting longer only moves the race — six of
# twenty-one frames still came out as bare background, and blank frames are
# easy to miss when you are looking at a folder of thumbnails.
#
# So the frame is measured instead. A screen with content has a wide spread of
# brightness; a bare background is flat. Flattens to RGB on success, because
# App Store Connect rejects an alpha channel and blames the dimensions.
shoot() {
    python3 - "$1" <<'CHECK'
import sys
from PIL import Image, ImageStat
path = sys.argv[1]
try:
    im = Image.open(path)
except Exception:
    sys.exit(1)
w, h = im.size
# Ignore the status bar and the tab bar: both carry content on an empty screen.
body = im.convert("L").crop((0, int(h * 0.12), w, int(h * 0.88)))
if ImageStat.Stat(body).stddev[0] < 8:
    sys.exit(1)
im.convert("RGB").save(path, "PNG", dpi=(72, 72))
CHECK
}

# Launches the app on one screen and shoots it, retrying until the frame has
# something on it.
capture() {
    local screen="$1" file="$2"
    local attempt
    for attempt in 1 2 3 4 5 6; do
        xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
        xcrun simctl launch "$UDID" "$BUNDLE" \
            -SunfoldDemoData -SunfoldDemoScreen "$screen" \
            -AppleLanguages "($locale)" -AppleLocale "$(locale_id "$locale")" >/dev/null
        sleep $((2 + attempt))
        xcrun simctl io "$UDID" screenshot --type png "$file" 2>/dev/null
        if shoot "$file"; then
            echo "    $locale/$(basename "$file")"
            return 0
        fi
    done
    echo "    !! $locale/$(basename "$file") came out blank after 6 tries" >&2
    return 1
}

blank=0

for locale in "${LOCALES[@]}"; do
    mkdir -p "$OUT/$locale"
    index=1
    for screen in "${SCREENS[@]}"; do
        file=$(printf "%s/%s/%02d-%s.png" "$OUT" "$locale" "$index" "$screen")
        capture "$screen" "$file" || blank=$((blank + 1))
        index=$((index + 1))
    done

    # The paywall, for the in-app purchase review field. Unnumbered so it can
    # never be mistaken for part of the store set.
    capture paywall "$OUT/$locale/paywall-for-review.png" || blank=$((blank + 1))
done

if [ "$blank" -gt 0 ]; then
    echo "==> $blank frame(s) failed. Do not upload this set." >&2
    exit 1
fi

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
echo "==> Done: $OUT"
