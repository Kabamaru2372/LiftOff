// QuoteBank.swift
// Picksy
//
// Created by Fotios Pongas 24.03.2026

import Foundation

struct QuoteBank {

    enum Language: String, CaseIterable, Codable {
        case english = "English"
        case greek = "Ελληνικά"
        case german = "Deutsch"
    }

    // MARK: - Default Quotes (Free)

    static let englishQuotes: [String] = [
        "Do you really need to be here right now?",
        "The world outside is still there.",
        "Take a breath. Put it down.",
        "What were you about to do before this?",
        "This can wait. You can't get this moment back.",
        "Your eyes need a break. So does your mind.",
        "Nothing on this screen is urgent.",
        "Three deep breaths, then decide.",
        "The best things in life aren't on a screen.",
        "You picked it up out of habit, not need.",
        "Be here now. Not in there.",
        "One less scroll, one more moment of peace.",
        "Your phone will still be here later.",
        "What if you just... didn't?",
        "You were doing fine without it.",
        "Put it down. See what happens.",
        "How many times today? Let's make this the last.",
        "Boredom isn't an emergency.",
        "You don't need to check anything right now.",
        "Life is happening around you. Look up."
    ]

    static let greekQuotes: [String] = [
        "Σίγουρα το χρειάζεσαι τώρα;",
        "Ο κόσμος έξω σε περιμένει.",
        "Πάρε μια ανάσα. Άσ' το κάτω.",
        "Τι έκανες πριν το πιάσεις;",
        "Αυτό μπορεί να περιμένει. Η στιγμή όχι.",
        "Τα μάτια σου χρειάζονται ξεκούραση.",
        "Τίποτα σ' αυτή την οθόνη δεν είναι επείγον.",
        "Τρεις βαθιές αναπνοές, μετά αποφάσισε.",
        "Τα καλύτερα πράγματα δεν είναι σε οθόνη.",
        "Το πήρες από συνήθεια, όχι ανάγκη.",
        "Να 'σαι εδώ. Όχι εκεί μέσα.",
        "Ένα scroll λιγότερο, μια στιγμή ηρεμίας παραπάνω.",
        "Το κινητό θα είναι εδώ αργότερα.",
        "Και αν απλά... δεν το άνοιγες;",
        "Τα πήγαινες μια χαρά χωρίς αυτό.",
        "Κατέβασέ το. Δες τι θα γίνει.",
        "Πόσες φορές σήμερα; Ας είναι αυτή η τελευταία.",
        "Η βαρεμάρα δεν είναι έκτακτη ανάγκη.",
        "Δεν χρειάζεται να τσεκάρεις τίποτα τώρα.",
        "Η ζωή γίνεται γύρω σου. Σήκωσε το βλέμμα."
    ]

    static let germanQuotes: [String] = [
        "Brauchst du das wirklich gerade jetzt?",
        "Die Welt da draußen ist noch da.",
        "Tief durchatmen. Leg es weg.",
        "Was hast du gemacht, bevor du es aufgehoben hast?",
        "Das kann warten. Diesen Moment bekommst du nicht zurück.",
        "Deine Augen brauchen eine Pause. Dein Kopf auch.",
        "Nichts auf diesem Bildschirm ist dringend.",
        "Drei tiefe Atemzüge, dann entscheide.",
        "Das Beste im Leben ist nicht auf einem Bildschirm.",
        "Du hast es aus Gewohnheit genommen, nicht aus Notwendigkeit.",
        "Sei hier. Nicht dort drin.",
        "Ein Scroll weniger, ein Moment mehr Ruhe.",
        "Das Handy ist später noch da.",
        "Was wäre, wenn du es einfach... nicht tätest?",
        "Du kamst ohne es gut zurecht.",
        "Leg es weg. Schau, was passiert.",
        "Wie oft heute schon? Lass das die letzte Mal sein.",
        "Langeweile ist kein Notfall.",
        "Du musst gerade nichts überprüfen.",
        "Das Leben passiert um dich herum. Schau auf."
    ]

    // MARK: - Stoic Pack (Pro)

