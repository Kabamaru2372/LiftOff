// ScreenTimeMilestoneNotifier.swift
// Picksy
//
// Fires a "what you could have done instead" notification the moment
// the user's cumulative screen time crosses a milestone (1h, 2h, 3h).
//
// Messages are specific, vivid, and context-aware:
//   • Weather-gated   — no outdoor suggestions when raining/snowing/foggy
//   • Time-gated      — no "cook Sunday feast" at midnight
//   • One per milestone per calendar day (resets automatically at midnight)
//
// Hook: call checkAndFire() from LiftOffApp.onScreenSessionEnded
// after store.addUsageTime() so the total is already updated.

import Foundation
import UserNotifications

// MARK: - Notifier

final class ScreenTimeMilestoneNotifier {

    static let shared = ScreenTimeMilestoneNotifier()
    private init() {}

    // Milestones in minutes
    private let milestones = [60, 120, 180]

    // UserDefaults keys
    private let firedKey     = "picksy.screenTimeMilestones.fired"
    private let scheduledKey = "picksy.screenTimeMilestones.scheduled"

    // App Group shared with DeviceActivityMonitor extension.
    // The extension fires the *accurate* notification (real Apple usage), but we
    // pre-compute the smart, weather/time-aware message here and hand it over.
    static let appGroupID = "group.fotiospongas.picksy"
    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: Self.appGroupID) }

    // MARK: - Public

    /// Cancels any pending (not yet fired) milestone notifications and clears
    /// the scheduledToday map so they will be re-scheduled on the next unlock.
    /// Call this when the screen locks so the notification fires while the
    /// user is actively using the phone, not minutes later from the lock screen.
    func cancelPending() {
        let identifiers = milestones.map { "picksy.milestone.\($0)" }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)

        // Clear scheduledToday so scheduleUpcoming() will re-schedule on next unlock
        let todayStr = todayKey()
        var scheduledMap = UserDefaults.standard.dictionary(forKey: scheduledKey) as? [String: [Int]] ?? [:]
        scheduledMap[todayStr] = []
        UserDefaults.standard.set(scheduledMap, forKey: scheduledKey)
        print("[Milestone] 🗑 Cancelled pending milestone notifications (screen locked)")
    }

    /// Call on app launch and every time the app returns to foreground.
    /// Pre-schedules milestone notifications using UNTimeIntervalNotificationTrigger
    /// so they fire even when the user is on TikTok / Instagram (app in background).
    func scheduleUpcoming(
        totalSeconds: Int,
        weather: WeatherCondition,
        language: String
    ) {
        let todayStr = todayKey()
        var firedMap     = UserDefaults.standard.dictionary(forKey: firedKey)     as? [String: [Int]] ?? [:]
        var scheduledMap = UserDefaults.standard.dictionary(forKey: scheduledKey) as? [String: [Int]] ?? [:]
        var firedToday     = firedMap[todayStr]     ?? []
        var scheduledToday = scheduledMap[todayStr] ?? []

        for milestone in milestones {
            guard !firedToday.contains(milestone) else { continue }
            guard !scheduledToday.contains(milestone) else { continue }

            let remaining = milestone * 60 - totalSeconds

            if remaining <= 0 {
                // Already crossed (e.g. app reopened after long session) — fire in 3s
                firedToday.append(milestone)
                firedMap[todayStr] = firedToday
                UserDefaults.standard.set(firedMap, forKey: firedKey)
                let activity = pickActivity(minutes: milestone, weather: weather)
                deliver(milestone: milestone, activity: activity, language: language, delay: 3)
            } else {
                // Upcoming — schedule now so iOS fires it at the right wall-clock time
                // even while the user is using a different app (TikTok, Instagram, etc.)
                scheduledToday.append(milestone)
                scheduledMap[todayStr] = scheduledToday
                UserDefaults.standard.set(scheduledMap, forKey: scheduledKey)
                let activity = pickActivity(minutes: milestone, weather: weather)
                deliver(milestone: milestone, activity: activity, language: language, delay: TimeInterval(remaining))
                print("[Milestone] 📅 Scheduled \(milestone)min alert in \(remaining)s (~\(remaining/60)min from now)")
            }
        }
    }

    /// Fallback: call after store.addUsageTime(). Catches milestones that were never
    /// pre-scheduled (first install, reboot cleared pending notifications, etc.).
    func checkAndFire(
        totalSeconds: Int,
        weather: WeatherCondition,
        language: String
    ) {
        let totalMin = totalSeconds / 60
        let todayStr = todayKey()
        var firedMap     = UserDefaults.standard.dictionary(forKey: firedKey)     as? [String: [Int]] ?? [:]
        var scheduledMap = UserDefaults.standard.dictionary(forKey: scheduledKey) as? [String: [Int]] ?? [:]
        var firedToday     = firedMap[todayStr]     ?? []
        var scheduledToday = scheduledMap[todayStr] ?? []

        for milestone in milestones {
            guard totalMin >= milestone, !firedToday.contains(milestone) else { continue }

            // Mark as fired and deliver immediately (cancel any stale pre-scheduled request first)
            firedToday.append(milestone)
            firedMap[todayStr] = firedToday
            scheduledToday.removeAll { $0 == milestone }
            scheduledMap[todayStr] = scheduledToday
            UserDefaults.standard.set(firedMap,     forKey: firedKey)
            UserDefaults.standard.set(scheduledMap, forKey: scheduledKey)
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["picksy.milestone.\(milestone)"])
            let activity = pickActivity(minutes: milestone, weather: weather)
            deliver(milestone: milestone, activity: activity, language: language, delay: 2)
            print("[Milestone] 🔔 \(milestone)min milestone fired at session end")
        }
    }

    // MARK: - App Group bridge (accurate, background firing)

    /// Pre-computes the smart, weather/time-aware milestone message for each of
    /// the three usage-threshold levels and writes it to the App Group, so the
    /// DeviceActivityMonitor extension can deliver it at the *real* moment Apple
    /// reports the usage threshold was crossed — in the background, with no
    /// wall-clock guessing and no app foregrounding required.
    ///
    /// Call on app launch and on every foreground (we have weather + language then).
    /// The level → displayed minutes mapping follows the user's chosen preset
    /// (light/moderate/strict); the message bucket uses the nearest bank tier
    /// (level 1 → 1h pool, level 2 → 2h pool, level 3 → 3h pool).
    func syncMilestonesToAppGroup(weather: WeatherCondition, language: String) {
        guard let defaults = sharedDefaults else { return }

        // Decoupled from ThresholdPreset (which lives in a target this file does
        // not belong to) — read the raw preset and map to minutes locally. Must
        // stay in sync with ThresholdPreset.thresholds in UsageThresholdManager.
        let presetMinutes: (Int, Int, Int)
        switch UserDefaults.standard.string(forKey: "picksyThresholdPreset") ?? "light" {
        case "moderate": presetMinutes = (45, 90, 120)
        case "strict":   presetMinutes = (30, 60, 90)
        default:         presetMinutes = (60, 120, 180)   // light (research-backed)
        }
        let levels: [(level: Int, minutes: Int, bucket: Int)] = [
            (1, presetMinutes.0, 60),
            (2, presetMinutes.1, 120),
            (3, presetMinutes.2, 180),
        ]

        defaults.set(language, forKey: "picksy.appLanguage")

        for entry in levels {
            let activity = pickActivity(minutes: entry.bucket, weather: weather)
            let (title, body) = milestoneStrings(minutes: entry.minutes,
                                                 activity: activity,
                                                 language: language)
            let p = "picksy_milestone_\(entry.level)_"
            defaults.set(entry.minutes, forKey: p + "minutes")
            defaults.set(title,         forKey: p + "title")
            defaults.set(body,          forKey: p + "body")
            defaults.set(activity.bodyEN, forKey: p + "bodyEN")
            defaults.set(activity.bodyGR, forKey: p + "bodyGR")
            defaults.set(activity.bodyDE, forKey: p + "bodyDE")
            if let link = activity.link {
                defaults.set(link.absoluteString, forKey: p + "link")
            } else {
                defaults.removeObject(forKey: p + "link")
            }
        }
    }

    /// Builds the localized (title, body) pair — single source of truth shared by
    /// both the local `deliver()` path and the App Group bridge.
    private func milestoneStrings(minutes: Int, activity: MilestoneActivity, language: String) -> (String, String) {
        let hours = minutes / 60
        let mins  = minutes % 60
        switch language {
        case "Ελληνικά":
            let title = hours > 0 && mins == 0
                ? "\(hours) \(hours == 1 ? "ώρα" : "ώρες") στις apps σου 📱"
                : "\(minutes) λεπτά στις apps σου 📱"
            return (title, "Σε αυτόν τον χρόνο μπορούσες να \(activity.bodyGR).")
        case "Deutsch":
            let title = hours > 0 && mins == 0
                ? "\(hours) \(hours == 1 ? "Stunde" : "Stunden") in deinen Apps 📱"
                : "\(minutes) Minuten in deinen Apps 📱"
            return (title, "In dieser Zeit hättest du \(activity.bodyDE) können.")
        default:
            let label = hours == 1 ? "1 hour" : hours > 1 ? "\(hours) hours" : "\(minutes) min"
            return ("\(label) on your apps today 📱", "In that time you could have \(activity.bodyEN).")
        }
    }

    // MARK: - Private

    private func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func deliver(milestone: Int, activity: MilestoneActivity, language: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "PICKSY_SCREEN_TIME_MILESTONE"

        let hours = milestone / 60
        let mins  = milestone % 60

        switch language {
        case "Ελληνικά":
            content.title = hours > 0 && mins == 0
                ? "\(hours) \(hours == 1 ? "ώρα" : "ώρες") στις apps σου 📱"
                : "\(milestone) λεπτά στις apps σου 📱"
            content.body = "Σε αυτόν τον χρόνο μπορούσες να \(activity.bodyGR)."

        case "Deutsch":
            content.title = hours > 0 && mins == 0
                ? "\(hours) \(hours == 1 ? "Stunde" : "Stunden") in deinen Apps 📱"
                : "\(milestone) Minuten in deinen Apps 📱"
            content.body = "In dieser Zeit hättest du \(activity.bodyDE) können."

        default:
            let label = hours == 1 ? "1 hour" : hours > 1 ? "\(hours) hours" : "\(milestone) min"
            content.title = "\(label) on your apps today 📱"
            content.body  = "In that time you could have \(activity.bodyEN)."
        }

        // Pass all activity data through userInfo so MilestoneDetailView can reconstruct it
        var info: [AnyHashable: Any] = [
            "milestoneMinutes": milestone,
            "milestoneBodyEN":  activity.bodyEN,
            "milestoneBodyGR":  activity.bodyGR,
            "milestoneBodyDE":  activity.bodyDE
        ]
        if let link = activity.link { info["milestoneLink"] = link.absoluteString }
        content.userInfo = info

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: "picksy.milestone.\(milestone)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { err in
            if let err { print("[Milestone] ❌ \(err.localizedDescription)") }
            else       { print("[Milestone] 🔔 Queued \(milestone)min notification (fires in \(Int(delay))s)") }
        }
    }

    private func pickActivity(minutes: Int, weather: WeatherCondition) -> MilestoneActivity {
        let hour = Calendar.current.component(.hour, from: Date())
        let isGoodWeather = weather == .sunny || weather == .partlyCloudy || weather == .windy

        let pool = MilestoneActivityBank.activities.filter { a in
            guard a.durationMinutes == minutes else { return false }
            if a.requiresGoodWeather && !isGoodWeather { return false }
            if let range = a.allowedHourRange, !range.contains(hour) { return false }
            return true
        }

        // Fallback: ignore time gate but still respect weather gate
        if let pick = pool.randomElement() { return pick }

        let weatherPool = MilestoneActivityBank.activities.filter {
            $0.durationMinutes == minutes && (!$0.requiresGoodWeather || isGoodWeather)
        }
        return weatherPool.randomElement()
            ?? MilestoneActivityBank.activities.first(where: { $0.durationMinutes == minutes })
            ?? MilestoneActivityBank.activities[0]
    }
}

