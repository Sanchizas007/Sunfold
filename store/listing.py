#!/usr/bin/env python3
"""The App Store page text, one file per locale, plus the limits Apple enforces.

Kept out of Tools/ because this is copy, not machinery, and it is the part a
human edits. `check()` runs before anything is sent: App Store Connect rejects
an over-long field with a 409 halfway through a run, which leaves the listing
half-updated in some locales and not others.

The English, Russian and Ukrainian entries are the text App Review already
approved for 1.0, pulled back out of App Store Connect rather than retyped.
"""

import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent

# Fifteen storefront locales from thirteen languages: Spanish ships twice
# because Latin American and Castilian usage differ and the App Store indexes
# them separately. Ukrainian is outside the house list but kept — the app
# already had it.
LOCALES = (
    "en-US", "de-DE", "fr-FR", "es-MX", "es-ES", "pt-BR", "it", "ja",
    "ko", "ru", "uk", "zh-Hans", "zh-Hant", "nl-NL", "pl",
)

# Apple's own limits. Exceeding one is a 409 from the API, not a warning.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotionalText": 170,
    "description": 4000,
    "whatsNew": 4000,
}

REQUIRED = ("name", "subtitle", "keywords", "promotionalText", "description")

# Simplified forms that must not appear in the Traditional Chinese listing.
# Building zh-Hant by running replacements over zh-Hans produced text that mixed
# both — "一个安静、温和的間歇性斷食紀錄工具" — which reads as machine output to
# anyone in Taiwan. The listing is written by hand; this makes sure it stays
# that way.
SIMPLIFIED_ONLY = set(
    "断记计这时发实关开过长对业东车门问现说认识让边还进运选适产严书专双变"
    "则刚创动励劳势单卖历厂压厌厅号叶员园国图圆块坚声报备复够头夹奋妇妈学"
    "宝宁审层尽属岁岛币师带帮广应库庆废异录态总恋恶悬惊惯战户扑执扩扫护担"
    "拟据挂挥损换摄敌数斗无旧显晓术机权条来杨极构样标树桥检楼欢汉沟济浅测"
    "渐满滨灵点炼烟热爱牺状独环电画疗监盖确种积称窗竞笔筑简级纪纯纸线练组"
    "细织终绍经给络绝统继续维绿缩网罗职联肃胜脏艺苏范荣药菜萝虑虽补装见观"
    "规觉订议讯讲论设访证评诉词译试诗诚话详语误请读课谁调谈谢赛资赶趋跃轮"
    "软轻较辅输达远连迟逊遗邮郑配锁锅钟银铁销锦镜闭闲闻队阶际陆险随难静韩"
    "页顾顿颗题风飞马验骗"
)


def load(locale):
    path = HERE / "listing" / f"{locale}.json"
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


LISTING = {locale: load(locale) for locale in LOCALES}


def check():
    """Every problem at once, so one run fixes them all rather than one each."""
    problems = []
    for locale, fields in LISTING.items():
        for key in REQUIRED:
            if not fields.get(key):
                problems.append(f"{locale}: {key} is empty")
        for key, limit in LIMITS.items():
            value = fields.get(key)
            if value and len(value) > limit:
                problems.append(f"{locale}: {key} is {len(value)} chars, limit {limit}")
        keywords = fields.get("keywords") or ""
        if ", " in keywords:
            problems.append(f"{locale}: keywords have a space after a comma, which costs characters")
        if locale == "zh-Hant":
            for key in ("name", "subtitle", "description", "whatsNew", "promotionalText"):
                stray = sorted(set(fields.get(key) or "") & SIMPLIFIED_ONLY)
                if stray:
                    problems.append(f"{locale}: {key} has simplified characters {''.join(stray)}")
    return problems


if __name__ == "__main__":
    found = check()
    print("\n".join(found) if found else f"{len(LISTING)} locales, all within limits")
