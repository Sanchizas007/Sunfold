#!/usr/bin/env python3
"""Generates Shared/Resources/Localizable.xcstrings from Tools/strings/<lang>.json.

The catalog is machine-generated on purpose. Hand-editing a JSON file of 267
keys across fifteen languages is how strings drift apart; here every language is
one file, every key is one line in it, and a missing translation is a build-time
error rather than a silent fallback to English.

One file per language rather than one row per key: a fifteen-wide tuple cannot
be read or reviewed, and adding a language would have touched every line of the
table. This way a new language is a new file and nothing else moves.

Run after adding or changing any user-facing string:

    python3 Tools/build-strings.py

`--check` reports drift without writing, for a hook or for CI. Run it BEFORE
`git add`, not after.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SOURCE = os.path.join(HERE, "strings")

# CLDR's own order for plural categories.
PLURAL_ORDER = ("zero", "one", "two", "few", "many", "other")

# Order matters only for readability of the generated file; `en` must come first
# because it is the source language.
#
# Spanish ships as two storefront locales: Latin America follows Mexican usage,
# Spain does not, and the App Store indexes them separately. Ukrainian is kept
# even though it is outside the thirteen-language house list — the app already
# had it, and it is the home market.
# Languages that are fully translated and therefore shipped. The list grows one
# entry at a time, together with the file that backs it, so the catalog builds
# and the app is shippable at every commit rather than only at the end.
#
# Target set (house list of thirteen languages, fifteen storefront locales):
#   en de fr es-MX es-ES pt-BR it ja ko ru uk zh-Hans zh-Hant nl pl
#
# Spanish ships as two locales: Latin America follows Mexican usage, Spain does
# not, and the App Store indexes them separately. Ukrainian is outside the house
# list but kept — the app already had it, and it is the home market.
LANGUAGES = (
    "en",
    "de",
    "fr",
    "es-MX",
    "es-ES",
    "pt-BR",
    "it",
    "nl",
    "pl",
    "ja",
    "ru",
    "uk",
)


def load(language: str) -> dict:
    path = os.path.join(SOURCE, f"{language}.json")
    if not os.path.exists(path):
        raise SystemExit(f"missing translation file: {path}")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def build() -> dict:
    tables = {language: load(language) for language in LANGUAGES}

    # English is the reference: every other language must carry exactly its keys.
    # Catching this here is the whole point of generating the catalog — a key
    # that reaches the app untranslated falls back to English silently, and
    # nobody notices until a user does.
    expected = set(tables["en"]["strings"])
    expected_plurals = set(tables["en"].get("plurals", {}))

    for language, table in tables.items():
        missing = expected - set(table["strings"])
        extra = set(table["strings"]) - expected
        if missing:
            raise SystemExit(f"{language}: {len(missing)} keys not translated: {sorted(missing)[:5]}")
        if extra:
            raise SystemExit(f"{language}: {len(extra)} keys not in English: {sorted(extra)[:5]}")
        if set(table.get("plurals", {})) != expected_plurals:
            raise SystemExit(f"{language}: plural keys differ from English")

    strings: dict = {}

    for key in expected:
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                language: {"stringUnit": {"state": "translated", "value": tables[language]["strings"][key]}}
                for language in LANGUAGES
            },
        }

    # Plural categories are per language, not universal: English needs two,
    # Russian, Ukrainian and Polish need four, Japanese, Korean and Chinese need
    # one. Each file declares only the categories its language actually has.
    #
    # Emitted in CLDR order rather than the order the file happens to list them,
    # so the catalog does not churn when a translation file is re-sorted.
    def ordered(forms: dict) -> list:
        return sorted(forms.items(), key=lambda item: PLURAL_ORDER.index(item[0]))

    for key in expected_plurals:
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                language: {
                    "variations": {
                        "plural": {
                            category: {"stringUnit": {"state": "translated", "value": value}}
                            for category, value in ordered(tables[language]["plurals"][key])
                        }
                    }
                }
                for language in LANGUAGES
            },
        }

    return {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}


def main() -> None:
    out = os.path.join(ROOT, "Shared", "Resources", "Localizable.xcstrings")
    rendered = json.dumps(build(), ensure_ascii=False, indent=2) + "\n"

    # Xcode rewrites the catalog on its own whenever the project is open in it,
    # adding keys its scanner finds in code — including the `defaultValue:`
    # literals, which are not keys at all. Twice that churn was picked up by
    # `git add -A` and nearly shipped, buried in an 8000-line diff of a file
    # nobody edited.
    if "--check" in sys.argv:
        current = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
        if current == rendered:
            print("string catalog matches the tables")
            return
        print(
            "string catalog has drifted from Tools/strings/*.json.\n"
            "Run `python3 Tools/build-strings.py` and commit the result.",
            file=sys.stderr,
        )
        raise SystemExit(1)

    with open(out, "w", encoding="utf-8") as handle:
        handle.write(rendered)
    print(f"wrote {len(json.loads(rendered)['strings'])} keys × {len(LANGUAGES)} languages to {out}")


if __name__ == "__main__":
    sys.exit(main())