// MARK: - Model

struct MilestoneActivity {
    let durationMinutes: Int
    let bodyEN: String
    let bodyGR: String
    let bodyDE: String
    let requiresGoodWeather: Bool
    let allowedHourRange: ClosedRange<Int>?
    let link: URL?

    init(
        _ minutes: Int,
        en: String, gr: String, de: String,
        outdoorOnly: Bool = false,
        hours: ClosedRange<Int>? = nil,
        link: String? = nil
    ) {
        durationMinutes     = minutes
        bodyEN              = en
        bodyGR              = gr
        bodyDE              = de
        requiresGoodWeather = outdoorOnly
        allowedHourRange    = hours
        self.link           = link.flatMap { URL(string: $0) }
    }
}

// MARK: - Bank

enum MilestoneActivityBank {

    static let activities: [MilestoneActivity] = [

        // ─────────────────────────────────────
        // 1 HOUR  (60 min)
        // ─────────────────────────────────────

        .init(60,
            en: "baked a batch of banana bread from scratch 🍌",
            gr: "φτιάξεις μπανανόψωμο από την αρχή 🍌",
            de: "einen Bananenkuchen von Grund auf gebacken 🍌",
            link: "https://www.allrecipes.com/"),

        .init(60,
            en: "called 3 friends you've been meaning to catch up with ☎️",
            gr: "πάρεις 3 φίλους που δεν μιλάτε καιρό ☎️",
            de: "3 Freunde angerufen, bei denen du dich längst melden wolltest ☎️"),

        .init(60,
            en: "read 50 pages of a book you've been ignoring 📖",
            gr: "διαβάσεις 50 σελίδες από το βιβλίο που περιμένει 📖",
            de: "50 Seiten in einem Buch gelesen, das du ignoriert hast 📖",
            link: "https://www.goodreads.com/"),

        .init(60,
            en: "done a full yoga or stretch session at home 🧘",
            gr: "κάνεις μια ολοκληρωμένη yoga ή stretching session 🧘",
            de: "eine vollständige Yoga- oder Dehnsession zu Hause gemacht 🧘",
            link: "https://www.youtube.com/results?search_query=1+hour+yoga+for+beginners"),

        .init(60,
            en: "cooked a proper meal completely from scratch 🍳",
            gr: "μαγειρέψεις ένα σωστό γεύμα από την αρχή 🍳",
            de: "eine richtige Mahlzeit von Grund auf gekocht 🍳",
            link: "https://www.allrecipes.com/recipes/"),

        .init(60,
            en: "written 500 words of that thing you keep putting off ✍️",
            gr: "γράψεις 500 λέξεις για αυτό που αναβάλλεις ✍️",
            de: "500 Wörter von dem geschrieben, das du immer aufziehst ✍️",
            link: "https://750words.com"),

        .init(60,
            en: "cleared and reorganised your entire bedroom ✨",
            gr: "καθαρίσεις και οργανώσεις ολόκληρη την κρεβατοκάμαρά σου ✨",
            de: "dein gesamtes Schlafzimmer aufgeräumt und neu organisiert ✨"),

        .init(60,
            en: "learned a new recipe and actually cooked it 👨‍🍳",
            gr: "μάθεις μια νέα συνταγή και να την φτιάξεις αμέσως 👨‍🍳",
            de: "ein neues Rezept gelernt und es sofort gekocht 👨‍🍳",
            link: "https://www.allrecipes.com/"),

        .init(60,
            en: "meditated and journalled for a full hour 🌿",
            gr: "διαλογιστείς και γράψεις στο ημερολόγιό σου 🌿",
            de: "meditiert und ein Stunde in dein Tagebuch geschrieben 🌿",
            link: "https://www.youtube.com/results?search_query=guided+meditation+1+hour"),

        // Outdoor — good weather
        .init(60,
            en: "gone for a solid 6 km run in the fresh air 🏃",
            gr: "τρέξεις 6 χιλιόμετρα στον φρέσκο αέρα 🏃",
            de: "6 km an der frischen Luft gelaufen 🏃",
            outdoorOnly: true, hours: 6...21,
            link: "https://www.alltrails.com/"),

        .init(60,
            en: "explored a new street in your city on foot 🗺️",
            gr: "εξερευνήσεις έναν νέο δρόμο της πόλης σου με τα πόδια 🗺️",
            de: "eine neue Straße deiner Stadt zu Fuß erkundet 🗺️",
            outdoorOnly: true, hours: 8...20),

        .init(60,
            en: "sat in the park with a coffee and watched the world go by ☕",
            gr: "πιεις τον καφέ σου στο πάρκο χωρίς βιασύνη ☕",
            de: "in Ruhe einen Kaffee im Park getrunken ☕",
            outdoorOnly: true, hours: 8...19),

        // Evening
        .init(60,
            en: "cooked a proper dinner and set the table with candles 🕯️",
            gr: "φτιάξεις ένα σωστό βραδινό και στρώσεις το τραπέζι με κεριά 🕯️",
            de: "ein richtiges Abendessen gekocht und den Tisch mit Kerzen gedeckt 🕯️",
            hours: 17...23,
            link: "https://www.allrecipes.com/"),

        // ─────────────────────────────────────
        // 2 HOURS  (120 min)
        // ─────────────────────────────────────

        .init(120,
            en: "watched a full movie with zero distractions 🎬",
            gr: "δεις μια ολόκληρη ταινία χωρίς καμία διακοπή 🎬",
            de: "einen kompletten Film ohne jegliche Ablenkung gesehen 🎬",
            link: "https://www.justwatch.com/"),

        .init(120,
            en: "deep-cleaned your whole kitchen until it sparkled ✨",
            gr: "καθαρίσεις σχολαστικά ολόκληρη την κουζίνα σου ✨",
            de: "deine gesamte Küche gründlich gereinigt, bis sie glänzt ✨"),

        .init(120,
            en: "almost finished an entire novel 📚",
            gr: "σχεδόν τελειώσεις ένα ολόκληρο μυθιστόρημα 📚",
            de: "fast ein ganzes Buch ausgelesen 📚",
            link: "https://www.goodreads.com/"),

        .init(120,
            en: "visited a parent or close friend for a real, unhurried conversation ❤️",
            gr: "επισκεφτείς έναν γονιό ή φίλο για μια αληθινή, αβίαστη κουβέντα ❤️",
            de: "einen Elternteil oder engen Freund für ein echtes, ungehetztes Gespräch besucht ❤️"),

        .init(120,
            en: "made homemade pizza from scratch — dough included 🍕",
            gr: "φτιάξεις σπιτική πίτσα από την αρχή — ζύμη και όλα 🍕",
            de: "selbstgemachte Pizza von Grund auf gemacht — inklusive Teig 🍕",
            link: "https://www.allrecipes.com/"),

        .init(120,
            en: "worked on a creative project you keep delaying 🎨",
            gr: "ασχοληθείς με ένα δημιουργικό project που αναβάλλεις 🎨",
            de: "an einem kreativen Projekt gearbeitet, das du immer hinausschiebst 🎨"),

        .init(120,
            en: "given your bike a proper service and gone for a ride 🚲",
            gr: "φτιάξεις το ποδήλατό σου και κάνεις μια βόλτα 🚲",
            de: "dein Fahrrad gewartet und eine Runde gedreht 🚲",
            link: "https://www.alltrails.com/"),

        // Outdoor — good weather
        .init(120,
            en: "gone on a proper hike and breathed some real mountain air 🏔️",
            gr: "κάνεις μια σωστή πεζοπορία και αναπνεύσεις ορεινό αέρα 🏔️",
            de: "eine richtige Wanderung gemacht und frische Bergluft geatmet 🏔️",
            outdoorOnly: true, hours: 7...18,
            link: "https://www.alltrails.com/"),

        .init(120,
            en: "cycled to a nearby town, grabbed a coffee, and cycled back 🚲",
            gr: "πας με ποδήλατο σε μια κοντινή πόλη, πιεις καφέ και γυρίσεις 🚲",
            de: "mit dem Fahrrad in eine nahe Stadt gefahren, Kaffee getrunken und zurückgeradelt 🚲",
            outdoorOnly: true, hours: 8...18,
            link: "https://www.alltrails.com/"),

        // ─────────────────────────────────────
        // 3 HOURS  (180 min)
        // ─────────────────────────────────────

        .init(180,
            en: "visited a museum and a gallery 🏛️",
            gr: "επισκεφτείς ένα μουσείο ΚΑΙ μια γκαλερί 🏛️",
            de: "ein Museum UND eine Galerie besucht 🏛️",
            hours: 9...18,
            link: "https://artsandculture.google.com/"),

        .init(180,
            en: "cooked a full Sunday feast for people you love 🍲",
            gr: "μαγειρέψεις ένα ολόκληρο Κυριακάτικο τραπέζι για αγαπημένους 🍲",
            de: "ein vollständiges Sonntagsessen für geliebte Menschen gekocht 🍲",
            hours: 10...16,
            link: "https://www.allrecipes.com/"),

        .init(180,
            en: "read almost an entire book, cover to cover 📖",
            gr: "διαβάσεις σχεδόν ολόκληρο ένα βιβλίο 📖",
            de: "fast ein ganzes Buch von Anfang bis Ende gelesen 📖",
            link: "https://www.goodreads.com/"),

        .init(180,
            en: "finished something you've been procrastinating on for weeks 🎯",
            gr: "ολοκληρώσεις κάτι που αναβάλλεις εδώ και εβδομάδες 🎯",
            de: "etwas fertiggestellt, das du seit Wochen aufgeschoben hast 🎯"),

        .init(180,
            en: "taught yourself something new from a YouTube tutorial 💡",
            gr: "μάθεις κάτι καινούργιο από ένα YouTube tutorial 💡",
            de: "sich durch ein YouTube-Tutorial etwas Neues beigebracht 💡",
            link: "https://www.youtube.com/"),

        .init(180,
            en: "taken a day trip to a nearby town and back 🚂",
            gr: "κάνεις μια ημερήσια εκδρομή σε κοντινή πόλη 🚂",
            de: "einen Tagesausflug in eine nahe Stadt und zurück gemacht 🚂",
            outdoorOnly: true, hours: 8...15,
            link: "https://www.alltrails.com/"),
    ]
}
