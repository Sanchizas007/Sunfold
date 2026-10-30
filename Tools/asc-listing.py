#!/usr/bin/env python3
"""Pushes the App Store page of Sunfold 1.1 through the App Store Connect API.

    ASC_KEY_ID=… ASC_ISSUER_ID=… python3 Tools/asc-listing.py [--texts-only]

Fifteen locales of name, subtitle, keywords, description, promotional text,
release notes, support and privacy URLs, plus the screenshots from
screenshots/<language>/. Texts live in store/listing/, one file per locale.

Doing this by hand is fifteen forms and a hundred and five file pickers, and the
one time it was done by hand the wrong objects went to review. Safe to re-run:
texts are overwritten with the current ones, and a screenshot set that already
holds the right number of processed shots is left alone.

Still the owner's to do, because the API cannot: App Privacy answers, the age
rating questionnaire for an existing app, and pressing Submit.
"""

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Tools"))
sys.path.insert(0, str(ROOT / "store"))
import asc  # noqa: E402
from listing import LISTING, check  # noqa: E402

BUNDLE_ID = "app.sunfold"
VERSION = "1.2"
COPYRIGHT = "2026 Olexandr Zhovnir"
SITE = "https://sanchizas007.github.io/Sunfold"

# The slot App Store Connect now requires: "iPhone with Dynamic Island (medium
# display)", which takes 1179x2556 or 1206x2622. The API calls it APP_IPHONE_61.
#
# The 1.0 set lived in APP_IPHONE_67 at 1284x2778 and was approved there, but
# Apple has since changed the requirement — a draft holding only that size is
# refused with "one or more screenshots do not meet the requirements and must be
# deleted". Sets of any other display type are removed rather than left behind,
# because a stale one is exactly what that error is about.
DISPLAY_TYPE = "APP_IPHONE_61"

# App Store locale -> the folder Tools/screenshots.sh writes. They differ where
# Apple wants a region and the app's own language codes do not.
SCREENSHOT_FOLDER = {
    "en-US": "en", "de-DE": "de", "fr-FR": "fr", "es-MX": "es-MX", "es-ES": "es-ES",
    "pt-BR": "pt-BR", "it": "it", "ja": "ja", "ko": "ko", "ru": "ru", "uk": "uk",
    "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "nl-NL": "nl", "pl": "pl",
}

# Where each locale's hosted policy lives. English sits at the site root.
POLICY_LANGUAGE = {locale: ("" if folder == "en" else f"/{folder}")
                   for locale, folder in SCREENSHOT_FOLDER.items()}


def ref(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def log(message):
    print(message, flush=True)


def app_id():
    apps = asc.request("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit(f"No app record for {BUNDLE_ID}.")
    return apps[0]["id"]


def editable_version(app):
    """The 1.1 record, created if this is the first run."""
    versions, _ = asc.get_all(f"/v1/apps/{app}/appStoreVersions", params={"filter[platform]": "IOS"})
    for version in versions:
        if version["attributes"].get("versionString") == VERSION:
            state = version["attributes"].get("appStoreState")
            log(f"version {VERSION}: exists, {state}")
            return version["id"]
    log(f"version {VERSION}: creating")
    created = asc.request("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": VERSION, "copyright": COPYRIGHT,
                       "releaseType": "MANUAL"},
        "relationships": {"app": ref("apps", app)}}})
    return created["data"]["id"]


def editable_app_info(app):
    """The app-level record that carries name and subtitle.

    A live app has one in READY_FOR_SALE that cannot be edited and, once a new
    version exists, a second one that can.
    """
    infos, _ = asc.get_all(f"/v1/apps/{app}/appInfos")
    for info in infos:
        if info["attributes"].get("appStoreState") != "READY_FOR_SALE":
            return info["id"]
    sys.exit("No editable app info — create the version first.")


def set_names(info):
    """Name, subtitle and the privacy policy URL, which live per locale here."""
    existing, _ = asc.get_all(f"/v1/appInfos/{info}/appInfoLocalizations")
    by_locale = {item["attributes"]["locale"]: item["id"] for item in existing}
    for locale, fields in LISTING.items():
        attributes = {
            "name": fields["name"],
            "subtitle": fields["subtitle"],
            "privacyPolicyUrl": f"{SITE}{POLICY_LANGUAGE[locale]}/privacy/",
        }
        if locale in by_locale:
            asc.request("PATCH", f"/v1/appInfoLocalizations/{by_locale[locale]}", {"data": {
                "type": "appInfoLocalizations", "id": by_locale[locale], "attributes": attributes}})
            log(f"  name/subtitle {locale}: updated")
        else:
            asc.request("POST", "/v1/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations", "attributes": {"locale": locale, **attributes},
                "relationships": {"appInfo": ref("appInfos", info)}}})
            log(f"  name/subtitle {locale}: created")


