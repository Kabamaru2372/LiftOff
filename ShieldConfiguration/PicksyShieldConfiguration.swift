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
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(appName: nil)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: nil)
    }

    // MARK: - Builder

    private func makeConfiguration(appName: String?) -> ShieldConfiguration {
        let defaults = UserDefaults(suiteName: appGroupID)
        let pickups  = defaults?.integer(forKey: "todayPickups") ?? 0
        let language = defaults?.string(forKey: "picksy.appLanguage") ?? "English"

        let (title, subtitle) = message(language: language, pickups: pickups, appName: appName)
        let (openText, cancelText) = buttonLabels(language: language)

        let indigo = UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0)

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

    // MARK: - Messages (rotating + context-aware)

    private func message(language: String, pickups: Int, appName: String?) -> (String, String) {
        // Next pickup number if they proceed.
        let n = pickups + 1
        let app = appName

        switch language {
        case "Ελληνικά":
            var lines: [(String, String)] = [
                ("Μια ανάσα πριν μπεις 🌿", "Σήκωμα #\(n) σήμερα. Σίγουρα το χρειάζεσαι τώρα;"),
                ("Στάσου ένα δευτερόλεπτο 🤔", "Θα γίνει το \(n)ο σήκωμά σου σήμερα."),
                ("Είσαι παρών; 📱", "Σήκωμα #\(n). Ή μήπως το αφήνεις για μετά;"),
                ("Σκόπιμα ή απ' τη συνήθεια; 🧠", "Αν το θες πραγματικά, προχώρα."),
            ]
            if let app { lines.append(("Σίγουρα θες \(app); 👀", "Θα είναι το \(n)ο σήκωμά σου σήμερα.")) }
            return lines.randomElement()!
        case "Deutsch":
            var lines: [(String, String)] = [
                ("Kurz durchatmen 🌿", "Griff #\(n) heute. Brauchst du es gerade wirklich?"),
                ("Eine Sekunde warten 🤔", "Das wäre dein \(n). Griff heute."),
                ("Bist du präsent? 📱", "Griff #\(n). Oder doch später?"),
                ("Absicht oder Gewohnheit? 🧠", "Wenn du es wirklich willst, mach weiter."),
            ]
            if let app { lines.append(("Wirklich \(app)? 👀", "Das wäre dein \(n). Griff heute.")) }
            return lines.randomElement()!
        default:
            var lines: [(String, String)] = [
                ("Take a breath first 🌿", "Pickup #\(n) today. Do you really need it now?"),
                ("Wait a second 🤔", "This would be your \(ordinal(n)) pickup today."),
                ("Are you present? 📱", "Pickup #\(n). Or save it for later?"),
                ("Intention or habit? 🧠", "If you truly want to, go ahead."),
            ]
            if let app { lines.append(("Really open \(app)? 👀", "This would be your \(ordinal(n)) pickup today.")) }
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
