# RCBar

A tiny macOS menu bar app that shows your App Store earnings from [RevenueCat](https://www.revenuecat.com):

- **Menu bar:** proceeds accumulated in the current Apple fiscal month — the amount growing toward a future payout.
- **Menu:**
  - **Next payout:** date, amount, and the fiscal period it covers.
  - **Latest event:** the most recent change in proceeds, e.g. `+€4.99 · 10:42`.

Single Swift file, no dependencies. Requires macOS 13+.

## Install

```sh
git clone https://github.com/gmoraleda/RCBar.git
cd RCBar
./make-app.sh
```

This builds `~/Applications/RCBar.app`, launches it, and registers it as a login item. You can turn launch at login off from the menu.

## Configure

Create a RevenueCat **API v2 secret key** under Project settings → API keys, with read access to:

- Charts & Metrics (overview + charts)
- Project configuration → Projects (only needed if you omit `projectId`)

Save it to `~/.config/rcbar/config.json` (`chmod 600` it):

```json
{ "apiKey": "sk_...", "projectId": "proj...", "currency": "EUR" }
```

`projectId` and `currency` are optional. Without a `projectId` the app uses the first project the key can access, and `currency` defaults to EUR. Then pick **Refresh** (⌘R) in the menu. The app polls every 5 minutes.

## How it works

- **Amounts:** RevenueCat's `metrics/revenue` endpoint with `revenue_type=proceeds`, i.e. after store commission and taxes.
- **Payout dates:** computed from Apple's fiscal calendar.
  - Each fiscal year ends on the last Saturday of September.
  - Fiscal months follow a 5-4-4 week pattern. In a 53-week year, December gets the extra week.
  - Payout is about 33 days after the end of the fiscal month.
- **Latest event:** RevenueCat's API has no "list transactions" endpoint. The app diffs the running total between polls, so it shows the amount and roughly when, but not the product or customer. Two sales within one poll show as a single amount.

## Caveats

- Apple pays in local currencies at its own exchange rates and applies payment thresholds, so the actual payout will differ slightly.
- The authoritative fiscal calendar is in App Store Connect → Payments and Financial Reports.

## Development

```sh
swift run RCBar --selftest   # fiscal-calendar and event-diff checks
```
