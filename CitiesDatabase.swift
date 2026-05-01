//
//  CitiesDatabase.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  1000+ πόλεις με localized names (EN/GR/DE) και flag emojis.
//  Χωρισμένο σε 2 αρχεία για διαχειρισιμότητα:
//  - CitiesDatabase.swift (Ευρώπη - core markets)
//  - CitiesDatabaseWorld.swift (Υπόλοιπος κόσμος)

import Foundation

struct City: Identifiable, Hashable {
    let id: String
    let nameEN: String
    let nameGR: String
    let nameDE: String
    let country: String
    let countryFlag: String
    let countryNameEN: String
    let countryNameGR: String
    let countryNameDE: String

    func localizedName(language: String) -> String {
        switch language {
        case "Ελληνικά": return nameGR
        case "Deutsch":  return nameDE
        default:         return nameEN
        }
    }

    func localizedCountry(language: String) -> String {
        switch language {
        case "Ελληνικά": return countryNameGR
        case "Deutsch":  return countryNameDE
        default:         return countryNameEN
        }
    }
}

struct CitiesDatabase {

    // MARK: - Helper

    static func c(_ id: String, _ en: String, _ gr: String, _ de: String,
                  country: String, flag: String,
                  countryEN: String, countryGR: String, countryDE: String) -> City {
        City(id: id, nameEN: en, nameGR: gr, nameDE: de,
             country: country, countryFlag: flag,
             countryNameEN: countryEN, countryNameGR: countryGR, countryNameDE: countryDE)
    }

    // Country shortcuts για να μειώσουμε verbosity
    static let GR = (flag: "🇬🇷", en: "Greece", gr: "Ελλάδα", de: "Griechenland")
    static let CY = (flag: "🇨🇾", en: "Cyprus", gr: "Κύπρος", de: "Zypern")
    static let DE = (flag: "🇩🇪", en: "Germany", gr: "Γερμανία", de: "Deutschland")
    static let AT = (flag: "🇦🇹", en: "Austria", gr: "Αυστρία", de: "Österreich")
    static let CH = (flag: "🇨🇭", en: "Switzerland", gr: "Ελβετία", de: "Schweiz")
    static let UK = (flag: "🇬🇧", en: "United Kingdom", gr: "Ηνωμένο Βασίλειο", de: "Vereinigtes Königreich")
    static let IE = (flag: "🇮🇪", en: "Ireland", gr: "Ιρλανδία", de: "Irland")
    static let FR = (flag: "🇫🇷", en: "France", gr: "Γαλλία", de: "Frankreich")
    static let IT = (flag: "🇮🇹", en: "Italy", gr: "Ιταλία", de: "Italien")
    static let ES = (flag: "🇪🇸", en: "Spain", gr: "Ισπανία", de: "Spanien")
    static let PT = (flag: "🇵🇹", en: "Portugal", gr: "Πορτογαλία", de: "Portugal")
    static let NL = (flag: "🇳🇱", en: "Netherlands", gr: "Ολλανδία", de: "Niederlande")
    static let BE = (flag: "🇧🇪", en: "Belgium", gr: "Βέλγιο", de: "Belgien")
    static let LU = (flag: "🇱🇺", en: "Luxembourg", gr: "Λουξεμβούργο", de: "Luxemburg")

    // MARK: - Europe Core Cities