    static let stoicEN: [String] = [
        "You have power over your mind, not outside events.",
        "It is not things that disturb us, but our judgments about them.",
        "The happiness of your life depends on the quality of your thoughts.",
        "No man is free who is not master of himself.",
        "He who fears death will never do anything worthy of a living man.",
        "Waste no more time arguing what a good man should be. Be one.",
        "The obstacle is the way.",
        "How long are you going to wait before you demand the best for yourself?",
        "First say to yourself what you would be; then do what you have to do.",
        "It's not what happens to you, but how you react to it that matters.",
        "Difficulties strengthen the mind, as labor does the body.",
        "The best revenge is not to be like your enemy.",
        "Begin at once to live, and count each separate day as a separate life.",
        "Man is not worried by real problems so much as by his imagined anxieties.",
        "If it is not right, do not do it. If it is not true, do not say it.",
        "The soul becomes dyed with the color of its thoughts.",
        "Choose not to be harmed — and you won't feel harmed.",
        "We suffer more often in imagination than in reality.",
        "Hang on to your youthful enthusiasms — you'll be able to use them better when you're older.",
        "He suffers more than necessary, who suffers before it is necessary."
    ]

    static let stoicGR: [String] = [
        "Έχεις δύναμη πάνω στο μυαλό σου, όχι στα γεγονότα.",
        "Δεν μας ταράζουν τα πράγματα, αλλά οι κρίσεις μας γι' αυτά.",
        "Η ευτυχία σου εξαρτάται από τη ποιότητα των σκέψεών σου.",
        "Κανείς δεν είναι ελεύθερος αν δεν είναι κύριος του εαυτού του.",
        "Αυτός που φοβάται τον θάνατο δεν θα κάνει τίποτα αξιόλογο.",
        "Σταμάτα να συζητάς τι σημαίνει καλός άνθρωπος. Γίνε ένας.",
        "Το εμπόδιο είναι ο δρόμος.",
        "Πόσο θα περιμένεις για να απαιτήσεις το καλύτερο για σένα;",
        "Πες πρώτα τι θέλεις να γίνεις. Μετά κάνε ό,τι χρειάζεται.",
        "Δεν μετράει τι σου συμβαίνει, αλλά πώς αντιδράς.",
        "Οι δυσκολίες δυναμώνουν το μυαλό, όπως η άσκηση το σώμα.",
        "Η καλύτερη εκδίκηση είναι να μη μοιάζεις στον εχθρό σου.",
        "Άρχισε αμέσως να ζεις. Κάθε μέρα είναι μια ξεχωριστή ζωή.",
        "Ο άνθρωπος ανησυχεί περισσότερο για φανταστικά παρά πραγματικά προβλήματα.",
        "Αν δεν είναι σωστό, μην το κάνεις. Αν δεν είναι αληθινό, μην το λες.",
        "Η ψυχή βάφεται με το χρώμα των σκέψεών της.",
        "Διάλεξε να μην πληγωθείς — και δεν θα πληγωθείς.",
        "Υποφέρουμε πιο συχνά στη φαντασία παρά στην πραγματικότητα.",
        "Κράτα τον ενθουσιασμό σου — θα σου χρειαστεί αργότερα.",
        "Υποφέρει περισσότερο αυτός που υποφέρει πριν χρειαστεί."
    ]

    static let stoicDE: [String] = [
        "Du hast Macht über deinen Geist, nicht über äußere Ereignisse.",
        "Nicht die Dinge beunruhigen uns, sondern unsere Urteile darüber.",
        "Das Glück deines Lebens hängt von der Qualität deiner Gedanken ab.",
        "Kein Mensch ist frei, der nicht Herr seiner selbst ist.",
        "Wer den Tod fürchtet, wird nie etwas Würdiges tun.",
        "Hör auf zu diskutieren, was ein guter Mensch sein soll. Sei einer.",
        "Das Hindernis ist der Weg.",
        "Wie lange willst du noch warten, bevor du das Beste für dich forderst?",
        "Sag erst, wer du sein willst; dann tu, was du tun musst.",
        "Nicht was dir passiert zählt, sondern wie du darauf reagierst.",
        "Schwierigkeiten stärken den Geist, wie Arbeit den Körper stärkt.",
        "Die beste Rache ist, deinem Feind nicht zu ähneln.",
        "Fang sofort an zu leben. Zähle jeden Tag als ein eigenes Leben.",
        "Der Mensch sorgt sich mehr um eingebildete als um wirkliche Probleme.",
        "Wenn es nicht richtig ist, tu es nicht. Wenn es nicht wahr ist, sag es nicht.",
        "Die Seele nimmt die Farbe ihrer Gedanken an.",
        "Wähle, nicht verletzt zu werden — und du wirst es nicht fühlen.",
        "Wir leiden öfter in der Vorstellung als in der Wirklichkeit.",
        "Halte an deinen jugendlichen Begeisterungen fest — du wirst sie später brauchen.",
        "Der leidet mehr als nötig, der leidet bevor es nötig ist."
    ]

