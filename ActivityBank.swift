// ActivityBank.swift
// Picksy
//
// Created by Fotios Pongas on 23.04.2026
//
// Αντικαθιστά τα quotes με συγκεκριμένες προτάσεις δραστηριοτήτων.
// - Time-based: διαφορετικές προτάσεις ανάλογα την ώρα
// - Weekday/Weekend variations
// - Anti-repetition: δεν επαναλαμβάνει τις τελευταίες 5

import Foundation

struct ActivityBank {

    enum Language: String, CaseIterable, Codable {
        case english = "English"
        case greek = "Ελληνικά"
        case german = "Deutsch"
    }

    enum TimeSlot {
        case morning       // 06-12
        case afternoon     // 12-17
        case evening       // 17-20
        case night         // 20-24
        case lateNight     // 00-06
    }

    // MARK: - Morning (06-12)

    static let morningEN: [String] = [
        "Make yourself a proper breakfast. Your body has been fasting all night.",
        "Stretch for 5 minutes. Your spine will thank you after a night of stillness.",
        "Step outside for 2 minutes of sunlight. It regulates your whole day's energy.",
        "Drink a glass of water before anything else. You're dehydrated.",
        "Do 10 slow breaths before the noise starts. Set the tone.",
        "Make your bed. One small win to start the day right.",
        "Brew a real cup of tea or coffee. Taste it, don't just drink it.",
        "Write down 3 things you want to do today. Paper, not screen.",
        "Open a window. Let fresh air in for 2 minutes.",
        "Wash your face with cold water. Instant alertness.",
        "Do 20 push-ups or squats. Gets blood flowing fast.",
        "Tidy one small area — a drawer, your desk. Clear space, clear mind.",
        "Call or text a family member good morning. Real connection.",
        "Read one page of a book. Just one. See where it leads.",
        "Write in a journal for 5 minutes. Empty the mental clutter.",
        "Water your plants. They've been waiting.",
        "Plan your first real meal of the day. Food = energy.",
        "Take a 10-minute walk. Morning walks change your entire mood.",
        "Listen to music without doing anything else. Just listen.",
        "Sit with your morning drink in silence. No screen. Just you."
    ]

    static let morningGR: [String] = [
        "Φτιάξε σωστό πρωινό. Το σώμα σου νήστευε όλη τη νύχτα.",
        "Κάνε stretching για 5 λεπτά. Η πλάτη σου θα σε ευχαριστήσει.",
        "Βγες έξω για 2 λεπτά στον ήλιο. Ρυθμίζει την ενέργεια όλης της μέρας.",
        "Πιες ένα ποτήρι νερό πριν από όλα. Είσαι αφυδατωμένος.",
        "Κάνε 10 αργές αναπνοές πριν αρχίσει ο θόρυβος. Όρισε τον ρυθμό.",
        "Στρώσε το κρεβάτι σου. Μια μικρή νίκη για καλή αρχή.",
        "Φτιάξε έναν πραγματικό καφέ ή τσάι. Γεύσου τον, μην τον κατεβάζεις.",
        "Γράψε 3 πράγματα που θες να κάνεις σήμερα. Χαρτί, όχι οθόνη.",
        "Άνοιξε ένα παράθυρο. Άφησε φρέσκο αέρα για 2 λεπτά.",
        "Πλύνε το πρόσωπό σου με κρύο νερό. Στιγμιαία εγρήγορση.",
        "Κάνε 20 push-ups ή squats. Ξυπνάει το αίμα γρήγορα.",
        "Τακτοποίησε έναν μικρό χώρο — ένα συρτάρι, το γραφείο. Τάξη = ηρεμία.",
        "Πάρε τηλέφωνο ή στείλε μήνυμα σε συγγενή. Πραγματική επαφή.",
        "Διάβασε μια σελίδα από βιβλίο. Μόνο μία. Δες πού πάει.",
        "Γράψε στο ημερολόγιο για 5 λεπτά. Άδειασε το μυαλό.",
        "Πότισε τα φυτά σου. Σε περιμένουν.",
        "Σχεδίασε το πρώτο σου πραγματικό γεύμα. Φαγητό = ενέργεια.",
        "Πήγαινε 10λεπτο περίπατο. Οι πρωινοί περίπατοι αλλάζουν τη διάθεση.",
        "Άκου μουσική χωρίς να κάνεις τίποτα άλλο. Απλά άκουσε.",
        "Κάτσε με τον καφέ σου στη σιωπή. Χωρίς οθόνη. Μόνο εσύ."
    ]

    static let morningDE: [String] = [
        "Mach dir ein richtiges Frühstück. Dein Körper hat die ganze Nacht gefastet.",
        "Dehne dich 5 Minuten. Dein Rücken wird dir danken.",
        "Geh für 2 Minuten in die Sonne. Das reguliert deine Energie den ganzen Tag.",
        "Trink ein Glas Wasser vor allem anderen. Du bist dehydriert.",
        "Mach 10 langsame Atemzüge, bevor der Lärm beginnt. Setz den Ton.",
        "Mach dein Bett. Ein kleiner Sieg für einen guten Start.",
        "Brau einen richtigen Tee oder Kaffee. Schmecke ihn, trink ihn nicht nur.",
        "Schreib 3 Dinge auf, die du heute tun willst. Papier, kein Bildschirm.",
        "Öffne ein Fenster. Lass 2 Minuten frische Luft rein.",
        "Wasch dein Gesicht mit kaltem Wasser. Sofortige Wachheit.",
        "Mach 20 Liegestütze oder Kniebeugen. Bringt das Blut in Wallung.",
        "Räum eine kleine Ecke auf — eine Schublade, den Schreibtisch. Ordnung = Ruhe.",
        "Ruf ein Familienmitglied an oder schreib Guten Morgen. Echte Verbindung.",
        "Lies eine Seite in einem Buch. Nur eine. Schau, wohin es führt.",
        "Schreib 5 Minuten ins Tagebuch. Leer den mentalen Ballast.",
        "Gieß deine Pflanzen. Sie warten.",
        "Plane deine erste richtige Mahlzeit. Essen = Energie.",
        "Geh 10 Minuten spazieren. Morgenspaziergänge ändern deine Stimmung.",
        "Hör Musik, ohne etwas anderes zu tun. Hör einfach zu.",
        "Sitz mit deinem Morgengetränk in Stille. Kein Bildschirm. Nur du."
    ]

