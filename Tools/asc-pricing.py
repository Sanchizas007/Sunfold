#!/usr/bin/env python3
"""Sets the 1.2 prices and the three-day free trial in App Store Connect.

    ASC_KEY_ID=… ASC_ISSUER_ID=… python3 Tools/asc-pricing.py          # say what it would do
    ASC_KEY_ID=… ASC_ISSUER_ID=… python3 Tools/asc-pricing.py --apply  # do it

Three changes, all of them affecting money, so nothing happens without --apply:

  * a three-day free trial on both subscriptions, worldwide;
  * the yearly subscription from $12.99 to $29.99;
  * the lifetime purchase from its current price to $79.99.

⚠️ The price rise is written with `preserveCurrentPrice`, which keeps every
existing subscriber on the price they signed up at. Without that flag Apple
raises the price for people who are already paying, and they have to agree to it
or be cancelled. The free trial needs no such care: Apple only ever offers an
introductory offer to someone who has never subscribed in the group.
"""

import datetime
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asc  # noqa: E402

APP = "6801442221"
MONTHLY = "6805539549"
YEARLY = "6805538135"

TRIAL_DURATION = "THREE_DAYS"
YEARLY_PRICE = "29.99"
LIFETIME_PRICE = "79.99"
LIFETIME_PRODUCT_ID = "app.sunfold.pro.lifetime"

APPLY = "--apply" in sys.argv


def log(message):
    print(message, flush=True)


def act(what, call):
    if not APPLY:
        log(f"  [сухой прогон] {what}")
        return None
    log(f"  {what}")
    return call()


def ref(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def territories():
    """Every storefront the subscription is sold in.

    One offer per territory, because the API refuses a request without one —
    there is no "worldwide" shorthand, despite the App Store Connect web form
    looking like there is.
    """
    items, _ = asc.get_all("/v1/territories", params={"limit": "200"})
    return [item["id"] for item in items]


def ensure_trial(subscription, name):
    """A three-day free trial in every storefront, skipping any already there."""
    existing, _ = asc.get_all(f"/v1/subscriptions/{subscription}/introductoryOffers",
                              params={"include": "territory", "limit": "200"})
    done = set()
    for offer in existing:
        if offer["attributes"].get("offerMode") != "FREE_TRIAL":
            continue
        link = offer.get("relationships", {}).get("territory", {}).get("data") or {}
        done.add(link.get("id"))

    wanted = territories()
    missing = [t for t in wanted if t not in done]
    if not missing:
        log(f"  {name}: пробный период уже во всех {len(wanted)} витринах")
        return
    if not APPLY:
        log(f"  [сухой прогон] {name}: создам {TRIAL_DURATION} в {len(missing)} витринах "
            f"(из {len(wanted)}; уже есть в {len(done)})")
        return

    log(f"  {name}: создаю {TRIAL_DURATION} в {len(missing)} витринах")
    failed = []
    for index, territory in enumerate(missing, 1):
        try:
            asc.request("POST", "/v1/subscriptionIntroductoryOffers", {"data": {
                "type": "subscriptionIntroductoryOffers",
                "attributes": {
                    "duration": TRIAL_DURATION,
                    "offerMode": "FREE_TRIAL",
                    "numberOfPeriods": 1,
                },
                "relationships": {
                    "subscription": ref("subscriptions", subscription),
                    "territory": ref("territories", territory),
                },
            }})
        except asc.APIError as error:
            # A storefront the subscription is not sold in refuses the offer.
            # That is expected, not a failure of the run.
            failed.append((territory, error.status))
        if index % 40 == 0:
            log(f"    {index}/{len(missing)}")
    log(f"    создано {len(missing) - len(failed)}, отказано {len(failed)}")
    if failed:
        log(f"    отказы: {', '.join(t for t, _ in failed[:12])}"
            + (" …" if len(failed) > 12 else ""))


def price_point(subscription, price):
    """The price-point id for a given customer price in the United States."""
    points, _ = asc.get_all(
        f"/v1/subscriptions/{subscription}/pricePoints",
        params={"filter[territory]": "USA", "limit": "200"})
    for point in points:
        if point["attributes"].get("customerPrice") == price:
            return point["id"]
    raise SystemExit(f"нет точки цены {price} — доступно: "
                     + ", ".join(sorted({p['attributes'].get('customerPrice') for p in points})[:20]))


def current_price(subscription):
    prices, included = asc.get_all(
        f"/v1/subscriptions/{subscription}/prices",
        params={"include": "subscriptionPricePoint", "filter[territory]": "USA", "limit": "10"})
    points = {i["id"]: i for i in included if i["type"] == "subscriptionPricePoints"}
    for price in prices:
        link = price.get("relationships", {}).get("subscriptionPricePoint", {}).get("data", {})
        point = points.get(link.get("id", ""), {}).get("attributes", {})
        if point.get("customerPrice"):
            return point["customerPrice"]
    return None


def raise_yearly():
    now = current_price(YEARLY)
    log(f"  годовая сейчас: ${now}")
    if now == YEARLY_PRICE:
        log("  уже на новой цене, не трогаю")
        return
    point = price_point(YEARLY, YEARLY_PRICE)
    # A `startDate` is what makes this a scheduled change rather than a second
    # attempt at the initial price, which an approved subscription refuses:
    # "Initial price cannot be created again after subscription is approved."
    start = (datetime.date.today() + datetime.timedelta(days=1)).isoformat()
    act(f"годовая ${now} → ${YEARLY_PRICE} с {start}, "
        f"существующим подписчикам цена сохраняется",
        lambda: asc.request("POST", "/v1/subscriptionPrices", {"data": {
            "type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": True, "startDate": start},
            "relationships": {
                "subscription": ref("subscriptions", YEARLY),
                "subscriptionPricePoint": ref("subscriptionPricePoints", point),
            },
        }}))


