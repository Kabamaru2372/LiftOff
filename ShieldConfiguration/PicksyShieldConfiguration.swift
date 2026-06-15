//
//  PicksyShieldConfiguration.swift
//  PicksyShieldConfig
//
//  Provides the custom "are you sure?" cover screen shown when the user opens a
//  shielded (tracked) app while Accurate Mode is ON. iOS calls this each time the
//  shield is presented, so we build a FRESH, rotating, context-aware message every
//  time (random line + today's pickup count + localized).
//
//  This extension only READS the App Group (count + language) — reads work in
//  Screen Time extensions; writes happen in the ShieldAction extension instead.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    private let appGroupID = "group.fotiospongas.picksy"

    // MARK: - Overrides

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let isSelf = application.bundleIdentifier == "fotiospongas.dev.UnPluq"
        recordShieldedApp(application, isSelf: isSelf)
        return makeConfiguration(appName: application.localizedDisplayName, isSelf: isSelf)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        let isSelf = application.bundleIdentifier == "fotiospongas.dev.UnPluq"
        recordShieldedApp(application, isSelf: isSelf)
        return makeConfiguration(appName: application.localizedDisplayName, isSelf: isSelf)
    }

    /// Hands the shielded app's token to the ShieldAction extension. For
    /// CATEGORY-shielded apps the action handler only receives the category
    /// token — without this it cannot tell WHICH app the user is opening, so it
    /// had to lift the whole category (unshielding every app in it). iOS renders
    /// the shield right before any button press, so the last-recorded token is
    /// the app being acted on. Best-effort: if this extension's writes are
    /// discarded by the sandbox, ShieldAction falls back to lifting the category.
    private func recordShieldedApp(_ application: Application, isSelf: Bool) {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)

        // Diagnostic marker — written on EVERY shield display, regardless of
        // token availability. Lets the DEV screen distinguish "this extension's
        // writes are discarded" from "the token was nil".
        if let url = container?.appendingPathComponent("shield_config_marker.txt") {
            try? "\(Date().timeIntervalSince1970)".data(using: .utf8)?
                .write(to: url, options: .atomic)
        }

        // Flag whether Picksy itself is being shielded. ShieldAction reads this
        // to always allow access to Picksy without a passcode — the user needs
        // Picksy to manage settings, passcodes, and duel data.
        if let url = container?.appendingPathComponent("picksy_shield_is_self.txt") {
            try? (isSelf ? "true" : "false").data(using: .utf8)?
                .write(to: url, options: .atomic)
        }

        guard let token = application.token,
              let data = try? JSONEncoder().encode(token) else { return }

        // Primary handoff: a FILE in the App Group container. File writes go
        // through a different path than UserDefaults (cfprefsd) and survive in
        // sandboxes where the defaults write is silently dropped. Freshness is
        // checked via the file's modification date on the reader side.
        if let url = container?.appendingPathComponent("last_shield_token.json") {
            try? data.write(to: url, options: .atomic)
        }

        // Secondary: UserDefaults (kept as belt-and-braces where it does work).
        if let d = UserDefaults(suiteName: appGroupID) {
            d.set(data, forKey: "picksy_last_shield_token")
            d.set(Date().timeIntervalSince1970, forKey: "picksy_last_shield_token_ts")
        }
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(appName: nil)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: nil)
    }

    // MARK: - Builder

    private func makeConfiguration(appName: String?, isSelf: Bool = false) -> ShieldConfiguration {
        let indigo = UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0)

        // Picksy itself is being shielded — always show a plain "Open Picksy"
        // button. Never lock the user out of their own management app.
        if isSelf {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: UIColor.black.withAlphaComponent(0.55),
                icon: UIImage(systemName: "hand.raised.fill"),
                title: ShieldConfiguration.Label(text: "Open Picksy", color: .white),
                subtitle: ShieldConfiguration.Label(text: "Manage your settings and goals.", color: UIColor.white.withAlphaComponent(0.8)),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Open", color: .white),
                primaryButtonBackgroundColor: indigo
            )
        }

        let defaults = UserDefaults(suiteName: appGroupID)
        let pickups  = freshPickupCount(defaults: defaults)
        let language = defaults?.string(forKey: "picksy.appLanguage") ?? "English"

        // App Lock: always-on per-app passcode lock, independent of the time limit.
        let appLockEnabled = defaults?.bool(forKey: "picksy_app_lock_enabled") ?? false
        let appLockBlocking = appLockEnabled && !isAppLockUnlocked()

        // If today's time limit has been reached, show the "time's up" variant.
        let timeLimitActive = defaults?.string(forKey: "picksy_timelimit_active") == todayKey()

        // Passcode-locked: time limit reached AND a passcode is required → no
        // bypass button; the user must open Picksy and enter the code.
        let passwordRequired = defaults?.bool(forKey: "picksy_timelimit_password_required") ?? false
        let timeLimitLocked = timeLimitActive && passwordRequired
        let locked = appLockBlocking || timeLimitLocked

        if locked {
            // Show "time limit reached" only when the time limit actually fired.
            // App Lock alone uses a neutral "apps are locked" message.
            let (title, subtitle) = timeLimitLocked
                ? lockedMessage(language: language)
                : appLockMessage(language: language)
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: UIColor.black.withAlphaComponent(0.6),
                icon: UIImage(systemName: "lock.fill"),
                title: ShieldConfiguration.Label(text: title, color: .white),
                subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.8)),
                primaryButtonLabel: ShieldConfiguration.Label(text: lockedButtonLabel(language: language), color: .white),
                primaryButtonBackgroundColor: indigo
            )
        }

        let (title, subtitle) = timeLimitActive
            ? timeLimitMessage(language: language, appName: appName)
            : message(language: language, pickups: pickups, appName: appName)
        let (openText, cancelText) = timeLimitActive
            ? timeLimitButtonLabels(language: language)
            : buttonLabels(language: language)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.55),
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: openText, color: .white),
            primaryButtonBackgroundColor: indigo,
            secondaryButtonLabel: ShieldConfiguration.Label(text: cancelText, color: UIColor.white.withAlphaComponent(0.9))
        )
    }

    private func lockedMessage(language: String) -> (String, String) {
        switch language {
        case "Ελληνικά":
            return ("Κλειδωμένο 🔒", "Έφτασες το όριο χρόνου. Άνοιξε το Picksy και βάλε τον κωδικό για να συνεχίσεις.")
        case "Deutsch":
            return ("Gesperrt 🔒", "Zeitlimit erreicht. Öffne Picksy und gib den Code ein, um fortzufahren.")
        default:
            return ("Locked 🔒", "Time limit reached. Open Picksy and enter the passcode to continue.")
        }
    }

    private func appLockMessage(language: String) -> (String, String) {
        switch language {
        case "Ελληνικά":
            return ("Κλειδωμένο 🔒", "Άνοιξε το Picksy και βάλε τον κωδικό για να ξεκλειδώσεις τις εφαρμογές.")
        case "Deutsch":
            return ("Gesperrt 🔒", "Öffne Picksy und gib den Code ein, um Apps freizuschalten.")
        default:
            return ("Locked 🔒", "Open Picksy and enter your passcode to unlock your apps.")
        }
    }

    private func lockedButtonLabel(language: String) -> String {
        switch language { case "Ελληνικά": return "Εντάξει"; case "Deutsch": return "OK"; default: return "OK" }
    }

    // MARK: - Messages (rotating + context-aware)

    private func message(language: String, pickups: Int, appName: String?) -> (String, String) {
        // CURRENT pickup number — the unlock that brought the user here was
        // already counted (opening an app right after unlocking is the SAME
        // physical pickup; the shared 6s cooldown dedups the tap-through).
        // The old "+1 / this would be your Nth" framing read like opening the
        // app was a brand-new pickup, which it isn't.
        let n = max(pickups, 1)
        let app = appName

        switch language {
        case "Ελληνικά":
            var lines: [(String, String)] = [
                ("Μια ανάσα πριν μπεις 🌿", "Σήκωμα #\(n) σήμερα. Σίγουρα το χρειάζεσαι τώρα;"),
                ("Στάσου ένα δευτερόλεπτο 🤔", "Είσαι στο \(n)ο σήκωμά σου για σήμερα."),
                ("Είσαι παρών; 📱", "Σήκωμα #\(n). Ή μήπως το αφήνεις για μετά;"),
                ("Σκόπιμα ή απ' τη συνήθεια; 🧠", "Αν το θες πραγματικά, προχώρα."),
            ]
            if let app { lines.append(("Σίγουρα θες \(app); 👀", "Είσαι στο \(n)ο σήκωμά σου για σήμερα.")) }
            return lines.randomElement()!
        case "Deutsch":
            var lines: [(String, String)] = [
                ("Kurz durchatmen 🌿", "Griff #\(n) heute. Brauchst du es gerade wirklich?"),
                ("Eine Sekunde warten 🤔", "Du bist bei deinem \(n). Griff heute."),
                ("Bist du präsent? 📱", "Griff #\(n). Oder doch später?"),
                ("Absicht oder Gewohnheit? 🧠", "Wenn du es wirklich willst, mach weiter."),
            ]
            if let app { lines.append(("Wirklich \(app)? 👀", "Du bist bei deinem \(n). Griff heute.")) }
            return lines.randomElement()!
        default:
            var lines: [(String, String)] = [
                ("Take a breath first 🌿", "Pickup #\(n) today. Do you really need it now?"),
                ("Wait a second 🤔", "You're on your \(ordinal(n)) pickup today."),
                ("Are you present? 📱", "Pickup #\(n). Or save it for later?"),
                ("Intention or habit? 🧠", "If you truly want to, go ahead."),
            ]
            if let app { lines.append(("Really open \(app)? 👀", "You're on your \(ordinal(n)) pickup today.")) }
            return lines.randomElement()!
        }
    }

    private func buttonLabels(language: String) -> (String, String) {
        switch language {
        case "Ελληνικά": return ("Άνοιξε", "Άκυρο")
        case "Deutsch":  return ("Öffnen", "Abbrechen")
        default:         return ("Open", "Not now")
        }
    }

    // MARK: - Time-limit variant

    private func timeLimitMessage(language: String, appName: String?) -> (String, String) {
        let app = appName
        switch language {
        case "Ελληνικά":
            let where_ = app.map { "στο \($0)" } ?? "εδώ"
            return ("Έφτασες το όριο χρόνου ⏳", "Πέρασες αρκετή ώρα \(where_) σήμερα. Ώρα για διάλειμμα;")
        case "Deutsch":
            let where_ = app.map { "in \($0)" } ?? "hier"
            return ("Zeitlimit erreicht ⏳", "Du hast heute viel Zeit \(where_) verbracht. Zeit für eine Pause?")
        default:
            let where_ = app.map { "on \($0)" } ?? "here"
            return ("Time limit reached ⏳", "You've spent a while \(where_) today. Time for a break?")
        }
    }

    private func timeLimitButtonLabels(language: String) -> (String, String) {
        switch language {
        case "Ελληνικά": return ("Συνέχισε", "Κλείσε")
        case "Deutsch":  return ("Weiter", "Schließen")
        default:         return ("Continue", "Close")
        }
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Today's pickup count, read FILE-FIRST. This sealed extension's process
    /// can live for hours and its UserDefaults reads come from a per-process
    /// prefs snapshot — the shield was showing counts hours old (19 vs the
    /// app's 25). The writers (DataStore, monitor, ShieldAction) mirror the
    /// count to today_pickups.txt ("yyyy-MM-dd|count"); file reads always hit
    /// disk. We take the max with defaults as belt-and-braces.
    /// Today's pickup count. File-first: the file is written by ShieldAction using
    /// per-day keys (always fresh — new key each day, never holds yesterday's value)
    /// and reset to 0 at midnight by both DataStore and DeviceActivityMonitor.
    /// We do NOT max with the UserDefaults `todayPickups` cache: that cache can hold
    /// yesterday's stale value in long-running extension processes, causing the count
    /// to show e.g. "34" when the real today count is 0 or 1.
    private func freshPickupCount(defaults: UserDefaults?) -> Int {
        let cached = defaults?.integer(forKey: "todayPickups") ?? 0
        guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("today_pickups.txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8)
        else { return cached }
        let parts = raw.split(separator: "|")
        guard parts.count == 2, String(parts[0]) == todayKey(),
              let fileCount = Int(parts[1])
        else { return cached }
        // File is authoritative when its date matches today — do not max with the
        // cached todayPickups value which may be stale from a previous day.
        return fileCount
    }

    private func isAppLockUnlocked() -> Bool {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        if let url = container?.appendingPathComponent("picksy_app_lock_unlock_until.txt"),
           let raw = try? String(contentsOf: url, encoding: .utf8),
           let ts = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return ts > Date().timeIntervalSince1970
        }
        let ts = UserDefaults(suiteName: appGroupID)?.double(forKey: "picksy_app_lock_unlock_until") ?? 0
        return ts > Date().timeIntervalSince1970
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