    // MARK: - Afternoon (12-17)

    static let afternoonEN: [String] = [
        "Take a 10-minute walk. It gives you energy and clears stress.",
        "Take the stairs instead of the elevator. Free workout.",
        "Call a friend you haven't talked to in a while. 5 minutes changes moods.",
        "Drink a full glass of water. Afternoon fatigue is often dehydration.",
        "Step away from your screen for 10 minutes. Your eyes need it.",
        "Do 15 squats wherever you are. Beats that 3pm slump instantly.",
        "Eat a piece of fruit. Real sugar beats coffee.",
        "Stand up and stretch your back and shoulders for 2 minutes.",
        "Look out the window for 1 minute. Focus on something far away.",
        "Take deep breaths — 4 seconds in, 4 seconds out, 5 times.",
        "Organize one thing on your desk or in your bag.",
        "Write down one thing you're grateful for today. Paper.",
        "Get outside for 5 minutes. Even just to the door.",
        "Make a list of 3 things to finish today. Prioritize.",
        "Practice something you want to get better at for 10 minutes.",
        "Do 10 slow neck rolls. Releases tension fast.",
        "Eat a snack made of actual food, not from a bag.",
        "Sit in silence for 3 minutes. No music, no screens.",
        "Send a thank-you message to someone who helped you.",
        "Plan something small for the evening. Anticipation boosts mood."
    ]

    static let afternoonGR: [String] = [
        "Κάνε 10λεπτο περίπατο. Δίνει ενέργεια και διώχνει το άγχος.",
        "Πάρε τη σκάλα αντί για ασανσέρ. Δωρεάν γυμναστική.",
        "Πάρε τηλέφωνο έναν φίλο που έχεις καιρό να μιλήσεις. 5 λεπτά αλλάζουν τη διάθεση.",
        "Πιες ένα γεμάτο ποτήρι νερό. Η μεσημεριανή κούραση είναι συχνά αφυδάτωση.",
        "Απομακρύνσου από την οθόνη για 10 λεπτά. Τα μάτια σου το χρειάζονται.",
        "Κάνε 15 squats όπου κι αν είσαι. Διώχνει άμεσα το μεσημεριανό κενό.",
        "Φάε ένα φρούτο. Η αληθινή ζάχαρη νικάει τον καφέ.",
        "Σήκω και τέντωσε πλάτη και ώμους για 2 λεπτά.",
        "Κοίτα από το παράθυρο για 1 λεπτό. Εστίασε σε κάτι μακριά.",
        "Κάνε βαθιές αναπνοές — 4 δευτ. μέσα, 4 έξω, 5 φορές.",
        "Τακτοποίησε κάτι στο γραφείο ή στην τσάντα σου.",
        "Γράψε ένα πράγμα για το οποίο είσαι ευγνώμων σήμερα. Χαρτί.",
        "Βγες έξω για 5 λεπτά. Έστω μέχρι την πόρτα.",
        "Φτιάξε λίστα με 3 πράγματα να τελειώσεις σήμερα. Βάλε προτεραιότητα.",
        "Εξάσκησε κάτι που θες να γίνεις καλύτερος για 10 λεπτά.",
        "Κάνε 10 αργές περιστροφές αυχένα. Φεύγει η ένταση γρήγορα.",
        "Φάε ένα σνακ από αληθινό φαγητό, όχι από σακουλάκι.",
        "Κάτσε στη σιωπή για 3 λεπτά. Χωρίς μουσική, χωρίς οθόνες.",
        "Στείλε ένα ευχαριστώ σε κάποιον που σε βοήθησε.",
        "Σχεδίασε κάτι μικρό για το βράδυ. Η προσμονή ανεβάζει τη διάθεση."
    ]

    static let afternoonDE: [String] = [
        "Mach einen 10-minütigen Spaziergang. Gibt Energie und baut Stress ab.",
        "Nimm die Treppe statt den Aufzug. Kostenloses Workout.",
        "Ruf einen Freund an, mit dem du lange nicht gesprochen hast. 5 Minuten ändern alles.",
        "Trink ein volles Glas Wasser. Nachmittagsmüdigkeit ist oft Dehydrierung.",
        "Geh 10 Minuten weg vom Bildschirm. Deine Augen brauchen es.",
        "Mach 15 Kniebeugen, wo du bist. Schlägt das 15-Uhr-Tief sofort.",
        "Iss ein Stück Obst. Echter Zucker schlägt Kaffee.",
        "Steh auf und dehne Rücken und Schultern 2 Minuten.",
        "Schau 1 Minute aus dem Fenster. Fokussiere etwas in der Ferne.",
        "Atme tief — 4 Sek. ein, 4 Sek. aus, 5 Mal.",
        "Ordne eine Sache auf deinem Schreibtisch oder in deiner Tasche.",
        "Schreib eine Sache auf, für die du heute dankbar bist. Papier.",
        "Geh 5 Minuten raus. Auch nur bis zur Tür.",
        "Mach eine Liste mit 3 Sachen, die du heute fertigstellen willst.",
        "Übe 10 Minuten etwas, worin du besser werden willst.",
        "Mach 10 langsame Nackenkreise. Löst schnell Spannung.",
        "Iss einen Snack aus echtem Essen, nicht aus einer Tüte.",
        "Sitz 3 Minuten in Stille. Keine Musik, keine Bildschirme.",
        "Schick jemandem eine Danke-Nachricht, der dir geholfen hat.",
        "Plan etwas Kleines für den Abend. Vorfreude hebt die Stimmung."
    ]

    // MARK: - Evening (17-20)