    // MARK: - Humor Pack (Pro)

    static let humorEN: [String] = [
        "Your phone called. It wants a break from YOU.",
        "Plot twist: nothing happened since you last checked.",
        "Instagram will survive without your like. Probably.",
        "Breaking news: still no breaking news.",
        "Your thumb called in sick. Give it a rest.",
        "Doomscrolling burns 0 calories and 100% of your joy.",
        "That notification? Just an app begging for attention.",
        "Your screen time report is judging you. Hard.",
        "Put it down or I'm telling your screen time.",
        "You've been \"just checking\" for 20 minutes.",
        "The WiFi will still work in 5 minutes.",
        "Your cat has more self-control than this.",
        "Remember books? They don't have ads.",
        "Touch grass. It's free and has no pop-ups.",
        "Your battery is dying. So is your attention span.",
        "Another scroll? That's what they want you to do.",
        "You're not bored. You're addicted. Different thing.",
        "Fun fact: people survived without phones until 2007.",
        "Your phone misses you too. From far away.",
        "This is your 47th pickup today. That's a lot, even for you."
    ]

    static let humorGR: [String] = [
        "Το κινητό σου πήρε τηλέφωνο. Θέλει διάλειμμα ΑΠΟ σένα.",
        "Plot twist: δεν έγινε τίποτα από τότε που τσέκαρες.",
        "Το Instagram θα επιβιώσει χωρίς το like σου. Μάλλον.",
        "Έκτακτο: δεν υπάρχει κανένα έκτακτο.",
        "Ο αντίχειράς σου πήρε αναρρωτική. Δώσ' του ρεπό.",
        "Το doomscrolling καίει 0 θερμίδες και 100% της χαράς σου.",
        "Αυτό το notification; Μια app που ζητιανεύει προσοχή.",
        "Το screen time report σου σε κρίνει. Σκληρά.",
        "Βάλ' το κάτω ή λέω στο screen time σου.",
        "\"Απλά τσεκάρω\" λες εδώ και 20 λεπτά.",
        "Το WiFi θα δουλεύει και σε 5 λεπτά.",
        "Η γάτα σου έχει περισσότερο αυτοέλεγχο.",
        "Θυμάσαι τα βιβλία; Δεν έχουν διαφημίσεις.",
        "Βγες έξω. Η φύση δεν έχει pop-ups.",
        "Η μπαταρία πεθαίνει. Όπως και η προσοχή σου.",
        "Άλλο ένα scroll; Αυτό ακριβώς θέλουν να κάνεις.",
        "Δεν βαριέσαι. Είσαι εθισμένος. Διαφορετικό πράγμα.",
        "Fun fact: ο κόσμος επέζησε χωρίς κινητά μέχρι το 2007.",
        "Το κινητό σου βαρέθηκε. Αλλά από μακριά.",
        "Αυτή είναι η 47η φορά σήμερα. Πολλές, ακόμα και για σένα."
    ]

    static let humorDE: [String] = [
        "Dein Handy hat angerufen. Es braucht eine Pause von DIR.",
        "Plot Twist: Seit du zuletzt nachgeschaut hast, ist nichts passiert.",
        "Instagram überlebt ohne dein Like. Wahrscheinlich.",
        "Eilmeldung: Immer noch keine Eilmeldung.",
        "Dein Daumen hat sich krankgemeldet. Gönn ihm Ruhe.",
        "Doomscrolling verbrennt 0 Kalorien und 100% deiner Freude.",
        "Diese Benachrichtigung? Nur eine App, die um Aufmerksamkeit bettelt.",
        "Dein Screen-Time-Bericht verurteilt dich. Hart.",
        "Leg es weg, oder ich verrat's deiner Screen Time.",
        "Du \"schaust nur kurz\" seit 20 Minuten.",
        "Das WLAN funktioniert auch in 5 Minuten noch.",
        "Deine Katze hat mehr Selbstkontrolle als du.",
        "Erinnerst du dich an Bücher? Die haben keine Werbung.",
        "Geh raus. Die Natur hat keine Pop-ups.",
        "Dein Akku stirbt. Deine Aufmerksamkeit auch.",
        "Noch ein Scroll? Genau das wollen sie, dass du tust.",
        "Du bist nicht gelangweilt. Du bist süchtig. Unterschied.",
        "Fun fact: Menschen haben bis 2007 ohne Handys überlebt.",
        "Dein Handy vermisst dich auch. Aus der Ferne.",
        "Das ist dein 47. Griff heute. Viel, selbst für dich."
    ]

