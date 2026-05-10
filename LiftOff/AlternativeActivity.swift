//
//  AlternativeActivity.swift
//  Picksy
//
//  Created by Fotios Pongas on 04.05.2026
//
//  v1.7 UPDATE:
//  - Localized links ανά γλώσσα (EN/GR/DE)
//  - Evening-specific activities ("Τι κάνω απόψε;")
//
//  Time math basis:
//  Average pickup duration 25 seconds (Rosen, 2016).
//  100 pickups × 25s = ~42 minutes
//  150 pickups × 25s = ~62 minutes
//  200 pickups × 25s = ~83 minutes
//

import Foundation

struct AlternativeActivity {
    let durationMinutes: Int

    let descriptionEN: String
    let descriptionGR: String
    let descriptionDE: String

    // Localized links (nil = no link for this language)
    let linkEN: String?
    let linkGR: String?
    let linkDE: String?

    // Localized link labels
    let linkLabelEN: String?
    let linkLabelGR: String?
    let linkLabelDE: String?

    /// True αν είναι evening-specific activity
    let isEveningActivity: Bool

    init(
        durationMinutes: Int,
        descriptionEN: String,
        descriptionGR: String,
        descriptionDE: String,
        linkEN: String? = nil,
        linkGR: String? = nil,
        linkDE: String? = nil,
        linkLabelEN: String? = nil,
        linkLabelGR: String? = nil,
        linkLabelDE: String? = nil,
        isEveningActivity: Bool = false
    ) {
        self.durationMinutes = durationMinutes
        self.descriptionEN = descriptionEN
        self.descriptionGR = descriptionGR
        self.descriptionDE = descriptionDE
        self.linkEN = linkEN
        self.linkGR = linkGR
        self.linkDE = linkDE
        self.linkLabelEN = linkLabelEN
        self.linkLabelGR = linkLabelGR
        self.linkLabelDE = linkLabelDE
        self.isEveningActivity = isEveningActivity
    }

    func description(language: String) -> String {
        switch language {
        case "Ελληνικά": return descriptionGR
        case "Deutsch":  return descriptionDE
        default:         return descriptionEN
        }
    }

    func link(language: String) -> URL? {
        let urlString: String?
        switch language {
        case "Ελληνικά": urlString = linkGR
        case "Deutsch":  urlString = linkDE
        default:         urlString = linkEN
        }
        guard let str = urlString else { return nil }
        return URL(string: str)
    }

    func linkLabel(language: String) -> String? {
        switch language {
        case "Ελληνικά": return linkLabelGR
        case "Deutsch":  return linkLabelDE
        default:         return linkLabelEN
        }
    }
}

enum AlternativeActivityBank {

    // MARK: - Time Calculation

    private static let secondsPerPickup: Int = 25

    static func totalMinutes(forPickups pickups: Int) -> Int {
        return (pickups * secondsPerPickup) / 60
    }

    // MARK: - Activity Bank

