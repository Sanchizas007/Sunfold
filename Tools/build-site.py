#!/usr/bin/env python3
"""Generates the static pages that must exist before Sunfold can be submitted.

    python3 Tools/build-site.py

Output goes to `site/`, ready to drop on any static host:

    site/index.html                landing
    site/privacy/index.html        privacy policy       (en, + one path per language)
    site/health/index.html         health notice        (en, + one path per language)
    site/terms/index.html          licence, points at Apple's standard EULA
    site/support/index.html        support contact
    site/robots.txt, sitemap.xml

The policy and health-notice text is imported from `build-strings.py`, the same
table the app compiles into its own screens. That is the entire point of this
script: App Review compares the hosted policy against the one in the binary, and
two copies maintained by hand drift apart within a release or two.
"""

import html
import importlib.util
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Where the pages will live. Two knobs so the same generator serves both the
# eventual domain and GitHub Pages, which hosts project sites under a
# subdirectory — root-relative links written for a bare domain would all 404
# there.
#
#     SUNFOLD_ORIGIN=https://sanchizas007.github.io SUNFOLD_BASE=/Sunfold \
#         python3 Tools/build-site.py
ORIGIN = os.environ.get("SUNFOLD_ORIGIN", "https://sunfold.app").rstrip("/")
# The support address shown on every page. Overridable because support@sunfold.app
# does not exist until the domain is bought, and a support contact that bounces
# is worse than no site at all.
EMAIL = os.environ.get("SUNFOLD_EMAIL", "support@sunfold.app")
BASE = "/" + os.environ.get("SUNFOLD_BASE", "").strip("/") if os.environ.get("SUNFOLD_BASE") else ""


