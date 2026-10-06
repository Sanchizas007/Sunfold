#!/usr/bin/env python3
"""Builds the App Store package and, on request, hands it to Apple.

  python3 Tools/release.py              archive, export, inspect the .ipa
  python3 Tools/release.py --validate   … then ask Apple whether it would accept it (nothing is sent)
  python3 Tools/release.py --upload     … then upload it to App Store Connect

--validate and --upload need ASC_KEY_ID and ASC_ISSUER_ID (see docs/RUNBOOK.md).

Every upload needs a new CURRENT_PROJECT_VERSION: App Store Connect refuses a
build number it has already seen, even from an attempt that failed.

⚠️ Build 1 of 1.0 shipped with an empty RCPublicAPIKey, which meant the release
build refused to sell anything. The package is opened and read here rather than
assumed, and the key is one of the things checked.
"""

import os
import pathlib
import plistlib
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "release"
ARCHIVE = BUILD / "Sunfold.xcarchive"
EXPORT = BUILD / "export"
TEAM = "3M856J997X"


def step(title):
    print(f"\n==> {title}", flush=True)


def run(args, log_name):
    log = BUILD / log_name
    with log.open("w") as handle:
        result = subprocess.run(args, stdout=handle, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        errors = sorted({line.strip() for line in log.read_text().splitlines() if "error" in line.lower()})
        print("\n".join(errors[:12]))
        sys.exit(f"failed, full log: {log}")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    BUILD.mkdir(parents=True, exist_ok=True)

    step("Checks")
    run(["python3", str(ROOT / "Tools" / "build-strings.py"), "--check"], "strings.log")
    print("    string catalog matches Tools/strings/")
    run(["python3", str(ROOT / "Tools" / "check-strings.py")], "translations.log")
    print("    translations clean")
    run(["python3", str(ROOT / "store" / "listing.py")], "listing.log")
    print("    listing within Apple's limits")

    step("Archive")
    subprocess.run(["rm", "-rf", str(ARCHIVE)])
    run(["xcodebuild", "-project", str(ROOT / "Sunfold.xcodeproj"), "-scheme", "Sunfold",
         "-configuration", "Release", "-destination", "generic/platform=iOS",
         "-archivePath", str(ARCHIVE), "archive", "-allowProvisioningUpdates"], "archive.log")
    print(f"    {ARCHIVE.relative_to(ROOT)}")

    step("Export for the App Store")
    options = BUILD / "ExportOptions.plist"
    options.write_bytes(plistlib.dumps({
        "method": "app-store-connect", "destination": "export", "teamID": TEAM,
        "signingStyle": "automatic", "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
    }))
    subprocess.run(["rm", "-rf", str(EXPORT)])
    run(["xcodebuild", "-exportArchive", "-archivePath", str(ARCHIVE), "-exportPath", str(EXPORT),
         "-exportOptionsPlist", str(options), "-allowProvisioningUpdates"], "export.log")
    ipa = next(EXPORT.glob("*.ipa"))
    print(f"    {ipa.relative_to(ROOT)} ({ipa.stat().st_size / 1_048_576:.1f} MB)")

    # Read what actually went into the package instead of assuming it.
    step("What is inside")
    inspect = BUILD / "inspect"
    subprocess.run(["rm", "-rf", str(inspect)])
    with zipfile.ZipFile(ipa) as package:
        package.extractall(inspect)
    app = next((inspect / "Payload").glob("*.app"))
    info = plistlib.loads((app / "Info.plist").read_bytes())
    for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion"):
        print(f"    {key}: {info.get(key)}")

    problems = []

    key = (info.get("RCPublicAPIKey") or "").strip()
    print(f"    RCPublicAPIKey: {'present' if key else '🔴 EMPTY — the build cannot sell anything'}")
    if not key:
        problems.append("no RevenueCat key")

    languages = sorted(path.stem for path in app.glob("*.lproj"))
    print(f"    localisations: {len(languages)} — {', '.join(languages)}")
    if len(languages) < 15:
        problems.append(f"only {len(languages)} localisations in the bundle")

    entitlements = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)],
                                  capture_output=True).stdout
    signed = plistlib.loads(entitlements) if entitlements else {}
    distribution = signed.get("get-task-allow") is False
    print(f"    {'distribution signature ✅' if distribution else '🔴 not a distribution signature'}")
    if not distribution:
        problems.append("not signed for distribution")

    manifests = list(app.rglob("PrivacyInfo.xcprivacy"))
    print(f"    privacy manifests: {len(manifests)}")
    if not manifests:
        problems.append("no privacy manifest")

    if problems:
        sys.exit("package is not fit for the App Store: " + "; ".join(problems))

    if mode not in ("--validate", "--upload"):
        print("\n==> Ready. Next: --validate, then --upload.")
        return

    key_id, issuer = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer:
        sys.exit("set ASC_KEY_ID and ASC_ISSUER_ID")
    action = "--validate-app" if mode == "--validate" else "--upload-app"
    step("Apple's validation (nothing is sent)" if mode == "--validate"
         else "Upload to App Store Connect")
    result = subprocess.run(["xcrun", "altool", action, "-f", str(ipa), "-t", "ios",
                             "--apiKey", key_id, "--apiIssuer", issuer])
    if result.returncode != 0:
        sys.exit("altool failed")
    if mode == "--upload":
        print("\n==> Sent. The build appears in App Store Connect after processing, "
              "usually 5–30 minutes.")


if __name__ == "__main__":
    main()