    static let activities: [AlternativeActivity] = [

        // ═══════════════════════════════════════
        // QUICK (30-45 min)
        // ═══════════════════════════════════════

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "take a refreshing walk in nature",
            descriptionGR: "πάς για έναν ωραίο περίπατο στη φύση",
            descriptionDE: "einen erfrischenden Spaziergang in der Natur machen",
            linkEN: "https://www.alltrails.com",
            linkGR: "https://www.alltrails.com/explore/greece",
            linkDE: "https://www.alltrails.com/explore/germany",
            linkLabelEN: "Find a trail near you",
            linkLabelGR: "Βρες μονοπάτι κοντά σου",
            linkLabelDE: "Finde einen Weg in der Nähe"
        ),

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "listen to a meaningful podcast episode",
            descriptionGR: "ακούς ένα ενδιαφέρον podcast",
            descriptionDE: "eine spannende Podcast-Folge hören",
            linkEN: "https://open.spotify.com/genre/podcasts-page",
            linkGR: "https://open.spotify.com/genre/podcasts-page",
            linkDE: "https://open.spotify.com/genre/podcasts-page",
            linkLabelEN: "Browse podcasts",
            linkLabelGR: "Ανακάλυψε podcasts",
            linkLabelDE: "Podcasts entdecken"
        ),

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "do a quick workout at home — no gym needed",
            descriptionGR: "κάνεις γρήγορη γυμναστική στο σπίτι",
            descriptionDE: "ein schnelles Training zu Hause machen",
            linkEN: "https://www.nike.com/ntc-app",
            linkGR: "https://www.freeletics.com",
            linkDE: "https://www.runtastic.com",
            linkLabelEN: "Nike Training Club (free)",
            linkLabelGR: "Freeletics — γυμναστική στο σπίτι",
            linkLabelDE: "Runtastic — Training"
        ),

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "write in your journal and reflect on your day",
            descriptionGR: "γράφεις σκέψεις στο ημερολόγιο σου",
            descriptionDE: "in dein Tagebuch schreiben und den Tag reflektieren"
        ),

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "call someone you love and catch up",
            descriptionGR: "παίρνεις τηλέφωνο κάποιον αγαπημένο",
            descriptionDE: "jemanden anrufen, den du liebst"
        ),

        AlternativeActivity(
            durationMinutes: 35,
            descriptionEN: "read a chapter of a great book",
            descriptionGR: "διαβάζεις ένα κεφάλαιο από βιβλίο",
            descriptionDE: "ein Kapitel eines guten Buches lesen",
            linkEN: "https://www.goodreads.com",
            linkGR: "https://www.biblionet.gr",
            linkDE: "https://www.lovelybooks.de",
            linkLabelEN: "Find your next book on Goodreads",
            linkLabelGR: "Βρες βιβλίο στο Biblionet",
            linkLabelDE: "Buch finden auf LovelyBooks"
        ),

        // ═══════════════════════════════════════
        // MEDIUM (60 min)
        // ═══════════════════════════════════════

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "cook something delicious from scratch",
            descriptionGR: "φτιάχνεις κάτι νόστιμο από την αρχή",
            descriptionDE: "etwas Leckeres von Grund auf kochen",
            linkEN: "https://www.allrecipes.com",
            linkGR: "https://www.sintages.gr",
            linkDE: "https://www.chefkoch.de",
            linkLabelEN: "Get a recipe on Allrecipes",
            linkLabelGR: "Βρες συνταγή στο Sintages.gr",
            linkLabelDE: "Rezept finden auf Chefkoch.de"
        ),

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "go for a proper run or workout",
            descriptionGR: "πάς για τρέξιμο ή προπόνηση",
            descriptionDE: "richtig joggen oder trainieren gehen",
            linkEN: "https://www.nike.com/ntc-app",
            linkGR: "https://www.freeletics.com",
            linkDE: "https://www.runtastic.com",
            linkLabelEN: "Nike Training Club",
            linkLabelGR: "Freeletics",
            linkLabelDE: "Runtastic"
        ),

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "watch a sunset without distractions",
            descriptionGR: "βλέπεις το ηλιοβασίλεμα χωρίς distractions",
            descriptionDE: "einen Sonnenuntergang ohne Ablenkung genießen"
        ),

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "have a meaningful conversation with a friend",
            descriptionGR: "κάνεις μια ουσιαστική κουβέντα με φίλο",
            descriptionDE: "ein tiefes Gespräch mit einem Freund führen"
        ),

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "tidy and reorganize your space",
            descriptionGR: "τακτοποιείς και οργανώνεις τον χώρο σου",
            descriptionDE: "deinen Raum aufräumen und neu organisieren"
        ),

        // ═══════════════════════════════════════
        // SUBSTANTIAL (90 min)
        // ═══════════════════════════════════════

        AlternativeActivity(
            durationMinutes: 90,
            descriptionEN: "cook a complete meal from scratch",
            descriptionGR: "μαγειρεύεις ένα ολόκληρο γεύμα",
            descriptionDE: "ein komplettes Essen von Grund auf kochen",
            linkEN: "https://www.allrecipes.com",
            linkGR: "https://www.sintages.gr",
            linkDE: "https://www.chefkoch.de",
            linkLabelEN: "Find a recipe",
            linkLabelGR: "Βρες συνταγή",
            linkLabelDE: "Rezept finden"
        ),

        AlternativeActivity(
            durationMinutes: 90,
            descriptionEN: "have a proper hike in nature",
            descriptionGR: "κάνεις πεζοπορία στη φύση",
            descriptionDE: "eine richtige Wanderung in der Natur machen",
            linkEN: "https://www.alltrails.com",
            linkGR: "https://www.alltrails.com/explore/greece",
            linkDE: "https://www.alltrails.com/explore/germany",
            linkLabelEN: "Find a hiking trail",
            linkLabelGR: "Βρες διαδρομή",
            linkLabelDE: "Wanderweg finden"
        ),

        AlternativeActivity(
            durationMinutes: 90,
            descriptionEN: "visit a museum or gallery nearby",
            descriptionGR: "επισκέπτεσαι ένα μουσείο ή γκαλερί",
            descriptionDE: "ein Museum oder eine Galerie besuchen"
        ),

        // ═══════════════════════════════════════
        // BIG (120+ min)
        // ═══════════════════════════════════════

        AlternativeActivity(
            durationMinutes: 120,
            descriptionEN: "watch a full film with full attention",
            descriptionGR: "βλέπεις μια ολόκληρη ταινία με πλήρη προσοχή",
            descriptionDE: "einen kompletten Film mit voller Aufmerksamkeit schauen",
            linkEN: "https://www.justwatch.com",
            linkGR: "https://www.justwatch.com/gr",
            linkDE: "https://www.justwatch.com/de",
            linkLabelEN: "Find a film on JustWatch",
            linkLabelGR: "Βρες ταινία στο JustWatch",
            linkLabelDE: "Film finden auf JustWatch"
        ),

        AlternativeActivity(
            durationMinutes: 120,
            descriptionEN: "visit your parents or a close friend",
            descriptionGR: "επισκέπτεσαι τους γονείς σου ή έναν στενό φίλο",
            descriptionDE: "deine Eltern oder einen engen Freund besuchen"
        ),

        AlternativeActivity(
            durationMinutes: 120,
            descriptionEN: "finish that project you've been postponing",
            descriptionGR: "ολοκληρώνεις ένα project που αναβάλλεις",
            descriptionDE: "das Projekt fertigstellen, das du aufgeschoben hast"
        ),

        // ═══════════════════════════════════════
        // EVENING ACTIVITIES (isEveningActivity: true)
        // Εμφανίζονται όταν ο user πατάει "Τι κάνω απόψε;"
        // ═══════════════════════════════════════

        AlternativeActivity(
            durationMinutes: 90,
            descriptionEN: "watch a film tonight — something worth your time",
            descriptionGR: "βλέπεις μια ταινία απόψε που αξίζει τον χρόνο σου",
            descriptionDE: "heute Abend einen Film schauen, der deine Zeit wert ist",
            linkEN: "https://www.justwatch.com",
            linkGR: "https://www.justwatch.com/gr",
            linkDE: "https://www.justwatch.com/de",
            linkLabelEN: "Find what to watch on JustWatch",
            linkLabelGR: "Βρες τι να δεις στο JustWatch",
            linkLabelDE: "Film finden auf JustWatch",
            isEveningActivity: true
        ),

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "cook a nice dinner and enjoy it slowly",
            descriptionGR: "φτιάχνεις ένα ωραίο βραδινό και το απολαμβάνεις",
            descriptionDE: "ein schönes Abendessen kochen und langsam genießen",
            linkEN: "https://www.allrecipes.com",
            linkGR: "https://www.sintages.gr",
            linkDE: "https://www.chefkoch.de",
            linkLabelEN: "Tonight's recipe on Allrecipes",
            linkLabelGR: "Συνταγή για απόψε στο Sintages.gr",
            linkLabelDE: "Abendrezept auf Chefkoch.de",
            isEveningActivity: true
        ),

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "read a few chapters before bed",
            descriptionGR: "διαβάζεις λίγα κεφάλαια πριν κοιμηθείς",
            descriptionDE: "vor dem Schlafengehen ein paar Kapitel lesen",
            linkEN: "https://www.goodreads.com",
            linkGR: "https://www.biblionet.gr",
            linkDE: "https://www.lovelybooks.de",
            linkLabelEN: "Find your next book",
            linkLabelGR: "Βρες βιβλίο",
            linkLabelDE: "Buch finden",
            isEveningActivity: true
        ),

        AlternativeActivity(
            durationMinutes: 45,
            descriptionEN: "call a friend and catch up properly",
            descriptionGR: "παίρνεις τηλέφωνο έναν φίλο για τα νέα",
            descriptionDE: "einen Freund anrufen und richtig plaudern",
            isEveningActivity: true
        ),

        AlternativeActivity(
            durationMinutes: 60,
            descriptionEN: "go for an evening walk — clear your head",
            descriptionGR: "πάς για βραδινό περίπατο — ξεκάθαρο μυαλό",
            descriptionDE: "einen Abendspaziergang machen — den Kopf frei bekommen",
            linkEN: "https://www.alltrails.com",
            linkGR: "https://www.alltrails.com/explore/greece",
            linkDE: "https://www.alltrails.com/explore/germany",
            linkLabelEN: "Find a route near you",
            linkLabelGR: "Βρες διαδρομή κοντά σου",
            linkLabelDE: "Route in der Nähe finden",
            isEveningActivity: true
        ),

        AlternativeActivity(
            durationMinutes: 30,
            descriptionEN: "write down 3 good things that happened today",
            descriptionGR: "γράφεις 3 καλά πράγματα που έγιναν σήμερα",
            descriptionDE: "3 gute Dinge aufschreiben, die heute passiert sind",
            isEveningActivity: true
        ),

        AlternativeActivity(
            durationMinutes: 90,
            descriptionEN: "plan something to look forward to this week",
            descriptionGR: "σχεδιάζεις κάτι να ανυπομονείς αυτή την εβδομάδα",
            descriptionDE: "etwas planen, worauf du dich diese Woche freuen kannst",
            isEveningActivity: true
        ),
    ]

    // MARK: - Selection

    /// Picks an activity matching the user's pickup time.
    static func pickActivity(forPickups pickups: Int) -> AlternativeActivity {
        let totalMin = totalMinutes(forPickups: pickups)

        let dayActivities = activities.filter { !$0.isEveningActivity }

        let matchingActivities = dayActivities.filter {
            abs($0.durationMinutes - totalMin) <= 15
        }

        if let activity = matchingActivities.randomElement() {
            return activity
        }

        let closest = dayActivities.min { a, b in
            abs(a.durationMinutes - totalMin) < abs(b.durationMinutes - totalMin)
        }

        return closest ?? dayActivities[0]
    }

    /// Picks a random evening activity για το "Τι κάνω απόψε;" button.
    static func pickEveningActivity() -> AlternativeActivity {
        let eveningActivities = activities.filter { $0.isEveningActivity }
        return eveningActivities.randomElement() ?? activities[0]
    }

    /// Picks multiple evening activities (για να δείχνει 3 επιλογές).
    static func pickEveningActivities(count: Int = 3) -> [AlternativeActivity] {
        let eveningActivities = activities.filter { $0.isEveningActivity }
        return Array(eveningActivities.shuffled().prefix(count))
    }
}