    static let eveningEN: [String] = [
        "Go for a walk outside. Sunset walks are the best therapy.",
        "Cook a real meal. Even something simple. You deserve it.",
        "Call someone you love. Not text — actually call.",
        "Do 15 minutes of any movement you enjoy. Dance, yoga, walk.",
        "Sit outside for 10 minutes. Watch the day end.",
        "Prepare something for tomorrow morning. Future you will thank you.",
        "Read for 20 minutes. A real book, not articles.",
        "Have dinner without any screens. Taste your food.",
        "Water your plants and notice how they've grown.",
        "Listen to a whole album. Front to back. No skips.",
        "Write down what went well today. Small wins count.",
        "Stretch for 10 minutes. Release the day from your body.",
        "Take a shower and actually feel the water.",
        "Organize your space for tomorrow. 5 minutes.",
        "Meet a friend for a quick coffee or tea.",
        "Do something creative — draw, write, play music. Just 15 minutes.",
        "Take a different route home. Notice something new.",
        "Sit with someone you love. Just sit. No agenda.",
        "Make a plan for the weekend. Something to look forward to.",
        "Close the laptop early. Work will be there tomorrow."
    ]

    static let eveningGR: [String] = [
        "Πήγαινε βόλτα έξω. Οι βόλτες στο ηλιοβασίλεμα είναι η καλύτερη θεραπεία.",
        "Μαγείρεψε ένα πραγματικό γεύμα. Ακόμα και κάτι απλό. Σου αξίζει.",
        "Πάρε τηλέφωνο κάποιον που αγαπάς. Όχι μήνυμα — τηλέφωνο.",
        "Κάνε 15 λεπτά κίνηση που σου αρέσει. Χορός, γιόγκα, περπάτημα.",
        "Κάτσε έξω για 10 λεπτά. Δες τη μέρα να τελειώνει.",
        "Ετοίμασε κάτι για το αυριανό πρωί. Το μελλοντικό σου εγώ θα σε ευχαριστήσει.",
        "Διάβασε για 20 λεπτά. Πραγματικό βιβλίο, όχι άρθρα.",
        "Φάε βραδινό χωρίς οθόνες. Γεύσου το φαγητό σου.",
        "Πότισε τα φυτά σου και παρατήρησε πώς μεγάλωσαν.",
        "Άκου ολόκληρο άλμπουμ. Από την αρχή ως το τέλος. Χωρίς skip.",
        "Γράψε τι πήγε καλά σήμερα. Οι μικρές νίκες μετράνε.",
        "Κάνε stretching 10 λεπτά. Ελευθέρωσε το σώμα από τη μέρα.",
        "Κάνε ντους και νιώσε πραγματικά το νερό.",
        "Τακτοποίησε τον χώρο σου για αύριο. 5 λεπτά.",
        "Συνάντησε έναν φίλο για γρήγορο καφέ ή τσάι.",
        "Κάνε κάτι δημιουργικό — ζωγράφισε, γράψε, παίξε μουσική. Μόνο 15 λεπτά.",
        "Πάρε διαφορετικό δρόμο για σπίτι. Πρόσεξε κάτι νέο.",
        "Κάτσε με κάποιον που αγαπάς. Απλά κάτσε. Χωρίς σκοπό.",
        "Σχεδίασε κάτι για το Σαββατοκύριακο. Κάτι να περιμένεις.",
        "Κλείσε το laptop νωρίς. Η δουλειά θα είναι εκεί αύριο."
    ]

    static let eveningDE: [String] = [
        "Geh draußen spazieren. Sonnenuntergangs-Spaziergänge sind die beste Therapie.",
        "Koch eine richtige Mahlzeit. Auch etwas Einfaches. Du verdienst es.",
        "Ruf jemanden an, den du liebst. Nicht SMS — wirklich anrufen.",
        "Mach 15 Minuten Bewegung, die dir Spaß macht. Tanzen, Yoga, Gehen.",
        "Sitz 10 Minuten draußen. Schau zu, wie der Tag endet.",
        "Bereite etwas für morgen früh vor. Dein zukünftiges Ich dankt dir.",
        "Lies 20 Minuten. Ein echtes Buch, keine Artikel.",
        "Iss zu Abend ohne Bildschirme. Schmecke dein Essen.",
        "Gieß deine Pflanzen und bemerke, wie sie gewachsen sind.",
        "Hör ein ganzes Album. Von vorne bis hinten. Kein Überspringen.",
        "Schreib auf, was heute gut lief. Kleine Siege zählen.",
        "Dehne dich 10 Minuten. Lass den Tag aus dem Körper.",
        "Nimm eine Dusche und fühle wirklich das Wasser.",
        "Ordne deinen Raum für morgen. 5 Minuten.",
        "Triff einen Freund auf einen schnellen Kaffee oder Tee.",
        "Mach etwas Kreatives — zeichne, schreibe, spiel Musik. 15 Minuten.",
        "Nimm einen anderen Heimweg. Bemerke etwas Neues.",
        "Sitz mit jemandem, den du liebst. Einfach sitzen. Ohne Plan.",
        "Plane etwas fürs Wochenende. Etwas, worauf du dich freust.",
        "Klapp den Laptop früher zu. Die Arbeit ist morgen noch da."
    ]

    // MARK: - Night (20-24)

    static let nightEN: [String] = [
        "Read a chapter before bed. Better sleep than scrolling.",
        "Take a warm shower. Signals your body it's time to relax.",
        "Journal for 5 minutes. Get the day out of your head.",
        "Stretch gently for 10 minutes. Release the day.",
        "Listen to calm music. No screen needed.",
        "Prepare tomorrow's clothes. Removes morning stress.",
        "Drink herbal tea. Chamomile is magic.",
        "Do a body scan — relax each part from head to toe.",
        "Write tomorrow's 3 priorities. Then close the notebook.",
        "Dim all the lights. Let your body know sleep is coming.",
        "Practice deep breathing for 5 minutes. 4-7-8 technique.",
        "Look at the stars or the moon for a minute.",
        "Have a quiet conversation with someone at home.",
        "Massage your feet or shoulders for 2 minutes.",
        "Reflect on one good moment from today.",
        "Clean up for 5 minutes. Wake up to a tidy space.",
        "Put on a playlist that calms you. Just listen.",
        "Try a short meditation. Even 3 minutes helps.",
        "Turn off all devices 30 min before bed.",
        "Read poetry or something slow. No fast content."
    ]

