# Picksy — Be Present
> Track your phone pickups. Understand your habits. Be more present.

Picksy is a minimal iOS app that counts every time you pick up your phone and shows you exactly where your time goes. No judgment, no shaming — just honest data and a gentle nudge to be more intentional.

---

## What it does

Every time you unlock your phone, Picksy notices. It tracks your daily pickups, maps them to science-backed zones, shows your app usage time, and gently nudges you when you've been on your phone too long. When you're ready to put it down, it suggests something worth doing instead.

---

## Features

### Free
- Pickup detection via screen unlock monitoring
- Science-backed zone system (Excellent → Problematic)
- Daily pickup counter with progress bar
- Weekly stats chart + streak tracking
- App usage time tracking (via Screen Time API)
- Customizable usage alerts (Light / Moderate / Strict)
- "What should I do?" button with localized activity suggestions
- Real-time weather background (WeatherKit + CoreLocation)
- Live Activity on Lock Screen & Dynamic Island
- Zone notifications with alternative activity suggestions
- Quiet hours (no nudges during sleep)
- Trilingual — English / Greek / German

### Picksy Pro (€4.99 — one time, forever)
- Pickup heatmap by hour of day
- Quote packs (Stoic, Humor, Philosophy)
- Badges & rewards as you improve
- Pay-it-forward gift codes
- Monthly progress reports

---

## Science-backed zones

Based on research from MIT Press (Rosen, 2016), Nottingham Trent University (2020) and Keimyung University (2018):

| Zone | Pickups | Description |
|------|---------|-------------|
| Excellent | 0–50 | Mindful, intentional use |
| Good | 51–100 | Solid, with room to improve |
| Average | 101–150 | Time to pay attention |
| Heavy | 151–200 | Your phone is running the show |
| Problematic | 200+ | Time to make a change |

---

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI + `@Observable` |
| Pickup detection | ScreenUnlockDetector (Darwin notifications) |
| App usage tracking | DeviceActivity + FamilyControls |
| Lock Screen / Dynamic Island | ActivityKit + WidgetKit |
| Weather | WeatherKit + CoreLocation |
| Background sync | Silent Push (APNs) + Supabase Edge Functions |
| Monetization | StoreKit 2 (non-consumable IAP) |
| Storage | UserDefaults + AppGroup |
| Minimum deployment | iOS 17 |

---

## Project structure

```
LiftOff/
├── ContentView.swift                # Tab navigation
├── NudgeView.swift                  # Main idle screen (weather, quote, stats)
├── DashboardView.swift              # Stats & weekly chart
├── AppsView.swift                   # App usage time (DeviceActivity)
├── HeatmapView.swift                # Hourly pickup heatmap (Pro)
├── RewardsView.swift                # Badges & quote packs (Pro)
├── PaywallView.swift                # Picksy Pro purchase screen
├── SettingsView.swift               # Goals, thresholds, quiet hours, language
├── AboutScienceView.swift           # Research references
├── ActivitySuggestionView.swift     # "What should I do?" sheet
│
├── ProManager.swift                 # StoreKit 2 purchase flow
├── DataStore.swift                  # Pickup data & statistics
├── ScreenUnlockDetector.swift       # Pickup detection via Darwin notifications
├── LiveActivityManager.swift        # Lock Screen / Dynamic Island
├── WeatherManager.swift             # WeatherKit + Open-Meteo fallback
├── PushNotificationManager.swift    # APNs device token + silent push handling
├── UsageThresholdManager.swift      # DeviceActivity usage threshold monitoring
├── ZoneNotificationManager.swift    # Zone-based notifications
├── AlternativeActivity.swift        # Activity suggestions with localized links
├── HourlyTracker.swift              # Per-hour pickup tracking
├── RewardManager.swift              # Badges & reward logic
├── QuoteBank.swift                  # Quote collections
└── LiftOffActivityAttributes.swift  # Live Activity data model

LiftOffLive/                         # Widget Extension
└── LiftOffLiveLiveActivity.swift    # Lock Screen & Dynamic Island UI

PicksyDeviceReport/                  # DeviceActivity Report Extension
DeviceActivityMonitor/               # DeviceActivity Monitor Extension
```

---

## Architecture

Picksy uses the `@Observable` macro (iOS 17+) throughout — no `ObservableObject`, no `@Published`. Managers are injected via SwiftUI's `.environment()`.

```swift
WindowGroup {
    ContentView()
        .environment(store)
        .environment(detector)
        .environment(liveActivity)
        .environment(hourlyTracker)
        .environment(rewardManager)
        .environment(proManager)
        .environment(weatherManager)
        .environment(activityPrefs)
}
```

### Background tracking

Picksy uses a Supabase Edge Function + Cron job to send silent APNs pushes every 5 minutes (30 minutes in production). This wakes the app in the background to sync pickup data and update the Live Activity — solving the iOS app suspension problem without battery-draining workarounds.

```
Supabase Cron (every 5 min)
    → Edge Function (Deno/TypeScript)
    → APNs silent push (content-available: 1)
    → iOS wakes Picksy
    → DataStore.syncWithDeviceActivity()
    → LiveActivity.update(pickupCount)
```

---

## Getting started

```bash
git clone https://github.com/Kabamaru2372/liftoff.git
cd liftoff
open LiftOff.xcodeproj
```

1. Set your own **Bundle Identifier** in target settings
2. Enable **Family Controls** capability (requires Apple approval for distribution)
3. Enable **WeatherKit** capability + activate on developer.apple.com (both Capabilities AND App Services tabs)
4. Add a **StoreKit Configuration file** for local testing
5. Set up **Supabase** project with the Edge Function in `/supabase/functions/picksy-silent-push`
6. Run on a real device (iOS 17+)

> Live Activity, ScreenUnlock detection, DeviceActivity and WeatherKit do not work in the simulator — test on a real device.

---

## App Store

Picksy: Be Present is available on the App Store.

**Bundle ID:** `fotiospongas.dev.UnPluq`
**App ID:** 6761116771
**Version:** 1.6 (1.7 in development)

---

## Author

**Fotios Pongas**
DevOps & Cloud Engineer — Ironhack Graduate (March 2026)
[fotiospongas.dev](https://fotiospongas.dev) · [hello@fotiospongas.dev](mailto:hello@fotiospongas.dev)
[github.com/Kabamaru2372](https://github.com/Kabamaru2372)

---

*The average person picks up their phone 186 times a day. What's your number?*