def lifetime_id():
    iaps, _ = asc.get_all(f"/v1/apps/{APP}/inAppPurchasesV2")
    for iap in iaps:
        if iap["attributes"].get("productId") == LIFETIME_PRODUCT_ID:
            return iap["id"]
    raise SystemExit("разовая покупка не найдена")


def raise_lifetime():
    purchase = lifetime_id()
    points, _ = asc.get_all(f"/v2/inAppPurchases/{purchase}/pricePoints",
                            params={"filter[territory]": "USA", "limit": "200"})
    point = next((p["id"] for p in points
                  if p["attributes"].get("customerPrice") == LIFETIME_PRICE), None)
    if point is None:
        raise SystemExit(f"нет точки цены {LIFETIME_PRICE} для разовой покупки")
    act(f"разовая → ${LIFETIME_PRICE}", lambda: asc.request(
        "POST", "/v1/inAppPurchasePriceSchedules", {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": ref("inAppPurchases", purchase),
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${new}"}]},
                    "baseTerritory": ref("territories", "USA"),
                },
            },
            "included": [{
                "type": "inAppPurchasePrices",
                "id": "${new}",
                "attributes": {"startDate": None},
                "relationships": {
                    "inAppPurchaseV2": ref("inAppPurchases", purchase),
                    "inAppPurchasePricePoint": ref("inAppPurchasePricePoints", point),
                },
            }],
        }))


def main():
    if not APPLY:
        log("Сухой прогон. Ничего не меняется. Добавьте --apply, чтобы применить.\n")
    log("Пробный период:")
    ensure_trial(MONTHLY, "месячная")
    ensure_trial(YEARLY, "годовая")
    log("\nЦены:")
    # Each step reports its own failure and the run continues: one refusal
    # should not hide whether the other change went through.
    for step in (raise_yearly, raise_lifetime):
        try:
            step()
        except asc.APIError as error:
            log(f"  🔴 не удалось: {str(error)[:200]}")
    log("\nГотово." if APPLY else "\nСухой прогон окончен.")


if __name__ == "__main__":
    try:
        main()
    except asc.APIError as error:
        sys.exit(str(error))
