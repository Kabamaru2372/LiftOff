# LiftOff — Be Present

> A gentle nudge to put your phone down.

LiftOff is a minimal iOS app that detects when you pick up your phone and asks one honest question: *do you need this right now?* No judgment, no shaming — just awareness.

---

## What it does

Every time you unlock your phone, LiftOff notices. It shows a timer, tracks your daily pickups, and gently nudges you to be more intentional with your screen time.

---

## Features

**Free**
- Pickup detection via CoreMotion
- Nudge screen with live timer
- Daily pickup counter
- Weekly stats chart
- Daily goal setting
- Quiet hours (no nudges during sleep)
- Live Activity on Lock Screen & Dynamic Island
- Bilingual — English / Greek

**LiftOff Pro** (€4.99 — one time, forever)
- Pickup heatmap by hour of day
- Quote packs (Stoic, Humor, Philosophy)
- Badges & rewards as you improve
- Pay-it-forward gift codes
- Monthly progress reports

---

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI + `@Observable` |
| Motion detection | CoreMotion |
| Lock Screen / Dynamic Island | ActivityKit + WidgetKit |
| Monetization | StoreKit 2 (non-consumable IAP) |
| Storage | UserDefaults |
| Minimum deployment | iOS 17 |

---

## Project structure

```
LiftOff/
├── ContentView.swift          # Tab navigation
├── NudgeView.swift            # Main nudge screen
├── DashboardView.swift        # Stats & weekly chart
├── HeatmapView.swift          # Hourly pickup heatmap (Pro)
├── RewardsView.swift          # Badges & quote packs (Pro)
├── PaywallView.swift          # LiftOff Pro purchase screen
├── SettingsView.swift         # Goals, quiet hours, language
├── ProManager.swift           # StoreKit 2 purchase flow
├── DataStore.swift            # Pickup data & statistics
├── PickupDetector.swift       # CoreMotion pickup detection
├── LiveActivityManager.swift  # Lock Screen / Dynamic Island
├── HourlyTracker.swift        # Per-hour pickup tracking
├── RewardManager.swift        # Badges & reward logic
├── QuoteBank.swift            # Quote collections
└── LiftOffActivityAttributes.swift  # Live Activity data model

LiftOffLive/                   # Widget Extension
└── LiftOffLiveLiveActivity.swift   # Lock Screen & Dynamic Island UI
```

---

## Architecture

LiftOff uses the new `@Observable` macro (iOS 17+) throughout — no `ObservableObject`, no `@Published`. Managers are injected via SwiftUI's `.environment()`.

```swift
// App entry point
WindowGroup {
    ContentView()
        .environment(DataStore())
        .environment(PickupDetector())
        .environment(ProManager.shared)
        .environment(RewardManager())
        .environment(LiveActivityManager())
        .environment(HourlyTracker())
}
```

StoreKit 2 handles all purchases. The `ProManager` listens for `Transaction.updates` in the background — so purchases made on other devices or via family sharing are reflected immediately.

---

## Getting started

```bash
git clone https://github.com/Kabamaru2372/liftoff.git
cd liftoff
open LiftOff.xcodeproj
```

1. Set your own **Bundle Identifier** in target settings
2. Add a **StoreKit Configuration file** for local testing
3. Run on simulator or device (iOS 17+)

> Live Activity and CoreMotion do not work in the simulator — test on a real device for full functionality.

---

## App Store

LiftOff is available on the App Store.

**Bundle ID:** `dev.fotiospongas.liftoff`  
**Version:** 1.0

---

## Author

**Fotios Pongas**  
DevOps & Cloud Engineer — Ironhack Graduate (March 2026)  
[fotiospongas.dev](https://fotiospongas.dev) · [hello@fotiospongas.dev](mailto:hello@fotiospongas.dev)  
[github.com/Kabamaru2372](https://github.com/Kabamaru2372)

---

*Built in one month. Submitted to the App Store in one night.*