    // MARK: - Philosophy Pack (Pro)

    static let philosophyEN: [String] = [
        "The unexamined life is not worth living.",
        "To be is to be perceived... but not through a screen.",
        "I think, therefore I don't need to scroll.",
        "The only true wisdom is in knowing you know nothing... about what just happened on Twitter.",
        "One cannot step twice into the same feed.",
        "Knowing yourself is the beginning of all wisdom.",
        "Time you enjoy wasting is not wasted time. Scrolling is.",
        "In the middle of difficulty lies opportunity. Not in your phone.",
        "We are what we repeatedly do. Put the phone down repeatedly.",
        "Man is condemned to be free — so stop letting your phone choose for you.",
        "The mind is everything. What you think you become. Think less about memes.",
        "Happiness is not something ready made. It doesn't come from notifications.",
        "He who has a why can bear almost any how. Your phone has no why.",
        "The only thing I know is that I know nothing... happened while I wasn't looking.",
        "Life must be understood backwards; but it must be lived forwards. Not scrolled.",
        "Simplicity is the ultimate sophistication. Put it down.",
        "To live is the rarest thing. Most people just scroll.",
        "The world is full of magic things, waiting for our senses to grow sharper.",
        "Wonder is the beginning of wisdom. Not WiFi.",
        "Real knowledge is to know the extent of one's ignorance. Also, screen time."
    ]

    static let philosophyGR: [String] = [
        "Ο ανεξέταστος βίος ου βιωτός ανθρώπω.",
        "Είναι σημαίνει γίνεσαι αντιληπτός... αλλά όχι μέσω οθόνης.",
        "Σκέφτομαι, άρα δεν χρειάζεται να σκρολάρω.",
        "Η μόνη αληθινή σοφία είναι να ξέρεις ότι δεν ξέρεις τίποτα... για το τι έγινε στο Twitter.",
        "Δεν μπορείς να μπεις δύο φορές στο ίδιο feed.",
        "Το να γνωρίζεις τον εαυτό σου είναι η αρχή κάθε σοφίας.",
        "Ο χρόνος που απολαμβάνεις δεν χάνεται. Το scrolling χάνεται.",
        "Μέσα στη δυσκολία κρύβεται ευκαιρία. Όχι στο κινητό.",
        "Είμαστε αυτό που κάνουμε επανειλημμένα. Βάλ' το κάτω επανειλημμένα.",
        "Ο άνθρωπος είναι καταδικασμένος να είναι ελεύθερος — σταμάτα να αφήνεις το κινητό να διαλέγει.",
        "Το μυαλό είναι τα πάντα. Ό,τι σκέφτεσαι γίνεσαι. Σκέψου λιγότερα memes.",
        "Η ευτυχία δεν είναι έτοιμη. Δεν έρχεται από notifications.",
        "Αυτός που έχει ένα γιατί αντέχει κάθε πώς. Το κινητό δεν έχει γιατί.",
        "Ξέρω ότι δεν ξέρω τίποτα... που έγινε όσο δεν κοίταζα.",
        "Η ζωή πρέπει να κατανοηθεί ανάποδα· αλλά να ζηθεί μπροστά. Όχι να σκρολαριστεί.",
        "Η απλότητα είναι η απόλυτη πολυπλοκότητα. Βάλ' το κάτω.",
        "Το να ζεις είναι το πιο σπάνιο πράγμα. Οι περισσότεροι απλά σκρολάρουν.",
        "Ο κόσμος είναι γεμάτος μαγικά πράγματα που περιμένουν τις αισθήσεις μας.",
        "Η απορία είναι η αρχή της σοφίας. Όχι το WiFi.",
        "Πραγματική γνώση είναι να ξέρεις πόσο αγνοείς. Και πόσο screen time έχεις."
    ]