    static let nightGR: [String] = [
        "Διάβασε ένα κεφάλαιο πριν τον ύπνο. Καλύτερος ύπνος από scrolling.",
        "Κάνε ζεστό ντους. Σηματοδοτεί στο σώμα ότι ώρα για χαλάρωση.",
        "Γράψε στο ημερολόγιο 5 λεπτά. Βγάλε τη μέρα από το μυαλό.",
        "Κάνε απαλό stretching για 10 λεπτά. Ελευθέρωσε τη μέρα.",
        "Άκου ήρεμη μουσική. Δεν χρειάζεται οθόνη.",
        "Ετοίμασε ρούχα για αύριο. Λιγότερο πρωινό άγχος.",
        "Πιες τσάι από βότανα. Το χαμομήλι είναι μαγικό.",
        "Κάνε body scan — χαλάρωσε κάθε μέρος από την κορυφή ως τα νύχια.",
        "Γράψε τις 3 προτεραιότητες για αύριο. Μετά κλείσε το τετράδιο.",
        "Χαμήλωσε όλα τα φώτα. Πες στο σώμα σου ότι έρχεται ύπνος.",
        "Εξάσκησε βαθιά αναπνοή για 5 λεπτά. Τεχνική 4-7-8.",
        "Κοίτα τα αστέρια ή το φεγγάρι για ένα λεπτό.",
        "Κάνε ήρεμη συζήτηση με κάποιον στο σπίτι.",
        "Κάνε μασάζ στα πόδια ή τους ώμους για 2 λεπτά.",
        "Αναλογίσου μια καλή στιγμή από σήμερα.",
        "Τακτοποίησε για 5 λεπτά. Ξύπνα σε τακτοποιημένο χώρο.",
        "Βάλε μια playlist που σε ηρεμεί. Απλά άκουσε.",
        "Δοκίμασε ένα σύντομο διαλογισμό. Και 3 λεπτά βοηθάνε.",
        "Κλείσε όλες τις συσκευές 30 λεπτά πριν τον ύπνο.",
        "Διάβασε ποίηση ή κάτι αργό. Όχι γρήγορο περιεχόμενο."
    ]

    static let nightDE: [String] = [
        "Lies ein Kapitel vor dem Schlafen. Besserer Schlaf als Scrollen.",
        "Nimm eine warme Dusche. Signalisiert dem Körper Entspannung.",
        "Schreib 5 Minuten Tagebuch. Bring den Tag aus deinem Kopf.",
        "Dehne dich sanft 10 Minuten. Lass den Tag los.",
        "Hör ruhige Musik. Kein Bildschirm nötig.",
        "Leg die Kleidung für morgen bereit. Weniger Morgenstress.",
        "Trink Kräutertee. Kamille ist magisch.",
        "Mach einen Bodyscan — entspanne jeden Teil von Kopf bis Fuß.",
        "Schreib 3 Prioritäten für morgen. Dann schließ das Heft.",
        "Dimme alle Lichter. Sag deinem Körper, dass Schlaf kommt.",
        "Atme tief 5 Minuten. 4-7-8 Technik.",
        "Schau eine Minute zu den Sternen oder dem Mond.",
        "Führ ein ruhiges Gespräch mit jemandem zu Hause.",
        "Massiere Füße oder Schultern 2 Minuten.",
        "Denk an einen guten Moment von heute.",
        "Räum 5 Minuten auf. Wach zu einem ordentlichen Raum auf.",
        "Spiel eine Playlist, die dich beruhigt. Hör einfach zu.",
        "Probiere eine kurze Meditation. Auch 3 Minuten helfen.",
        "Schalte alle Geräte 30 Min vor dem Schlafen aus.",
        "Lies Gedichte oder etwas Langsames. Keine schnellen Inhalte."
    ]

    // MARK: - Late Night (00-06)

    static let lateNightEN: [String] = [
        "It's late. Your body needs sleep, not another scroll.",
        "Close your eyes. Count 10 slow breaths. Try to sleep.",
        "If you can't sleep, read a physical book. Not a screen.",
        "Drink a glass of water. Then lie back down.",
        "Your brain needs darkness now. Trust the process.",
        "Tomorrow's version of you is begging you to sleep.",
        "No productive idea comes at 3am. Sleep on it.",
        "The anxious thoughts will be smaller in the morning.",
        "Put the phone across the room. Force yourself.",
        "If your mind races, write it down on paper. Then try again.",
        "Breathe slowly. In for 4, hold for 7, out for 8.",
        "You don't need to solve anything right now. Sleep.",
        "Whatever you're thinking about — it's waiting for daylight.",
        "Your eyes are begging for darkness. Listen.",
        "One more scroll never helps. You know this.",
        "Meditation or deep breathing — not TikTok.",
        "Stretch for 2 minutes. Then back to bed.",
        "The phone is keeping you awake. It's not helping.",
        "You'll regret this tomorrow. Put it down.",
        "Sleep is a superpower. You're wasting yours."
    ]