    static let europe: [City] = [

        // MARK: Greece (🇬🇷) — όλες οι πρωτεύουσες νομών + τουριστικά νησιά
        c("athens_gr", "Athens", "Αθήνα", "Athen", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("thessaloniki_gr", "Thessaloniki", "Θεσσαλονίκη", "Thessaloniki", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("patra_gr", "Patras", "Πάτρα", "Patras", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("piraeus_gr", "Piraeus", "Πειραιάς", "Piräus", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("larisa_gr", "Larissa", "Λάρισα", "Larisa", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("heraklion_gr", "Heraklion", "Ηράκλειο", "Heraklion", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("volos_gr", "Volos", "Βόλος", "Volos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("ioannina_gr", "Ioannina", "Ιωάννινα", "Ioannina", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("chania_gr", "Chania", "Χανιά", "Chania", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("rhodes_gr", "Rhodes", "Ρόδος", "Rhodos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kalamata_gr", "Kalamata", "Καλαμάτα", "Kalamata", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kavala_gr", "Kavala", "Καβάλα", "Kavala", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("serres_gr", "Serres", "Σέρρες", "Serres", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("alexandroupoli_gr", "Alexandroupoli", "Αλεξανδρούπολη", "Alexandroupoli", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("xanthi_gr", "Xanthi", "Ξάνθη", "Xanthi", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("katerini_gr", "Katerini", "Κατερίνη", "Katerini", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("agrinio_gr", "Agrinio", "Αγρίνιο", "Agrinio", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("trikala_gr", "Trikala", "Τρίκαλα", "Trikala", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("chalkida_gr", "Chalcis", "Χαλκίδα", "Chalkida", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("corfu_gr", "Corfu", "Κέρκυρα", "Korfu", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kos_gr", "Kos", "Κως", "Kos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("mykonos_gr", "Mykonos", "Μύκονος", "Mykonos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("santorini_gr", "Santorini", "Σαντορίνη", "Santorin", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("naxos_gr", "Naxos", "Νάξος", "Naxos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("syros_gr", "Syros", "Σύρος", "Syros", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("lamia_gr", "Lamia", "Λαμία", "Lamia", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("komotini_gr", "Komotini", "Κομοτηνή", "Komotini", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("veria_gr", "Veria", "Βέροια", "Veria", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kozani_gr", "Kozani", "Κοζάνη", "Kozani", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("drama_gr", "Drama", "Δράμα", "Drama", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("tripoli_gr", "Tripoli", "Τρίπολη", "Tripoli", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("sparta_gr", "Sparta", "Σπάρτη", "Sparta", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("nafplio_gr", "Nafplio", "Ναύπλιο", "Nafplio", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("argos_gr", "Argos", "Άργος", "Argos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("corinth_gr", "Corinth", "Κόρινθος", "Korinth", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("pyrgos_gr", "Pyrgos", "Πύργος", "Pyrgos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("amaliada_gr", "Amaliada", "Αμαλιάδα", "Amaliada", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("aigio_gr", "Aigio", "Αίγιο", "Aigio", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("rethymno_gr", "Rethymno", "Ρέθυμνο", "Rethymno", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("agios_nikolaos_gr", "Agios Nikolaos", "Άγιος Νικόλαος", "Agios Nikolaos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("ierapetra_gr", "Ierapetra", "Ιεράπετρα", "Ierapetra", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("arta_gr", "Arta", "Άρτα", "Arta", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("preveza_gr", "Preveza", "Πρέβεζα", "Preveza", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("lefkada_gr", "Lefkada", "Λευκάδα", "Lefkada", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("zakynthos_gr", "Zakynthos", "Ζάκυνθος", "Zakynthos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kefalonia_gr", "Kefalonia", "Κεφαλονιά", "Kefalonia", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("ithaca_gr", "Ithaca", "Ιθάκη", "Ithaka", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("karpenisi_gr", "Karpenisi", "Καρπενήσι", "Karpenisi", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("livadeia_gr", "Livadeia", "Λιβαδειά", "Livadia", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("thebes_gr", "Thebes", "Θήβα", "Theben", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("karditsa_gr", "Karditsa", "Καρδίτσα", "Karditsa", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kilkis_gr", "Kilkis", "Κιλκίς", "Kilkis", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("edessa_gr", "Edessa", "Έδεσσα", "Edessa", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("florina_gr", "Florina", "Φλώρινα", "Florina", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kastoria_gr", "Kastoria", "Καστοριά", "Kastoria", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("grevena_gr", "Grevena", "Γρεβενά", "Grevena", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("polygyros_gr", "Polygyros", "Πολύγυρος", "Polygyros", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("chios_gr", "Chios", "Χίος", "Chios", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("mytilene_gr", "Mytilene", "Μυτιλήνη", "Mytilini", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("samos_gr", "Samos", "Σάμος", "Samos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("ikaria_gr", "Ikaria", "Ικαρία", "Ikaria", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("limnos_gr", "Limnos", "Λήμνος", "Limnos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("paros_gr", "Paros", "Πάρος", "Paros", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("milos_gr", "Milos", "Μήλος", "Milos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("tinos_gr", "Tinos", "Τήνος", "Tinos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("andros_gr", "Andros", "Άνδρος", "Andros", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("karpathos_gr", "Karpathos", "Κάρπαθος", "Karpathos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kalymnos_gr", "Kalymnos", "Κάλυμνος", "Kalymnos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("leros_gr", "Leros", "Λέρος", "Leros", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("patmos_gr", "Patmos", "Πάτμος", "Patmos", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("aegina_gr", "Aegina", "Αίγινα", "Ägina", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("hydra_gr", "Hydra", "Ύδρα", "Hydra", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("poros_gr", "Poros", "Πόρος", "Poros", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("spetses_gr", "Spetses", "Σπέτσες", "Spetses", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("salamina_gr", "Salamina", "Σαλαμίνα", "Salamis", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("glyfada_gr", "Glyfada", "Γλυφάδα", "Glyfada", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("marousi_gr", "Marousi", "Μαρούσι", "Marousi", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("kallithea_gr", "Kallithea", "Καλλιθέα", "Kallithea", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("peristeri_gr", "Peristeri", "Περιστέρι", "Peristeri", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),
        c("nikaia_gr", "Nikaia", "Νίκαια", "Nikea", country: "GR", flag: GR.flag, countryEN: GR.en, countryGR: GR.gr, countryDE: GR.de),

        // MARK: Cyprus (🇨🇾)
        c("nicosia_cy", "Nicosia", "Λευκωσία", "Nikosia", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("limassol_cy", "Limassol", "Λεμεσός", "Limassol", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("larnaca_cy", "Larnaca", "Λάρνακα", "Larnaka", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("paphos_cy", "Paphos", "Πάφος", "Paphos", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("famagusta_cy", "Famagusta", "Αμμόχωστος", "Famagusta", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("kyrenia_cy", "Kyrenia", "Κερύνεια", "Kyrenia", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("paralimni_cy", "Paralimni", "Παραλίμνι", "Paralimni", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),
        c("ayia_napa_cy", "Ayia Napa", "Αγία Νάπα", "Ayia Napa", country: "CY", flag: CY.flag, countryEN: CY.en, countryGR: CY.gr, countryDE: CY.de),

        // MARK: Germany (🇩🇪) — 60+ πόλεις
        c("berlin_de", "Berlin", "Βερολίνο", "Berlin", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("hamburg_de", "Hamburg", "Αμβούργο", "Hamburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("munich_de", "Munich", "Μόναχο", "München", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("cologne_de", "Cologne", "Κολωνία", "Köln", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("frankfurt_de", "Frankfurt", "Φρανκφούρτη", "Frankfurt", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("stuttgart_de", "Stuttgart", "Στουτγκάρδη", "Stuttgart", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("muhlacker_de", "Mühlacker", "Μύλακερ", "Mühlacker", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("dusseldorf_de", "Düsseldorf", "Ντίσελντορφ", "Düsseldorf", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("leipzig_de", "Leipzig", "Λειψία", "Leipzig", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("dortmund_de", "Dortmund", "Ντόρτμουντ", "Dortmund", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("essen_de", "Essen", "Έσσεν", "Essen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("bremen_de", "Bremen", "Βρέμη", "Bremen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("dresden_de", "Dresden", "Δρέσδη", "Dresden", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("hanover_de", "Hanover", "Ανόβερο", "Hannover", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("nuremberg_de", "Nuremberg", "Νυρεμβέργη", "Nürnberg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("erlangen_de", "Erlangen", "Έρλανγκεν", "Erlangen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("duisburg_de", "Duisburg", "Ντούισμπουργκ", "Duisburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("bochum_de", "Bochum", "Μπόχουμ", "Bochum", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("wuppertal_de", "Wuppertal", "Βούπερταλ", "Wuppertal", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("bielefeld_de", "Bielefeld", "Μπίλεφελντ", "Bielefeld", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("bonn_de", "Bonn", "Βόννη", "Bonn", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("mannheim_de", "Mannheim", "Μάνχαϊμ", "Mannheim", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("karlsruhe_de", "Karlsruhe", "Καρλσρούη", "Karlsruhe", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("augsburg_de", "Augsburg", "Αυγούστα", "Augsburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("wiesbaden_de", "Wiesbaden", "Βισμπάντεν", "Wiesbaden", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("freiburg_de", "Freiburg", "Φράιμπουργκ", "Freiburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("vaihingen_de", "Vaihingen", "Φαϊχίνγκεν", "Vaihingen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("mainz_de", "Mainz", "Μάιντζ", "Mainz", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("kiel_de", "Kiel", "Κίελο", "Kiel", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("lubeck_de", "Lübeck", "Λίμπεκ", "Lübeck", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("rostock_de", "Rostock", "Ρόστοκ", "Rostock", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("magdeburg_de", "Magdeburg", "Μαγδεμβούργο", "Magdeburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("halle_de", "Halle", "Χάλλε", "Halle", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("erfurt_de", "Erfurt", "Έρφουρτ", "Erfurt", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("jena_de", "Jena", "Ιένα", "Jena", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("chemnitz_de", "Chemnitz", "Χέμνιτς", "Chemnitz", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("saarbrucken_de", "Saarbrücken", "Ζάαρμπρουκεν", "Saarbrücken", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("braunschweig_de", "Braunschweig", "Μπράουνσβαϊγκ", "Braunschweig", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("gelsenkirchen_de", "Gelsenkirchen", "Γκέλζενκιρχεν", "Gelsenkirchen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("monchengladbach_de", "Mönchengladbach", "Μένχενγκλαντμπαχ", "Mönchengladbach", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("aachen_de", "Aachen", "Άαχεν", "Aachen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("krefeld_de", "Krefeld", "Κρέφελντ", "Krefeld", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("lubeck2_de", "Oberhausen", "Όμπερχαουζεν", "Oberhausen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("hagen_de", "Hagen", "Χάγκεν", "Hagen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("kassel_de", "Kassel", "Κάσελ", "Kassel", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("saarlouis_de", "Saarlouis", "Ζάαρλουις", "Saarlouis", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("potsdam_de", "Potsdam", "Πότσνταμ", "Potsdam", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("ingolstadt_de", "Ingolstadt", "Ίνγκολσταντ", "Ingolstadt", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("regensburg_de", "Regensburg", "Ρέγκενσμπουργκ", "Regensburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("wurzburg_de", "Würzburg", "Βίρτσμπουργκ", "Würzburg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("ulm_de", "Ulm", "Ουλμ", "Ulm", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("heidelberg_de", "Heidelberg", "Χαϊδελβέργη", "Heidelberg", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("darmstadt_de", "Darmstadt", "Ντάρμστατ", "Darmstadt", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("paderborn_de", "Paderborn", "Πάντερμπορν", "Paderborn", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("osnabruck_de", "Osnabrück", "Οσναμπρουκ", "Osnabrück", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("trier_de", "Trier", "Τρίερ", "Trier", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("gottingen_de", "Göttingen", "Γκέτινγκεν", "Göttingen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("koblenz_de", "Koblenz", "Κόμπλεντζ", "Koblenz", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("reutlingen_de", "Reutlingen", "Ρόιτλινγκεν", "Reutlingen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("tubingen_de", "Tübingen", "Τίμπινγκεν", "Tübingen", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("konstanz_de", "Konstanz", "Κωνστάντσα", "Konstanz", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("baden_baden_de", "Baden-Baden", "Μπάντεν-Μπάντεν", "Baden-Baden", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("garmisch_de", "Garmisch", "Γκάρμις", "Garmisch", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),
        c("rosenheim_de", "Rosenheim", "Ρόζενχαϊμ", "Rosenheim", country: "DE", flag: DE.flag, countryEN: DE.en, countryGR: DE.gr, countryDE: DE.de),

        // MARK: Austria (🇦🇹)
        c("vienna_at", "Vienna", "Βιέννη", "Wien", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("graz_at", "Graz", "Γκρατς", "Graz", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("salzburg_at", "Salzburg", "Σάλτσμπουργκ", "Salzburg", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("innsbruck_at", "Innsbruck", "Ίνσμπρουκ", "Innsbruck", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("linz_at", "Linz", "Λιντς", "Linz", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("klagenfurt_at", "Klagenfurt", "Κλάγκενφουρτ", "Klagenfurt", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("villach_at", "Villach", "Βίλαχ", "Villach", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("wels_at", "Wels", "Βελς", "Wels", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("bregenz_at", "Bregenz", "Μπρέγκεντς", "Bregenz", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),
        c("st_polten_at", "St. Pölten", "Άγιος Πέλτεν", "St. Pölten", country: "AT", flag: AT.flag, countryEN: AT.en, countryGR: AT.gr, countryDE: AT.de),

        // MARK: Switzerland (🇨🇭)
        c("zurich_ch", "Zurich", "Ζυρίχη", "Zürich", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("geneva_ch", "Geneva", "Γενεύη", "Genf", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("basel_ch", "Basel", "Βασιλεία", "Basel", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("bern_ch", "Bern", "Βέρνη", "Bern", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("lausanne_ch", "Lausanne", "Λωζάννη", "Lausanne", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("lucerne_ch", "Lucerne", "Λουκέρνη", "Luzern", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("st_gallen_ch", "St. Gallen", "Άγιος Γκάλεν", "St. Gallen", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("lugano_ch", "Lugano", "Λουγκάνο", "Lugano", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("winterthur_ch", "Winterthur", "Βίντερτουρ", "Winterthur", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("zermatt_ch", "Zermatt", "Ζερμάτ", "Zermatt", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("davos_ch", "Davos", "Νταβός", "Davos", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),
        c("interlaken_ch", "Interlaken", "Ίντερλάκεν", "Interlaken", country: "CH", flag: CH.flag, countryEN: CH.en, countryGR: CH.gr, countryDE: CH.de),

        // MARK: United Kingdom (🇬🇧)
        c("london_uk", "London", "Λονδίνο", "London", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("manchester_uk", "Manchester", "Μάντσεστερ", "Manchester", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("birmingham_uk", "Birmingham", "Μπέρμιγχαμ", "Birmingham", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("liverpool_uk", "Liverpool", "Λίβερπουλ", "Liverpool", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("glasgow_uk", "Glasgow", "Γλασκώβη", "Glasgow", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("edinburgh_uk", "Edinburgh", "Εδιμβούργο", "Edinburgh", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("bristol_uk", "Bristol", "Μπρίστολ", "Bristol", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("leeds_uk", "Leeds", "Λιντς", "Leeds", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("sheffield_uk", "Sheffield", "Σέφιλντ", "Sheffield", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("cardiff_uk", "Cardiff", "Κάρντιφ", "Cardiff", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("belfast_uk", "Belfast", "Μπέλφαστ", "Belfast", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("newcastle_uk", "Newcastle", "Νιούκαστλ", "Newcastle", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("nottingham_uk", "Nottingham", "Νότιγχαμ", "Nottingham", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("leicester_uk", "Leicester", "Λέστερ", "Leicester", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("southampton_uk", "Southampton", "Σαουθάμπτον", "Southampton", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("brighton_uk", "Brighton", "Μπράιτον", "Brighton", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("oxford_uk", "Oxford", "Οξφόρδη", "Oxford", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("cambridge_uk", "Cambridge", "Κέιμπριτζ", "Cambridge", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("aberdeen_uk", "Aberdeen", "Άμπερντιν", "Aberdeen", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("dundee_uk", "Dundee", "Ντάντι", "Dundee", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("plymouth_uk", "Plymouth", "Πλίμουθ", "Plymouth", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("swansea_uk", "Swansea", "Σουόνσι", "Swansea", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("york_uk", "York", "Υόρκη", "York", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),
        c("bath_uk", "Bath", "Μπαθ", "Bath", country: "UK", flag: UK.flag, countryEN: UK.en, countryGR: UK.gr, countryDE: UK.de),

        // MARK: Ireland (🇮🇪)
        c("dublin_ie", "Dublin", "Δουβλίνο", "Dublin", country: "IE", flag: IE.flag, countryEN: IE.en, countryGR: IE.gr, countryDE: IE.de),
        c("cork_ie", "Cork", "Κορκ", "Cork", country: "IE", flag: IE.flag, countryEN: IE.en, countryGR: IE.gr, countryDE: IE.de),
        c("galway_ie", "Galway", "Γκόλγουεϊ", "Galway", country: "IE", flag: IE.flag, countryEN: IE.en, countryGR: IE.gr, countryDE: IE.de),
        c("limerick_ie", "Limerick", "Λίμερικ", "Limerick", country: "IE", flag: IE.flag, countryEN: IE.en, countryGR: IE.gr, countryDE: IE.de),
        c("waterford_ie", "Waterford", "Γουότερφορντ", "Waterford", country: "IE", flag: IE.flag, countryEN: IE.en, countryGR: IE.gr, countryDE: IE.de),
        c("kilkenny_ie", "Kilkenny", "Κιλκένι", "Kilkenny", country: "IE", flag: IE.flag, countryEN: IE.en, countryGR: IE.gr, countryDE: IE.de),

        // MARK: France (🇫🇷)
        c("paris_fr", "Paris", "Παρίσι", "Paris", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("marseille_fr", "Marseille", "Μασσαλία", "Marseille", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("lyon_fr", "Lyon", "Λυών", "Lyon", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("toulouse_fr", "Toulouse", "Τουλούζη", "Toulouse", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("nice_fr", "Nice", "Νίκαια", "Nizza", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("nantes_fr", "Nantes", "Νάντη", "Nantes", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("strasbourg_fr", "Strasbourg", "Στρασβούργο", "Straßburg", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("bordeaux_fr", "Bordeaux", "Μπορντώ", "Bordeaux", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("lille_fr", "Lille", "Λιλ", "Lille", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("rennes_fr", "Rennes", "Ρεν", "Rennes", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("reims_fr", "Reims", "Ρεμς", "Reims", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("montpellier_fr", "Montpellier", "Μονπελιέ", "Montpellier", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("cannes_fr", "Cannes", "Κάννες", "Cannes", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("monaco_fr", "Monaco", "Μονακό", "Monaco", country: "MC", flag: "🇲🇨", countryEN: "Monaco", countryGR: "Μονακό", countryDE: "Monaco"),
        c("grenoble_fr", "Grenoble", "Γκρενόμπλ", "Grenoble", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("dijon_fr", "Dijon", "Ντιζόν", "Dijon", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("angers_fr", "Angers", "Ανζέ", "Angers", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("nancy_fr", "Nancy", "Νανσί", "Nancy", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("toulon_fr", "Toulon", "Τουλόν", "Toulon", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),
        c("versailles_fr", "Versailles", "Βερσαλλίες", "Versailles", country: "FR", flag: FR.flag, countryEN: FR.en, countryGR: FR.gr, countryDE: FR.de),

        // MARK: Italy (🇮🇹)
        c("rome_it", "Rome", "Ρώμη", "Rom", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("milan_it", "Milan", "Μιλάνο", "Mailand", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("naples_it", "Naples", "Νάπολη", "Neapel", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("turin_it", "Turin", "Τορίνο", "Turin", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("palermo_it", "Palermo", "Παλέρμο", "Palermo", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("genoa_it", "Genoa", "Γένοβα", "Genua", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("bologna_it", "Bologna", "Μπολόνια", "Bologna", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("florence_it", "Florence", "Φλωρεντία", "Florenz", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("venice_it", "Venice", "Βενετία", "Venedig", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("verona_it", "Verona", "Βερόνα", "Verona", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("catania_it", "Catania", "Κατάνια", "Catania", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("bari_it", "Bari", "Μπάρι", "Bari", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("pisa_it", "Pisa", "Πίζα", "Pisa", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("siena_it", "Siena", "Σιένα", "Siena", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("parma_it", "Parma", "Πάρμα", "Parma", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("padua_it", "Padua", "Πάντοβα", "Padua", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("trieste_it", "Trieste", "Τεργέστη", "Triest", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("cagliari_it", "Cagliari", "Κάλιαρι", "Cagliari", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("catanzaro_it", "Catanzaro", "Κατανζάρο", "Catanzaro", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),
        c("perugia_it", "Perugia", "Περούτζια", "Perugia", country: "IT", flag: IT.flag, countryEN: IT.en, countryGR: IT.gr, countryDE: IT.de),

        // MARK: Spain (🇪🇸)
        c("madrid_es", "Madrid", "Μαδρίτη", "Madrid", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("barcelona_es", "Barcelona", "Βαρκελώνη", "Barcelona", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("valencia_es", "Valencia", "Βαλένθια", "Valencia", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("seville_es", "Seville", "Σεβίλλη", "Sevilla", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("zaragoza_es", "Zaragoza", "Σαραγόσα", "Saragossa", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("malaga_es", "Malaga", "Μάλαγα", "Málaga", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("bilbao_es", "Bilbao", "Μπιλμπάο", "Bilbao", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("palma_es", "Palma", "Πάλμα", "Palma", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("granada_es", "Granada", "Γρανάδα", "Granada", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("cordoba_es", "Cordoba", "Κόρδοβα", "Córdoba", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("alicante_es", "Alicante", "Αλικάντε", "Alicante", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("murcia_es", "Murcia", "Μούρθια", "Murcia", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("san_sebastian_es", "San Sebastian", "Σαν Σεμπαστιάν", "San Sebastián", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("toledo_es", "Toledo", "Τολέδο", "Toledo", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("salamanca_es", "Salamanca", "Σαλαμάνκα", "Salamanca", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("santander_es", "Santander", "Σανταντέρ", "Santander", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("tenerife_es", "Tenerife", "Τενερίφη", "Teneriffa", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("las_palmas_es", "Las Palmas", "Λας Πάλμας", "Las Palmas", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),
        c("ibiza_es", "Ibiza", "Ίμπιζα", "Ibiza", country: "ES", flag: ES.flag, countryEN: ES.en, countryGR: ES.gr, countryDE: ES.de),

        // MARK: Portugal (🇵🇹)
        c("lisbon_pt", "Lisbon", "Λισαβόνα", "Lissabon", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("porto_pt", "Porto", "Πόρτο", "Porto", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("braga_pt", "Braga", "Μπράγκα", "Braga", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("faro_pt", "Faro", "Φάρο", "Faro", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("coimbra_pt", "Coimbra", "Κοΐμπρα", "Coimbra", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("funchal_pt", "Funchal", "Φουντσάλ", "Funchal", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("aveiro_pt", "Aveiro", "Αβέιρο", "Aveiro", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("evora_pt", "Evora", "Έβορα", "Évora", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),
        c("cascais_pt", "Cascais", "Κασκάις", "Cascais", country: "PT", flag: PT.flag, countryEN: PT.en, countryGR: PT.gr, countryDE: PT.de),

        // MARK: Netherlands (🇳🇱)
        c("amsterdam_nl", "Amsterdam", "Άμστερνταμ", "Amsterdam", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("rotterdam_nl", "Rotterdam", "Ρότερνταμ", "Rotterdam", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("the_hague_nl", "The Hague", "Χάγη", "Den Haag", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("utrecht_nl", "Utrecht", "Ουτρέχτη", "Utrecht", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("eindhoven_nl", "Eindhoven", "Αϊντχόβεν", "Eindhoven", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("groningen_nl", "Groningen", "Γκρόνινγκεν", "Groningen", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("haarlem_nl", "Haarlem", "Χάαρλεμ", "Haarlem", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("maastricht_nl", "Maastricht", "Μάαστριχτ", "Maastricht", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("delft_nl", "Delft", "Ντελφτ", "Delft", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),
        c("leiden_nl", "Leiden", "Λέιντεν", "Leiden", country: "NL", flag: NL.flag, countryEN: NL.en, countryGR: NL.gr, countryDE: NL.de),

        // MARK: Belgium & Luxembourg
        c("brussels_be", "Brussels", "Βρυξέλλες", "Brüssel", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("antwerp_be", "Antwerp", "Αμβέρσα", "Antwerpen", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("ghent_be", "Ghent", "Γάνδη", "Gent", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("bruges_be", "Bruges", "Μπριζ", "Brügge", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("liege_be", "Liège", "Λιέγη", "Lüttich", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("leuven_be", "Leuven", "Λούβεν", "Löwen", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("namur_be", "Namur", "Ναμίρ", "Namur", country: "BE", flag: BE.flag, countryEN: BE.en, countryGR: BE.gr, countryDE: BE.de),
        c("luxembourg_lu", "Luxembourg", "Λουξεμβούργο", "Luxemburg", country: "LU", flag: LU.flag, countryEN: LU.en, countryGR: LU.gr, countryDE: LU.de)
    ]

    // MARK: - Combined All Cities (Europe + World)

    static var all: [City] {
        return europe + worldRest
    }

    // MARK: - Search

    static func search(query: String) -> [City] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }

        return all.filter { city in
            city.nameEN.lowercased().contains(trimmed) ||
            city.nameGR.lowercased().contains(trimmed) ||
            city.nameDE.lowercased().contains(trimmed) ||
            city.countryNameEN.lowercased().contains(trimmed) ||
            city.countryNameGR.lowercased().contains(trimmed) ||
            city.countryNameDE.lowercased().contains(trimmed)
        }
    }

    static func grouped(cities: [City], language: String) -> [(country: String, flag: String, cities: [City])] {
        let groupedDict = Dictionary(grouping: cities) { $0.country }

        return groupedDict.map { (countryCode, citiesInCountry) in
            let flag = citiesInCountry.first?.countryFlag ?? ""
            let countryName = citiesInCountry.first?.localizedCountry(language: language) ?? countryCode
            let sortedCities = citiesInCountry.sorted {
                $0.localizedName(language: language) < $1.localizedName(language: language)
            }
            return (country: countryName, flag: flag, cities: sortedCities)
        }
        .sorted { $0.country < $1.country }
    }

    static func find(id: String) -> City? {
        all.first { $0.id == id }
    }
}

