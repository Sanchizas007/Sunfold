#!/usr/bin/env python3
"""Composes the App Store frames for Sunfold from raw simulator screens.

    python3 Tools/store-shots.py                 # every locale
    python3 Tools/store-shots.py en de ja        # some of them
    python3 Tools/store-shots.py --only timer    # one frame

Raw screens come from Tools/screenshots.sh (screenshots/<locale>/NN-name.png),
copy from Design/shot-copy.json, section names from the app's own translation
tables, the backdrop from Design/screenshot-background.png. Output goes to
store-shots/<locale>/NN-name.png at 1206x2622, flattened to RGB.

Rendered by headless Chrome rather than drawn with PIL: line breaking in
Japanese, Chinese and Korean, balanced wrapping of long German words and
per-script font fallback are all things a browser already does correctly.

The look is Sunfold's own — a warm serif headline over the owner's peach
backdrop, the phone in a pane of frosted glass that echoes the glass rings in
the picture, and each frame's headline carrying one italic word. It is
deliberately not the layout other apps in the portfolio use.
"""

import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DESIGN = ROOT / "Design"
RAW = ROOT / "screenshots"
OUT = ROOT / "store-shots"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1206, 2622

# Story order, not feature order: the first three frames are what search results
# show, so they carry the product, its difference from every other fasting app,
# and the depth behind it.
FRAMES = [
    # name,       raw screen,        section name (an app string),  text side
    ("timer",     "01-timer",        "tab.timer",                   "left"),
    ("privacy",   "07-privacy",      "privacy.title",               "right"),
    ("phases",    "02-phases",       "phases.title",                "left"),
    ("schedules", "05-protocols",    "protocols.title",             "right"),
    ("history",   "03-history",      "history.title",               "left"),
    ("weight",    "04-weight",       "weight.title",                "right"),
]

# App Store locale folder -> (app language file, CSS lang, serif, sans)
LOCALES = {
    "en":      ("en",      "en",      None, None),
    "de":      ("de",      "de",      None, None),
    "fr":      ("fr",      "fr",      None, None),
    "es-MX":   ("es-MX",   "es",      None, None),
    "es-ES":   ("es-ES",   "es",      None, None),
    "pt-BR":   ("pt-BR",   "pt",      None, None),
    "it":      ("it",      "it",      None, None),
    "nl":      ("nl",      "nl",      None, None),
    "pl":      ("pl",      "pl",      None, None),
    "ru":      ("ru",      "ru",      None, None),
    "uk":      ("uk",      "uk",      None, None),
    "ja":      ("ja",      "ja",      '"Hiragino Mincho ProN"', '"Hiragino Sans"'),
    "ko":      ("ko",      "ko",      '"AppleMyungjo"',         '"Apple SD Gothic Neo"'),
    "zh-Hans": ("zh-Hans", "zh-Hans", '"Songti SC"',            '"PingFang SC"'),
    "zh-Hant": ("zh-Hant", "zh-Hant", '"Songti TC"',            '"PingFang TC"'),
}
CJK = {"ja", "ko", "zh-Hans", "zh-Hant"}


def font_face(name, file, weights, style="normal"):
    return (f'@font-face{{font-family:"{name}";font-style:{style};font-weight:{weights};'
            f'src:url("file://{DESIGN / "fonts" / file}")}}')


KICKER_FULL = {("es-MX", "timer"): "Temporizador", ("es-ES", "timer"): "Temporizador"}


