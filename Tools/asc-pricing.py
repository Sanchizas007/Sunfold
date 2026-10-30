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


def ensure_trial(subscription, name):
    """A worldwide three-day free trial, unless one is already there."""
    existing, _ = asc.get_all(f"/v1/subscriptions/{subscription}/introductoryOffers")
    live = [o for o in existing if o["attributes"].get("offerMode") == "FREE_TRIAL"]
    if live:
        attributes = live[0]["attributes"]
        log(f"  {name}: пробный период уже есть — {attributes.get('duration')}, не трогаю")
        return
    act(f"{name}: создаю пробный период {TRIAL_DURATION}", lambda: asc.request(
        "POST", "/v1/subscriptionIntroductoryOffers", {"data": {
            "type": "subscriptionIntroductoryOffers",
            "attributes": {
                "duration": TRIAL_DURATION,
                "offerMode": "FREE_TRIAL",
                "numberOfPeriods": 1,
            },
            # No territory relationship: that means every storefront.
            "relationships": {"subscription": ref("subscriptions", subscription)},
        }}))


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
    act(f"годовая ${now} → ${YEARLY_PRICE}, существующим подписчикам цена сохраняется",
        lambda: asc.request("POST", "/v1/subscriptionPrices", {"data": {
            "type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": True},
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
    raise_yearly()
    raise_lifetime()
    log("\nГотово." if APPLY else "\nСухой прогон окончен.")


if __name__ == "__main__":
    try:
        main()
    except asc.APIError as error:
        sys.exit(str(error))