def set_texts(version):
    existing, _ = asc.get_all(f"/v1/appStoreVersions/{version}/appStoreVersionLocalizations")
    by_locale = {item["attributes"]["locale"]: item["id"] for item in existing}
    for locale, fields in LISTING.items():
        attributes = {
            "description": fields["description"],
            "keywords": fields["keywords"],
            "promotionalText": fields["promotionalText"],
            "whatsNew": fields["whatsNew"],
            "supportUrl": f"{SITE}{POLICY_LANGUAGE[locale]}/support/",
        }
        if locale in by_locale:
            asc.request("PATCH", f"/v1/appStoreVersionLocalizations/{by_locale[locale]}", {"data": {
                "type": "appStoreVersionLocalizations", "id": by_locale[locale], "attributes": attributes}})
            log(f"  texts {locale}: updated")
        else:
            created = asc.request("POST", "/v1/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **attributes},
                "relationships": {"appStoreVersion": ref("appStoreVersions", version)}}})
            by_locale[locale] = created["data"]["id"]
            log(f"  texts {locale}: created")
    return by_locale


def upload_screenshots(localization, folder):
    files = sorted(path for path in (ROOT / "screenshots" / folder).glob("*.png")
                   if not path.name.startswith("paywall"))
    if not files:
        return "no files"

    sets, _ = asc.get_all(f"/v1/appStoreVersionLocalizations/{localization}/appScreenshotSets")

    # Anything in another display type is left over from an older requirement
    # and blocks submission. The screenshots here are this script's to own.
    for item in sets:
        if item["attributes"]["screenshotDisplayType"] != DISPLAY_TYPE:
            stale, _ = asc.get_all(f"/v1/appScreenshotSets/{item['id']}/appScreenshots")
            for shot in stale:
                asc.request("DELETE", f"/v1/appScreenshots/{shot['id']}")
            asc.request("DELETE", f"/v1/appScreenshotSets/{item['id']}")
            log(f"    removed stale {item['attributes']['screenshotDisplayType']} set")

    screenshot_set = next(
        (item["id"] for item in sets
         if item["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE), None)
    if screenshot_set is None:
        screenshot_set = asc.request("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
            "relationships": {"appStoreVersionLocalization":
                              ref("appStoreVersionLocalizations", localization)}}})["data"]["id"]

    current, _ = asc.get_all(f"/v1/appScreenshotSets/{screenshot_set}/appScreenshots")
    done = [item for item in current
            if item["attributes"].get("assetDeliveryState", {}).get("state") == "COMPLETE"]
    if len(done) == len(files) == len(current):
        return "already there"

    for item in current:
        asc.request("DELETE", f"/v1/appScreenshots/{item['id']}")
    for path in files:
        content = path.read_bytes()
        reservation = asc.request("POST", "/v1/appScreenshots", {"data": {
            "type": "appScreenshots",
            "attributes": {"fileName": path.name, "fileSize": len(content)},
            "relationships": {"appScreenshotSet": ref("appScreenshotSets", screenshot_set)}}})
        asc.upload_asset(reservation, path)
        asc.request("PATCH", f"/v1/appScreenshots/{reservation['data']['id']}", {"data": {
            "type": "appScreenshots", "id": reservation["data"]["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(content).hexdigest()}}})
    return f"uploaded {len(files)}"


def main():
    problems = check()
    if problems:
        sys.exit("store/listing: " + "; ".join(problems))

    app = app_id()
    version = editable_version(app)
    info = editable_app_info(app)

    log("names and subtitles:")
    set_names(info)
    log("version texts:")
    localizations = set_texts(version)

    if "--texts-only" in sys.argv:
        log("screenshots skipped (--texts-only)")
        return
    log("screenshots:")
    for locale, folder in SCREENSHOT_FOLDER.items():
        log(f"  {locale}: {upload_screenshots(localizations[locale], folder)}")
    log("done")


if __name__ == "__main__":
    try:
        main()
    except asc.APIError as error:
        sys.exit(str(error))