    static let lateNightGR: [String] = [
        "Είναι αργά. Το σώμα σου θέλει ύπνο, όχι άλλο scrolling.",
        "Κλείσε τα μάτια. Μέτρα 10 αργές αναπνοές. Δοκίμασε να κοιμηθείς.",
        "Αν δεν κοιμάσαι, διάβασε πραγματικό βιβλίο. Όχι οθόνη.",
        "Πιες ένα ποτήρι νερό. Μετά ξάπλωσε.",
        "Ο εγκέφαλός σου χρειάζεται σκοτάδι τώρα. Εμπιστέψου τη διαδικασία.",
        "Ο αυριανός σου εαυτός σε ικετεύει να κοιμηθείς.",
        "Καμία παραγωγική ιδέα δεν έρχεται στις 3πμ. Κοιμήσου πρώτα.",
        "Οι αγχωτικές σκέψεις θα είναι μικρότερες το πρωί.",
        "Βάλε το κινητό μακριά σου. Υποχρέωσε τον εαυτό σου.",
        "Αν το μυαλό τρέχει, γράψ' το σε χαρτί. Μετά ξαναδοκίμασε.",
        "Αναπνεύσε αργά. 4 μέσα, 7 κρατάς, 8 έξω.",
        "Δεν χρειάζεται να λύσεις τίποτα τώρα. Κοιμήσου.",
        "Ό,τι σκέφτεσαι — περιμένει το φως της μέρας.",
        "Τα μάτια σου σε ικετεύουν για σκοτάδι. Άκουσέ τα.",
        "Ένα scroll ακόμα δεν βοηθάει ποτέ. Το ξέρεις.",
        "Διαλογισμός ή βαθιές αναπνοές — όχι TikTok.",
        "Κάνε stretching 2 λεπτά. Μετά πάλι στο κρεβάτι.",
        "Το κινητό σε κρατάει ξύπνιο. Δεν βοηθάει.",
        "Θα το μετανιώσεις αύριο. Βάλ' το κάτω.",
        "Ο ύπνος είναι υπερδύναμη. Σπαταλάς τη δική σου."
    ]

    static let lateNightDE: [String] = [
        "Es ist spät. Dein Körper braucht Schlaf, kein weiteres Scrollen.",
        "Schließ die Augen. Zähl 10 langsame Atemzüge. Versuch zu schlafen.",
        "Wenn du nicht schlafen kannst, lies ein echtes Buch. Keinen Bildschirm.",
        "Trink ein Glas Wasser. Dann leg dich zurück.",
        "Dein Hirn braucht jetzt Dunkelheit. Vertrau dem Prozess.",
        "Dein morgiges Ich bettelt dich an zu schlafen.",
        "Keine produktive Idee kommt um 3 Uhr. Schlaf erst darüber.",
        "Die ängstlichen Gedanken werden morgen früh kleiner sein.",
        "Leg das Handy auf die andere Seite des Raums. Zwing dich.",
        "Wenn dein Kopf rast, schreib es auf Papier. Dann versuch's nochmal.",
        "Atme langsam. 4 rein, 7 halten, 8 raus.",
        "Du musst jetzt nichts lösen. Schlaf.",
        "Was auch immer du denkst — es wartet auf Tageslicht.",
        "Deine Augen betteln um Dunkelheit. Hör zu.",
        "Ein weiteres Scrollen hilft nie. Du weißt das.",
        "Meditation oder tiefes Atmen — kein TikTok.",
        "Dehne dich 2 Minuten. Dann zurück ins Bett.",
        "Das Handy hält dich wach. Es hilft nicht.",
        "Du wirst es morgen bereuen. Leg es weg.",
        "Schlaf ist eine Superkraft. Du verschwendest deine.",
    ]

    // MARK: - Weekend bonus activities

    static let weekendEN: [String] = [
        "Visit a place you've never been. Even nearby.",
        "Have a long breakfast with someone you love.",
        "Go to a market, bookstore, or park for an hour.",
        "Plan a day trip for next weekend.",
        "Invite a friend over. Real faces, real conversation.",
        "Try cooking something you've never made before.",
        "Go to a cafe with a book. No laptop.",
        "Take photos of your neighborhood. See it with new eyes.",
        "Write letters — real letters — to 2 people you love.",
        "Start a project that's been on your list for months."
    ]

    static let weekendGR: [String] = [
        "Επισκέψου ένα μέρος που δεν έχεις πάει. Έστω κοντινό.",
        "Πάρε ένα μεγάλο πρωινό με κάποιον που αγαπάς.",
        "Πήγαινε σε αγορά, βιβλιοπωλείο ή πάρκο για μια ώρα.",
        "Σχεδίασε εκδρομή για το επόμενο Σαββατοκύριακο.",
        "Κάλεσε φίλο σπίτι. Πραγματικά πρόσωπα, πραγματική συζήτηση.",
        "Δοκίμασε να μαγειρέψεις κάτι που δεν έχεις φτιάξει ποτέ.",
        "Πήγαινε καφετέρια με βιβλίο. Χωρίς laptop.",
        "Τράβα φωτογραφίες από τη γειτονιά σου. Δες την με νέα μάτια.",
        "Γράψε γράμματα — πραγματικά γράμματα — σε 2 ανθρώπους που αγαπάς.",
        "Ξεκίνα ένα project που έχεις στη λίστα εδώ και μήνες."
    ]

    static let weekendDE: [String] = [
        "Besuche einen Ort, an dem du noch nie warst. Auch in der Nähe.",
        "Mach ein langes Frühstück mit jemandem, den du liebst.",
        "Geh auf einen Markt, Buchladen oder in einen Park für eine Stunde.",
        "Plan einen Tagesausflug fürs nächste Wochenende.",
        "Lad einen Freund ein. Echte Gesichter, echte Gespräche.",
        "Probier etwas zu kochen, was du noch nie gemacht hast.",
        "Geh mit einem Buch ins Café. Kein Laptop.",
        "Mach Fotos von deiner Nachbarschaft. Sieh sie mit neuen Augen.",
        "Schreib Briefe — echte Briefe — an 2 Menschen, die du liebst.",
        "Fang ein Projekt an, das seit Monaten auf deiner Liste steht."
    ]

    // MARK: - Weather-specific suggestions

    static let rainyEN: [String] = [
        "Perfect weather for a book and hot tea. Get cozy.",
        "Rain is the best soundtrack for reading. Find a book.",
        "Listen to the rain for 5 minutes. Real mindfulness.",
        "Cozy up with a warm drink. Watch the weather happen.",
        "Rainy day = perfect for organizing that drawer you've been avoiding.",
        "Put on comfy clothes. Make soup. Slow down.",
        "Call someone and listen to the rain together.",
        "Journal while it rains. Something about rain helps thoughts flow.",
        "Stretch and listen to the rain. No rush today."
    ]