    static let philosophyDE: [String] = [
        "Das ungeprüfte Leben ist nicht lebenswert.",
        "Sein heißt wahrgenommen werden... aber nicht durch einen Bildschirm.",
        "Ich denke, also muss ich nicht scrollen.",
        "Die einzige wahre Weisheit ist zu wissen, dass du nichts weißt... über das, was gerade auf Twitter passiert.",
        "Man kann nicht zweimal in denselben Feed steigen.",
        "Sich selbst zu kennen ist der Beginn aller Weisheit.",
        "Zeit, die du genießt zu verschwenden, ist keine verschwendete Zeit. Scrollen schon.",
        "In der Mitte der Schwierigkeit liegt die Möglichkeit. Nicht in deinem Handy.",
        "Wir sind, was wir wiederholt tun. Leg das Handy wiederholt weg.",
        "Der Mensch ist zur Freiheit verurteilt — hör auf, dein Handy für dich wählen zu lassen.",
        "Der Geist ist alles. Was du denkst, wirst du. Denke weniger an Memes.",
        "Glück ist nicht fertig gemacht. Es kommt nicht von Benachrichtigungen.",
        "Wer ein Warum hat, kann fast jedes Wie ertragen. Dein Handy hat kein Warum.",
        "Das Einzige, was ich weiß, ist, dass ich nichts weiß... was passiert ist, während ich nicht geschaut habe.",
        "Das Leben muss vorwärts gelebt, aber rückwärts verstanden werden. Nicht gescrollt.",
        "Einfachheit ist das höchste Maß an Raffinesse. Leg es weg.",
        "Zu leben ist das Seltenste. Die meisten scrollen nur.",
        "Die Welt ist voller magischer Dinge, die darauf warten, dass unsere Sinne schärfer werden.",
        "Staunen ist der Anfang der Weisheit. Nicht WLAN.",
        "Echtes Wissen bedeutet zu wissen, wie groß die eigene Unwissenheit ist. Auch beim Screen Time."
    ]

    // MARK: - Random Quote

    static func random(language: Language? = nil) -> String {
        let lang = language ?? savedLanguage()
        let enabledPacks = UserDefaults.standard.stringArray(forKey: "enabledQuotePacks") ?? []

        var allQuotes: [String] = []

        switch lang {
        case .english:
            allQuotes.append(contentsOf: englishQuotes)
            if enabledPacks.contains("stoic") { allQuotes.append(contentsOf: stoicEN) }
            if enabledPacks.contains("humor") { allQuotes.append(contentsOf: humorEN) }
            if enabledPacks.contains("philosophy") { allQuotes.append(contentsOf: philosophyEN) }
        case .greek:
            allQuotes.append(contentsOf: greekQuotes)
            if enabledPacks.contains("stoic") { allQuotes.append(contentsOf: stoicGR) }
            if enabledPacks.contains("humor") { allQuotes.append(contentsOf: humorGR) }
            if enabledPacks.contains("philosophy") { allQuotes.append(contentsOf: philosophyGR) }
        case .german:
            allQuotes.append(contentsOf: germanQuotes)
            if enabledPacks.contains("stoic") { allQuotes.append(contentsOf: stoicDE) }
            if enabledPacks.contains("humor") { allQuotes.append(contentsOf: humorDE) }
            if enabledPacks.contains("philosophy") { allQuotes.append(contentsOf: philosophyDE) }
        }

        return allQuotes.randomElement() ?? "Put it down."
    }

    static func savedLanguage() -> Language {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        return Language(rawValue: raw) ?? .english
    }

    static func enablePack(_ pack: String) {
        var packs = UserDefaults.standard.stringArray(forKey: "enabledQuotePacks") ?? []
        if !packs.contains(pack) {
            packs.append(pack)
            UserDefaults.standard.set(packs, forKey: "enabledQuotePacks")
        }
    }

    static func isPackEnabled(_ pack: String) -> Bool {
        let packs = UserDefaults.standard.stringArray(forKey: "enabledQuotePacks") ?? []
        return packs.contains(pack)
    }
}