def load_app_strings():
    """The app's own tables, so the hosted policy and the in-app one cannot drift.

    App Review compares the two, and that is the entire reason this script
    exists rather than a hand-written page.
    """
    path = os.path.join(ROOT, "Tools", "build-strings.py")
    spec = importlib.util.spec_from_file_location("build_strings", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return {language: module.load(language)["strings"] for language in module.LANGUAGES}, module.LANGUAGES


STRINGS, LANGUAGES = load_app_strings()


def tr(key, language):
    """One translation from the app's table."""
    return STRINGS[language][key]


# Copy that only ever appears on the website, never in the app.
def load_site_strings(language):
    """Site-only text: nav, support and terms copy that never appears in the app.

    Kept out of the app's own table deliberately — shipping these in the binary
    would mean nineteen strings per language that no screen ever reads.
    """
    path = os.path.join(ROOT, "Tools", "site-strings", f"{language}.json")
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


SITE = {language: load_site_strings(language) for language in LANGUAGES}


def site(key, language):
    return SITE[language][key]


STYLE = """
:root {
  --canvas: #FBF5EE; --surface: #FFFCF8; --ink: #3B2E27;
  --ink-2: #8B7668; --ink-3: #AE9C8D; --line: #EADCCC; --accent: #B75E3D;
}
@media (prefers-color-scheme: dark) {
  :root {
    --canvas: #211B18; --surface: #2C2421; --ink: #F5EBE1;
    --ink-2: #B09C8E; --ink-3: #87766B; --line: #40352F; --accent: #F2A883;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; padding: 0 20px 64px; background: var(--canvas); color: var(--ink);
  font: 17px/1.65 ui-rounded, -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  -webkit-text-size-adjust: 100%;
}
.wrap { max-width: 680px; margin: 0 auto; }
header { display: flex; flex-wrap: wrap; gap: 12px; align-items: baseline;
  justify-content: space-between; padding: 28px 0 8px; }
.brand { font-weight: 700; font-size: 20px; color: var(--ink); text-decoration: none; }
nav a { color: var(--ink-2); text-decoration: none; margin-left: 14px; font-size: 15px; }
nav a:hover { color: var(--accent); }
h1 { font-size: clamp(28px, 6vw, 38px); line-height: 1.2; margin: 28px 0 12px; }
h2 { font-size: 20px; margin: 32px 0 8px; }
.lede { color: var(--ink-2); font-size: 19px; }
p { margin: 0 0 14px; color: var(--ink-2); }
h2 + p { margin-top: 0; }
a { color: var(--accent); }
.card { background: var(--surface); border: 1px solid var(--line);
  border-radius: 20px; padding: 20px 22px; margin: 22px 0; }
.langs { margin: 28px 0 0; font-size: 15px; }
.langs a { margin-right: 12px; }
.langs .on { color: var(--ink-3); text-decoration: none; }
footer { margin-top: 44px; padding-top: 20px; border-top: 1px solid var(--line);
  color: var(--ink-3); font-size: 14px; }
.button { display: inline-block; background: var(--accent); color: #fff;
  padding: 12px 20px; border-radius: 14px; text-decoration: none; font-weight: 600; }
@media (prefers-color-scheme: dark) { .button { color: #211B18; } }
"""


def prefix(language):
    """URL prefix for a language: English sits at the root."""
    return "" if language == "en" else f"/{language}"


def path(language, slug):
    """Site-root-relative path for links inside the pages."""
    return f"{BASE}{prefix(language)}/{slug}"


def url(language, slug):
    """Absolute URL. Every directory keeps its trailing slash, so canonical,
    hreflang, sitemap and the in-page links all agree — a mismatch there is a
    self-inflicted duplicate-content problem."""
    return f"{ORIGIN}{path(language, slug)}"


def page(language, slug, title, body_html, description):
    """Wraps content in the shared shell, with hreflang for every language."""
    canonical = url(language, slug)
    alternates = "\n    ".join(
        f'<link rel="alternate" hreflang="{lang}" href="{url(lang, slug)}">'
        for lang in LANGUAGES
    )
    nav = "".join(
        f'<a href="{path(language, target)}">{html.escape(site(key, language))}</a>'
        for key, target in (
            ("site.nav.privacy", "privacy/"),
            ("site.nav.health", "health/"),
            ("site.nav.terms", "terms/"),
            ("site.nav.support", "support/"),
        )
    )
    langs = " ".join(
        f'<span class="on">{lang.upper()}</span>'
        if lang == language
        else f'<a href="{path(lang, slug)}">{lang.upper()}</a>'
        for lang in LANGUAGES
    )

    return f"""<!doctype html>
<html lang="{language}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{html.escape(title)}</title>
    <meta name="description" content="{html.escape(description)}">
    <link rel="canonical" href="{canonical}">
    {alternates}
    <link rel="alternate" hreflang="x-default" href="{url('en', slug)}">
    <style>{STYLE}</style>
  </head>
  <body>
    <div class="wrap">
      <header>
        <a class="brand" href="{path(language, '')}">Sunfold</a>
        <nav>{nav}</nav>
      </header>
      {body_html}
      <p class="langs">{langs}</p>
      <footer>© 2026 Sunfold · <a href="mailto:{EMAIL}">{EMAIL}</a></footer>
    </div>
  </body>
</html>
"""


def sections_html(language, keys):
    out = []
    for title_key, body_key in keys:
        out.append(f"<h2>{html.escape(tr(title_key, language))}</h2>")
        out.append(f"<p>{html.escape(tr(body_key, language))}</p>")
    return "\n      ".join(out)


PRIVACY_SECTIONS = [
    ("privacy.stored.title", "privacy.stored.body"),
    ("privacy.notCollected.title", "privacy.notCollected.body"),
    ("privacy.purchases.title", "privacy.purchases.body"),
    ("privacy.notifications.title", "privacy.notifications.body"),
    ("privacy.health.title", "privacy.health.body"),
    ("privacy.deletion.title", "privacy.deletion.body"),
    ("privacy.children.title", "privacy.children.body"),
    ("privacy.changes.title", "privacy.changes.body"),
]

HEALTH_SECTIONS = [
    ("disclaimer.notMedical.title", "disclaimer.notMedical.body"),
    ("disclaimer.askFirst.title", "disclaimer.askFirst.body"),
    ("disclaimer.stop.title", "disclaimer.stop.body"),
    ("disclaimer.eatingDisorders.title", "disclaimer.eatingDisorders.body"),
    ("disclaimer.phases.title", "disclaimer.phases.body"),
]


def write(path, contents):
    full = os.path.join(ROOT, "site", path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as handle:
        handle.write(contents)
    return path


def build():
    written = []

    for language in LANGUAGES:
        base = prefix(language).lstrip("/")
        base = f"{base}/" if base else ""

        # Landing
        body = f"""<h1>Sunfold</h1>
      <p class="lede">{html.escape(site("site.tagline", language))}</p>
      <div class="card">
        <p>{html.escape(tr("privacy.lede", language))}</p>
      </div>"""
        written.append(write(f"{base}index.html", page(
            language, "", "Sunfold", body, site("site.tagline", language))))

        # Privacy policy — text imported from the app's own string table.
        body = f"""<h1>{html.escape(tr("privacy.heading", language))}</h1>
      <p class="lede">{html.escape(tr("privacy.lede", language))}</p>
      {sections_html(language, PRIVACY_SECTIONS)}
      <p><a href="mailto:{EMAIL}">{html.escape(tr("privacy.contact", language))}</a></p>
      <p><small>{html.escape(tr("privacy.updated", language))}</small></p>"""
        written.append(write(f"{base}privacy/index.html", page(
            language, "privacy/", f'{tr("privacy.title", language)} — Sunfold',
            body, tr("privacy.lede", language))))

        # Health notice
        body = f"""<h1>{html.escape(tr("disclaimer.heading", language))}</h1>
      <p class="lede">{html.escape(tr("disclaimer.lede", language))}</p>
      {sections_html(language, HEALTH_SECTIONS)}"""
        written.append(write(f"{base}health/index.html", page(
            language, "health/", f'{tr("disclaimer.title", language)} — Sunfold',
            body, tr("disclaimer.lede", language))))

        # Terms
        body = f"""<h1>{html.escape(site("site.terms.heading", language))}</h1>
      <p class="lede">{html.escape(site("site.terms.lede", language))}</p>
      <p><a class="button" href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">{html.escape(site("site.terms.eula", language))}</a></p>
      <h2>{html.escape(site("site.terms.pricing.title", language))}</h2>
      <p>{html.escape(site("site.terms.pricing.body", language))}</p>"""
        written.append(write(f"{base}terms/index.html", page(
            language, "terms/", f'{site("site.terms.heading", language)} — Sunfold',
            body, site("site.terms.lede", language))))

        # Support
        body = f"""<h1>{html.escape(site("site.support.heading", language))}</h1>
      <p class="lede">{html.escape(site("site.support.lede", language))}</p>
      <div class="card">
        <h2 style="margin-top:0">{html.escape(site("site.support.contact.title", language))}</h2>
        <p>{html.escape(site("site.support.contact.body", language))}</p>
        <p><a class="button" href="mailto:{EMAIL}">{EMAIL}</a></p>
      </div>
      <h2>{html.escape(site("site.support.data.title", language))}</h2>
      <p>{html.escape(site("site.support.data.body", language))}</p>
      <h2>{html.escape(site("site.support.subscription.title", language))}</h2>
      <p>{html.escape(site("site.support.subscription.body", language))}</p>"""
        written.append(write(f"{base}support/index.html", page(
            language, "support/", f'{site("site.support.heading", language)} — Sunfold',
            body, site("site.support.lede", language))))

    # robots + sitemap
    written.append(write(
        "robots.txt",
        f"User-agent: *\nAllow: /\n\nSitemap: {ORIGIN}{BASE}/sitemap.xml\n"
    ))

    urls = []
    for language in LANGUAGES:
        for slug in ("", "privacy/", "health/", "terms/", "support/"):
            urls.append(f"  <url><loc>{url(language, slug)}</loc></url>")
    sitemap = ('<?xml version="1.0" encoding="UTF-8"?>\n'
               '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
               + "\n".join(urls) + "\n</urlset>\n")
    written.append(write("sitemap.xml", sitemap))

    print(f"wrote {len(written)} files to site/")
    for path in written:
        print(f"  {path}")


if __name__ == "__main__":
    sys.exit(build())