    static let rainyGR: [String] = [
        "Τέλειος καιρός για βιβλίο και ζεστό τσάι. Ζεστάσου.",
        "Η βροχή είναι το καλύτερο soundtrack για διάβασμα. Βρες ένα βιβλίο.",
        "Άκου τη βροχή για 5 λεπτά. Αληθινό mindfulness.",
        "Ζεστάσου με ζεστό ρόφημα. Δες τον καιρό να γίνεται.",
        "Βροχερή μέρα = τέλεια για να τακτοποιήσεις το συρτάρι που αποφεύγεις.",
        "Βάλε άνετα ρούχα. Φτιάξε σούπα. Αργά.",
        "Πάρε κάποιον τηλέφωνο και ακούστε τη βροχή μαζί.",
        "Γράψε ημερολόγιο όσο βρέχει. Η βροχή βοηθάει τις σκέψεις.",
        "Κάνε stretching ακούγοντας τη βροχή. Χωρίς βιασύνη σήμερα."
    ]

    static let rainyDE: [String] = [
        "Perfektes Wetter für ein Buch und heißen Tee. Mach es dir gemütlich.",
        "Regen ist der beste Soundtrack zum Lesen. Such ein Buch.",
        "Hör 5 Minuten dem Regen zu. Echte Achtsamkeit.",
        "Kuschel dich ein mit einem warmen Getränk. Schau dem Wetter zu.",
        "Regentag = perfekt, um die Schublade zu ordnen, die du meidest.",
        "Zieh bequeme Kleidung an. Koch Suppe. Verlangsame.",
        "Ruf jemanden an und hört gemeinsam dem Regen zu.",
        "Schreib Tagebuch im Regen. Regen hilft den Gedanken zu fließen.",
        "Dehne dich beim Regengeräusch. Keine Eile heute."
    ]

    static let hotEN: [String] = [
        "It's hot. Drink a full glass of cold water right now.",
        "Hot day. Take a cool shower. You'll feel amazing.",
        "Find shade. Read something outside in a cool spot.",
        "Too hot for a walk? Stretch inside for 10 minutes.",
        "Freeze some fruit and eat it slowly. Natural cooling.",
        "Put feet in cold water for 2 minutes. Instant cooling.",
        "Close the curtains. Cool room = calm mind.",
        "Make iced tea. Cold drink, slow sip, real pause."
    ]

    static let hotGR: [String] = [
        "Έχει ζέστη. Πιες ένα γεμάτο ποτήρι κρύο νερό τώρα.",
        "Ζεστή μέρα. Κάνε δροσερό ντους. Θα νιώσεις τέλεια.",
        "Βρες σκιά. Διάβασε κάτι έξω σε δροσερό μέρος.",
        "Πολύ ζέστη για περίπατο; Κάνε stretching μέσα 10 λεπτά.",
        "Βάλε φρούτα στην κατάψυξη και φάτα αργά. Φυσική δροσιά.",
        "Βάλε τα πόδια σε κρύο νερό 2 λεπτά. Άμεση δροσιά.",
        "Κλείσε τις κουρτίνες. Δροσερό δωμάτιο = ήρεμο μυαλό.",
        "Φτιάξε παγωμένο τσάι. Κρύο ποτό, αργή γουλιά, αληθινή παύση."
    ]

    static let hotDE: [String] = [
        "Es ist heiß. Trink jetzt ein volles Glas kaltes Wasser.",
        "Heißer Tag. Nimm eine kühle Dusche. Du wirst dich großartig fühlen.",
        "Such Schatten. Lies etwas draußen an einem kühlen Ort.",
        "Zu heiß zum Spazieren? Dehne dich drinnen 10 Minuten.",
        "Frier etwas Obst ein und iss es langsam. Natürliche Kühlung.",
        "Füße 2 Minuten in kaltes Wasser. Sofortige Kühlung.",
        "Zieh die Vorhänge zu. Kühler Raum = ruhiger Geist.",
        "Mach Eistee. Kaltes Getränk, langsamer Schluck, echte Pause."
    ]

    static let coldEN: [String] = [
        "It's cold out. Perfect excuse to cozy up with a book.",
        "Make a hot drink. Hold the cup. Feel the warmth.",
        "Layer up and go for a quick walk. Cold air is energizing.",
        "Warm bath or shower. 10 minutes of pure relaxation.",
        "Cook something warm. Soup, tea, hot chocolate — anything.",
        "Wrap in a blanket and read. This is what winter is for.",
        "Light a candle. Read by candlelight for 10 minutes."
    ]

    static let coldGR: [String] = [
        "Κάνει κρύο έξω. Τέλεια δικαιολογία για βιβλίο.",
        "Φτιάξε ζεστό ρόφημα. Κράτα την κούπα. Νιώσε τη ζέστη.",
        "Ντύσου ζεστά και πήγαινε γρήγορη βόλτα. Ο κρύος αέρας τονώνει.",
        "Ζεστό μπάνιο ή ντους. 10 λεπτά απόλυτης χαλάρωσης.",
        "Μαγείρεψε κάτι ζεστό. Σούπα, τσάι, ζεστή σοκολάτα — οτιδήποτε.",
        "Τυλίξου με κουβέρτα και διάβασε. Γι' αυτό υπάρχει ο χειμώνας.",
        "Άναψε ένα κερί. Διάβασε στο φως κεριού για 10 λεπτά."
    ]

    static let coldDE: [String] = [
        "Es ist kalt draußen. Perfekte Ausrede für ein Buch.",
        "Mach ein heißes Getränk. Halt die Tasse. Spüre die Wärme.",
        "Zieh dich warm an und mach einen kurzen Spaziergang. Kalte Luft belebt.",
        "Warmes Bad oder Dusche. 10 Minuten pure Entspannung.",
        "Koch etwas Warmes. Suppe, Tee, heiße Schokolade — alles.",
        "Wickel dich in eine Decke und lies. Dafür ist der Winter.",
        "Zünd eine Kerze an. Lies 10 Minuten bei Kerzenlicht."
    ]

