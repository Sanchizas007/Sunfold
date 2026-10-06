#!/usr/bin/env python3
"""Checks the translation tables for the mistakes a human eye slides over.

`build-strings.py` already refuses to build when a key is missing. This looks
for the errors that still produce a valid catalog and a shippable build, and
only show up to a native speaker reading the App Store listing:

  * a format specifier dropped or renumbered, which crashes or prints garbage;
  * an English word left sitting in a translated sentence;
  * text from the wrong script — Hangul in the Japanese file, say.

All three happened while writing these files by hand.

    python3 Tools/check-strings.py
"""

import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "strings")

SPECIFIER = re.compile(r"%(?:\d+\$)?(?:lld|@|%)")
LATIN_RUN = re.compile(r"[A-Za-z]{2,}")

# Proper nouns, matched with their capital letter. The case carries meaning
# here: "Apple Health" is a product name and belongs in Latin script, while a
# lower-case "health" sitting in a Japanese sentence is a line that never got
# translated — which is exactly what this found.
ALLOWED_NAMES = {
    "Sunfold", "Apple", "Health", "App", "Store", "StoreKit", "RevenueCat",
    "Dynamic", "Island", "Pro", "Live", "Activity", "ID", "OK",
}

# Technical tokens that are written in Latin whatever the surrounding script,
# in any case: "push-сервер", "iPhone", "CSV", and `lld` from a specifier.
ALLOWED_TOKENS = {
    "iphone", "ios", "csv", "sdk", "os", "lld", "push", "widget", "widgets",
}

# Which Unicode blocks each language is allowed to draw on, beyond Latin,
# digits and punctuation. A file written in the wrong script is usually a
# fragment pasted from the neighbouring language.
SCRIPTS = {
    "ja": {"HIRAGANA", "KATAKANA", "CJK"},
    "ko": {"HANGUL"},
    "zh-Hans": {"CJK"},
    "zh-Hant": {"CJK"},
    "ru": {"CYRILLIC"},
    "uk": {"CYRILLIC"},
}


def script_of(ch):
    code = ord(ch)
    if 0x3040 <= code <= 0x309F:
        return "HIRAGANA"
    if 0x30A0 <= code <= 0x30FF:
        return "KATAKANA"
    if 0x4E00 <= code <= 0x9FFF or 0x3400 <= code <= 0x4DBF:
        return "CJK"
    if 0xAC00 <= code <= 0xD7A3 or 0x1100 <= code <= 0x11FF:
        return "HANGUL"
    if 0x0400 <= code <= 0x04FF:
        return "CYRILLIC"
    return None


def main() -> int:
    english = json.load(open(os.path.join(SOURCE, "en.json"), encoding="utf-8"))
    problems = 0

    for name in sorted(os.listdir(SOURCE)):
        if not name.endswith(".json"):
            continue
        language = name[: -len(".json")]
        table = json.load(open(os.path.join(SOURCE, name), encoding="utf-8"))
        strings = table["strings"]

        for key, source in english["strings"].items():
            value = strings.get(key)
            if value is None:
                print(f"{language}: {key} is missing")
                problems += 1
                continue

            if sorted(SPECIFIER.findall(source)) != sorted(SPECIFIER.findall(value)):
                print(f"{language}: {key} format specifiers differ from English")
                problems += 1

            if language == "en":
                continue

            allowed = SCRIPTS.get(language)
            if allowed:
                wrong = {
                    script_of(ch) for ch in value
                    if script_of(ch) is not None and script_of(ch) not in allowed
                }
                if wrong:
                    print(f"{language}: {key} contains {', '.join(sorted(wrong))} text")
                    problems += 1

                stray = [
                    word for word in LATIN_RUN.findall(value)
                    if word not in ALLOWED_NAMES and word.lower() not in ALLOWED_TOKENS
                ]
                if stray:
                    print(f"{language}: {key} has untranslated Latin {stray}")
                    problems += 1

    if problems:
        print(f"\n{problems} problem(s)", file=sys.stderr)
        return 1
    print("translation tables look clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