def page(locale, frame, copy, kicker, side):
    kicker = KICKER_FULL.get((locale, frame), kicker)
    lang_file, css_lang, serif, sans = LOCALES[locale]
    cjk = locale in CJK
    headline = copy["h"].replace("\n", "<br>")
    # *word* marks the one accent word of the headline.
    import re
    headline = re.sub(r"\*(.+?)\*", r"<em>\1</em>", headline)

    serif_stack = ", ".join(filter(None, ['"Literata"', serif, "serif"]))
    sans_stack = ", ".join(filter(None, ['"Onest"', sans, "sans-serif"]))
    align = "left" if side == "left" else "right"
    shift = 56 if side == "left" else -56          # the phone leans away from the text

    return f"""<!doctype html><html lang="{css_lang}"><meta charset="utf-8"><style>
{font_face("Literata", "Literata.ttf", "200 900")}
{font_face("Literata", "Literata-Italic.ttf", "200 900", "italic")}
{font_face("Onest", "Onest.ttf", "100 900")}
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;background:#fbe9de url("file://{DESIGN / "screenshot-background.png"}") center/cover no-repeat;
  font-family:{sans_stack};color:#4a2430}}
.copy{{position:absolute;top:706px;left:100px;right:100px;text-align:{align}}}
.kicker{{display:inline-flex;align-items:center;gap:22px;font:600 27px/1 {sans_stack};
  letter-spacing:.2em;text-transform:uppercase;color:#b5586a;margin-bottom:30px;
  flex-direction:{"row" if side == "left" else "row-reverse"}}}
.kicker i{{display:block;width:64px;height:2px;background:#b5586a;opacity:.75}}
h1{{margin:0;font:600 112px/1.06 {serif_stack};letter-spacing:{"0" if cjk else "-.012em"};color:#4a2430;
  text-wrap:balance}}
h1 em{{font-style:{"normal" if cjk else "italic"};font-weight:{700 if cjk else 500};color:#c2566d;
  {"white-space:nowrap;" if cjk else ""}}}
p{{margin:30px 0 0;font:450 44px/1.36 {sans_stack};color:#6e4b54;text-wrap:balance;
  {"margin-left:auto;" if side == "right" else ""}max-width:900px}}
{"p,h1{word-break:keep-all}" if locale == "ko" else ""}
{"p,h1{word-break:auto-phrase}" if locale == "ja" else ""}
.phone{{position:absolute;top:1232px;left:{(W - 868) // 2 + shift}px;width:868px;box-sizing:border-box;
  padding:17px;border-radius:176px;
  background:linear-gradient(150deg,rgba(255,255,255,.82),rgba(255,255,255,.34));
  box-shadow:0 80px 130px -34px rgba(122,44,62,.42),0 0 0 2px rgba(255,255,255,.72) inset,0 0 0 1px rgba(194,86,109,.18)}}
.phone img{{display:block;width:100%;border-radius:160px}}
</style>
<div class="copy">
  <div class="kicker"><i></i>{kicker}</div>
  <h1 id="h">{headline}</h1>
  <p>{copy["s"].replace("|", "<br>")}</p>
</div>
<div class="phone"><img src="file://{RAW / locale_raw(locale, frame)}"></div>
<script>
// Fit: shrink the headline until the whole text block sits above the phone and
// no word is wider than the column. German compounds and long Cyrillic words
// are what this is for.
//
// Waits for the fonts. Measured before they load, the text is set in a fallback
// face with different metrics, the loop sees room that is not there, and the
// real serif then spills its last line under the phone — which is what the
// first full run of this script produced in six locales out of fifteen.
document.fonts.ready.then(function() {{
  const h = document.getElementById('h'), copy = document.querySelector('.copy');
  const limit = {1232 - 706 - 36};
  let size = {112 if not cjk else 104};
  const fits = () => copy.offsetHeight <= limit && h.scrollWidth <= h.clientWidth + 1;
  while (!fits() && size > 58) {{ size -= 2; h.style.fontSize = size + 'px'; }}
  document.title = 'fit:' + size;
}});
</script></script></html>"""


def locale_raw(locale, frame):
    name = {f[0]: f[1] for f in FRAMES}[frame]
    return f"{locale}/{name}.png"


def render(html, out_png):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, dir=OUT) as handle:
        handle.write(html)
        tmp = handle.name
    try:
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", f"--window-size={W},{H}",
                        "--virtual-time-budget=5000", f"--screenshot={out_png}", f"file://{tmp}"],
                       check=True, capture_output=True)
    finally:
        pathlib.Path(tmp).unlink(missing_ok=True)


def flatten(path):
    from PIL import Image
    image = Image.open(path).convert("RGB")
    assert image.size == (W, H), image.size
    image.save(path, "PNG", dpi=(72, 72))


def main():
    args = sys.argv[1:]
    only = None
    if "--only" in args:
        i = args.index("--only"); only = args[i + 1]; del args[i:i + 2]
    locales = args or list(LOCALES)
    copy_all = json.loads((DESIGN / "shot-copy.json").read_text(encoding="utf-8"))
    OUT.mkdir(exist_ok=True)

    for locale in locales:
        lang_file = LOCALES[locale][0]
        strings = json.loads((ROOT / "Tools" / "strings" / f"{lang_file}.json").read_text(encoding="utf-8"))["strings"]
        folder = OUT / locale
        folder.mkdir(exist_ok=True)
        for index, (name, raw, section, side) in enumerate(FRAMES, 1):
            if only and name != only:
                continue
            source = RAW / locale / f"{raw}.png"
            if not source.exists():
                sys.exit(f"missing raw frame: {source}")
            out = folder / f"{index:02d}-{name}.png"
            render(page(locale, name, copy_all[locale][name], strings[section], side), out)
            flatten(out)
            print(f"  {locale}/{out.name}", flush=True)


if __name__ == "__main__":
    main()