    static let snowEN: [String] = [
        "It's snowing! Go outside for 5 minutes. Just look.",
        "Snow day. Hot chocolate + window + book = magic.",
        "Take photos of the snow. Then put the phone down.",
        "Bundle up and take a short snowy walk. Unforgettable."
    ]

    static let snowGR: [String] = [
        "Χιονίζει! Βγες έξω για 5 λεπτά. Απλά κοίτα.",
        "Χιονιάς. Ζεστή σοκολάτα + παράθυρο + βιβλίο = μαγεία.",
        "Βγάλε φωτογραφίες του χιονιού. Μετά άσ' το κάτω.",
        "Ντύσου ζεστά και πήγαινε σύντομο περίπατο στο χιόνι. Αξέχαστο."
    ]

    static let snowDE: [String] = [
        "Es schneit! Geh 5 Minuten raus. Schau einfach.",
        "Schneetag. Heiße Schokolade + Fenster + Buch = Magie.",
        "Mach Fotos vom Schnee. Dann leg es weg.",
        "Zieh dich warm an und mach einen kurzen Schneespaziergang. Unvergesslich."
    ]

    // MARK: - Random Activity (με anti-repetition)

    private static let recentKey = "picksyRecentActivities"
    private static let maxRecent = 5

    static func random(
        language: Language? = nil,
        date: Date = Date(),
        weather: WeatherCondition? = nil,
        categories: Set<ActivityCategory>? = nil
    ) -> String {
        let lang = language ?? savedLanguage()
        let timeSlot = currentTimeSlot(date: date)
        let isWeekend = Calendar.current.isDateInWeekend(date)

        // Συλλέγουμε activities για την τρέχουσα ώρα
        var pool: [String] = activitiesFor(timeSlot: timeSlot, language: lang)

        // Στο Σαββατοκύριακο προσθέτουμε και weekend bonus
        if isWeekend {
            pool.append(contentsOf: weekendActivitiesFor(language: lang))
        }

        // Φιλτράρισμα και προσθήκη weather-specific activities
        if let weather = weather {
            // Αφαίρεσε outdoor activities αν ο καιρός δεν είναι φιλικός
            if !weather.isOutdoorFriendly {
                pool = pool.filter { !isOutdoorActivity($0, language: lang) }
            }

            // Πρόσθεσε weather-specific suggestions
            pool.append(contentsOf: weatherSpecificActivities(weather: weather, language: lang))
        }

        // Φιλτράρισμα βάσει επιλεγμένων κατηγοριών
        if let cats = categories, !cats.isEmpty, cats.count < ActivityCategory.allCases.count {
            pool = pool.filter { matchesCategories($0, categories: cats, language: lang) }
        }

        // Anti-repetition: αποκλείουμε τις τελευταίες 5
        let recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        let filtered = pool.filter { !recent.contains($0) }

        // Αν όλες οι activities έχουν χρησιμοποιηθεί πρόσφατα, χρησιμοποιούμε όλες
        let candidates = filtered.isEmpty ? pool : filtered

        guard let chosen = candidates.randomElement() else {
            return fallback(language: lang)
        }

        // Αποθηκεύουμε την επιλογή
        saveRecent(chosen)
        return chosen
    }

    // MARK: - Category matching

    /// Ελέγχει αν μια activity ανήκει σε κάποια από τις επιλεγμένες κατηγορίες
    /// Αν δεν βρεθεί match, επιστρέφει true (default inclusion για γενικές προτάσεις)
    private static func matchesCategories(_ text: String, categories: Set<ActivityCategory>, language: Language) -> Bool {
        let lower = text.lowercased()

        // Εντόπισε την κατηγορία του κειμένου
        let detectedCategories = detectCategories(lower, language: language)

        // Αν δεν ανιχνεύτηκε καμία κατηγορία, συμπεριέλαβέ την (γενική πρόταση)
        if detectedCategories.isEmpty {
            return true
        }

        // Περιλαμβάνεται αν ΜΙΑ από τις κατηγορίες της είναι επιλεγμένη
        return !detectedCategories.isDisjoint(with: categories)
    }

    private static func detectCategories(_ lower: String, language: Language) -> Set<ActivityCategory> {
        var detected: Set<ActivityCategory> = []

        for category in ActivityCategory.allCases {
            let keywords = categoryKeywords(category, language: language)
            if keywords.contains(where: { lower.contains($0) }) {
                detected.insert(category)
            }
        }
        return detected
    }

    /// Keywords που αναγνωρίζουν κάθε κατηγορία σε 3 γλώσσες
    private static func categoryKeywords(_ category: ActivityCategory, language: Language) -> [String] {
        switch (category, language) {

        // Movement & nature
        case (.movement, .english):
            return ["walk", "outside", "outdoor", "park", "sun", "stairs", "fresh air", "snowy walk"]
        case (.movement, .greek):
            return ["περίπατ", "βόλτ", "έξω", "ήλιο", "σκάλα", "φρέσκο αέρα"]
        case (.movement, .german):
            return ["spazier", "draußen", "raus", "sonne", "treppe", "frische luft"]

        // Mindfulness
        case (.mindfulness, .english):
            return ["breath", "meditat", "mindful", "silence", "body scan", "reflect", "quiet"]
        case (.mindfulness, .greek):
            return ["αναπνο", "διαλογισμ", "σιωπή", "body scan", "αναλογίσου", "ήρεμ"]
        case (.mindfulness, .german):
            return ["atem", "meditat", "achtsam", "stille", "bodyscan", "reflek", "ruhig"]

        // Fitness
        case (.fitness, .english):
            return ["squat", "push-up", "stretch", "exercise", "workout", "yoga", "dance", "movement you enjoy"]
        case (.fitness, .greek):
            return ["squat", "push-up", "stretching", "άσκηση", "γιόγκα", "χορό", "γυμναστ"]
        case (.fitness, .german):
            return ["kniebeuge", "liegestütz", "dehn", "übung", "yoga", "tanz", "bewegung"]

        // Reading
        case (.reading, .english):
            return ["read", "book", "chapter", "journal", "poetry", "write down"]
        case (.reading, .greek):
            return ["διάβασε", "βιβλίο", "κεφάλαιο", "ημερολόγι", "ποίηση", "γράψε"]
        case (.reading, .german):
            return ["lies", "buch", "kapitel", "tagebuch", "gedicht", "schreib"]

        // Cooking
        case (.cooking, .english):
            return ["breakfast", "cook", "meal", "tea", "coffee", "drink", "eat", "snack", "soup", "chocolate"]
        case (.cooking, .greek):
            return ["πρωινό", "μαγείρεψ", "γεύμα", "τσάι", "καφέ", "ρόφημα", "φάε", "σνακ", "σούπ", "σοκολάτ"]
        case (.cooking, .german):
            return ["frühstück", "koch", "mahlzeit", "tee", "kaffee", "getränk", "iss", "snack", "suppe", "schokolade"]

        // Creative
        case (.creative, .english):
            return ["draw", "music", "album", "creative", "photo", "play music", "listen"]
        case (.creative, .greek):
            return ["ζωγραφ", "μουσική", "άλμπουμ", "δημιουργ", "φωτογραφ", "άκου"]
        case (.creative, .german):
            return ["zeichne", "musik", "album", "kreativ", "foto", "musik spiel", "hör"]

        // Social
        case (.social, .english):
            return ["call", "friend", "family", "letter", "message", "conversation", "invite"]
        case (.social, .greek):
            return ["τηλέφωνο", "φίλο", "οικογένει", "γράμμα", "μήνυμα", "συζήτηση", "κάλεσε", "πάρε τηλέφωνο", "στείλε"]
        case (.social, .german):
            return ["ruf", "freund", "familie", "brief", "nachricht", "gespräch", "einlad"]

        // Home
        case (.home, .english):
            return ["tidy", "organize", "clean", "plant", "drawer", "prepare", "space"]
        case (.home, .greek):
            return ["τακτοποίησ", "οργάνωσ", "καθαρ", "φυτ", "συρτάρι", "ετοίμασε", "χώρο"]
        case (.home, .german):
            return ["aufräum", "ordne", "pflanz", "schublade", "bereit", "raum"]

        // Health
        case (.health, .english):
            return ["water", "sleep", "shower", "hydrat", "rest", "sip", "breath"]
        case (.health, .greek):
            return ["νερό", "ύπνο", "κοιμ", "ντους", "αφυδατ", "ανάπαυσ", "γουλιά"]
        case (.health, .german):
            return ["wasser", "schlaf", "dusche", "dehydri", "ruh", "schluck"]
        }
    }


    // MARK: - Weather helpers

    private static func weatherSpecificActivities(weather: WeatherCondition, language: Language) -> [String] {
        switch (weather, language) {
        case (.rainy, .english), (.thunderstorm, .english): return rainyEN
        case (.rainy, .greek),   (.thunderstorm, .greek):   return rainyGR
        case (.rainy, .german),  (.thunderstorm, .german):  return rainyDE

        case (.hot, .english): return hotEN
        case (.hot, .greek):   return hotGR
        case (.hot, .german):  return hotDE

        case (.cold, .english): return coldEN
        case (.cold, .greek):   return coldGR
        case (.cold, .german):  return coldDE

        case (.snow, .english): return snowEN
        case (.snow, .greek):   return snowGR
        case (.snow, .german):  return snowDE

        default: return []
        }
    }

    /// Αναγνωρίζει outdoor activities βάσει keywords
    private static func isOutdoorActivity(_ text: String, language: Language) -> Bool {
        let lower = text.lowercased()
        switch language {
        case .english:
            return lower.contains("walk") || lower.contains("outside") ||
                   lower.contains("outdoor") || lower.contains("park") ||
                   lower.contains("sun") || lower.contains("stairs")
        case .greek:
            return lower.contains("περίπατ") || lower.contains("βόλτ") ||
                   lower.contains("έξω") || lower.contains("ήλιο") ||
                   lower.contains("σκάλα")
        case .german:
            return lower.contains("spazier") || lower.contains("draußen") ||
                   lower.contains("raus") || lower.contains("sonne") ||
                   lower.contains("treppe")
        }
    }

    private static func currentTimeSlot(date: Date) -> TimeSlot {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        case 20..<24: return .night
        default:      return .lateNight
        }
    }

    private static func activitiesFor(timeSlot: TimeSlot, language: Language) -> [String] {
        switch (timeSlot, language) {
        case (.morning, .english):   return morningEN
        case (.morning, .greek):     return morningGR
        case (.morning, .german):    return morningDE
        case (.afternoon, .english): return afternoonEN
        case (.afternoon, .greek):   return afternoonGR
        case (.afternoon, .german):  return afternoonDE
        case (.evening, .english):   return eveningEN
        case (.evening, .greek):     return eveningGR
        case (.evening, .german):    return eveningDE
        case (.night, .english):     return nightEN
        case (.night, .greek):       return nightGR
        case (.night, .german):      return nightDE
        case (.lateNight, .english): return lateNightEN
        case (.lateNight, .greek):   return lateNightGR
        case (.lateNight, .german):  return lateNightDE
        }
    }

    private static func weekendActivitiesFor(language: Language) -> [String] {
        switch language {
        case .english: return weekendEN
        case .greek:   return weekendGR
        case .german:  return weekendDE
        }
    }

    private static func saveRecent(_ activity: String) {
        var recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        recent.append(activity)
        // Κρατάμε μόνο τις τελευταίες 5
        if recent.count > maxRecent {
            recent = Array(recent.suffix(maxRecent))
        }
        UserDefaults.standard.set(recent, forKey: recentKey)
    }

    private static func savedLanguage() -> Language {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        return Language(rawValue: raw) ?? .english
    }

    private static func fallback(language: Language) -> String {
        switch language {
        case .english: return "Put it down. Do something real."
        case .greek:   return "Βάλ' το κάτω. Κάνε κάτι αληθινό."
        case .german:  return "Leg es weg. Tu etwas Echtes."
        }
    }
}

