//
//  CitiesDatabaseWorld.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  Υπόλοιπες πόλεις του κόσμου.
//  Εκτενές set με ~650+ πόλεις συνολικά εδώ.

import Foundation

extension CitiesDatabase {

    // Country shortcuts
    private static let US = (flag: "🇺🇸", en: "USA", gr: "ΗΠΑ", de: "USA")
    private static let CA = (flag: "🇨🇦", en: "Canada", gr: "Καναδάς", de: "Kanada")
    private static let MX = (flag: "🇲🇽", en: "Mexico", gr: "Μεξικό", de: "Mexiko")
    private static let BR = (flag: "🇧🇷", en: "Brazil", gr: "Βραζιλία", de: "Brasilien")
    private static let AR = (flag: "🇦🇷", en: "Argentina", gr: "Αργεντινή", de: "Argentinien")
    private static let CL = (flag: "🇨🇱", en: "Chile", gr: "Χιλή", de: "Chile")
    private static let PE = (flag: "🇵🇪", en: "Peru", gr: "Περού", de: "Peru")
    private static let CO = (flag: "🇨🇴", en: "Colombia", gr: "Κολομβία", de: "Kolumbien")
    private static let JP = (flag: "🇯🇵", en: "Japan", gr: "Ιαπωνία", de: "Japan")
    private static let CN = (flag: "🇨🇳", en: "China", gr: "Κίνα", de: "China")
    private static let KR = (flag: "🇰🇷", en: "South Korea", gr: "Νότια Κορέα", de: "Südkorea")
    private static let IN = (flag: "🇮🇳", en: "India", gr: "Ινδία", de: "Indien")
    private static let TH = (flag: "🇹🇭", en: "Thailand", gr: "Ταϊλάνδη", de: "Thailand")
    private static let VN = (flag: "🇻🇳", en: "Vietnam", gr: "Βιετνάμ", de: "Vietnam")
    private static let ID = (flag: "🇮🇩", en: "Indonesia", gr: "Ινδονησία", de: "Indonesien")
    private static let MY = (flag: "🇲🇾", en: "Malaysia", gr: "Μαλαισία", de: "Malaysia")
    private static let PH = (flag: "🇵🇭", en: "Philippines", gr: "Φιλιππίνες", de: "Philippinen")
    private static let SG = (flag: "🇸🇬", en: "Singapore", gr: "Σιγκαπούρη", de: "Singapur")
    private static let AE = (flag: "🇦🇪", en: "UAE", gr: "ΗΑΕ", de: "VAE")
    private static let SA = (flag: "🇸🇦", en: "Saudi Arabia", gr: "Σαουδική Αραβία", de: "Saudi-Arabien")
    private static let IL = (flag: "🇮🇱", en: "Israel", gr: "Ισραήλ", de: "Israel")
    private static let TR = (flag: "🇹🇷", en: "Turkey", gr: "Τουρκία", de: "Türkei")
    private static let EG = (flag: "🇪🇬", en: "Egypt", gr: "Αίγυπτος", de: "Ägypten")
    private static let ZA = (flag: "🇿🇦", en: "South Africa", gr: "Νότια Αφρική", de: "Südafrika")
    private static let MA = (flag: "🇲🇦", en: "Morocco", gr: "Μαρόκο", de: "Marokko")
    private static let NG = (flag: "🇳🇬", en: "Nigeria", gr: "Νιγηρία", de: "Nigeria")
    private static let KE = (flag: "🇰🇪", en: "Kenya", gr: "Κένυα", de: "Kenia")
    private static let AU = (flag: "🇦🇺", en: "Australia", gr: "Αυστραλία", de: "Australien")
    private static let NZ = (flag: "🇳🇿", en: "New Zealand", gr: "Νέα Ζηλανδία", de: "Neuseeland")
    private static let SE = (flag: "🇸🇪", en: "Sweden", gr: "Σουηδία", de: "Schweden")
    private static let NO = (flag: "🇳🇴", en: "Norway", gr: "Νορβηγία", de: "Norwegen")
    private static let DK = (flag: "🇩🇰", en: "Denmark", gr: "Δανία", de: "Dänemark")
    private static let FI = (flag: "🇫🇮", en: "Finland", gr: "Φινλανδία", de: "Finnland")
    private static let IS = (flag: "🇮🇸", en: "Iceland", gr: "Ισλανδία", de: "Island")
    private static let PL = (flag: "🇵🇱", en: "Poland", gr: "Πολωνία", de: "Polen")
    private static let CZ = (flag: "🇨🇿", en: "Czech Republic", gr: "Τσεχία", de: "Tschechien")
    private static let HU = (flag: "🇭🇺", en: "Hungary", gr: "Ουγγαρία", de: "Ungarn")
    private static let SK = (flag: "🇸🇰", en: "Slovakia", gr: "Σλοβακία", de: "Slowakei")
    private static let RO = (flag: "🇷🇴", en: "Romania", gr: "Ρουμανία", de: "Rumänien")
    private static let BG = (flag: "🇧🇬", en: "Bulgaria", gr: "Βουλγαρία", de: "Bulgarien")
    private static let SI = (flag: "🇸🇮", en: "Slovenia", gr: "Σλοβενία", de: "Slowenien")
    private static let HR = (flag: "🇭🇷", en: "Croatia", gr: "Κροατία", de: "Kroatien")
    private static let RS = (flag: "🇷🇸", en: "Serbia", gr: "Σερβία", de: "Serbien")
    private static let BA = (flag: "🇧🇦", en: "Bosnia", gr: "Βοσνία", de: "Bosnien")
    private static let MK = (flag: "🇲🇰", en: "North Macedonia", gr: "Βόρεια Μακεδονία", de: "Nordmazedonien")
    private static let AL = (flag: "🇦🇱", en: "Albania", gr: "Αλβανία", de: "Albanien")
    private static let ME = (flag: "🇲🇪", en: "Montenegro", gr: "Μαυροβούνιο", de: "Montenegro")
    private static let RU = (flag: "🇷🇺", en: "Russia", gr: "Ρωσία", de: "Russland")
    private static let UA = (flag: "🇺🇦", en: "Ukraine", gr: "Ουκρανία", de: "Ukraine")

    // MARK: - Rest of Europe + World

    static let worldRest: [City] = [

        // MARK: Nordic countries
        c("stockholm_se", "Stockholm", "Στοκχόλμη", "Stockholm", country: "SE", flag: SE.flag, countryEN: SE.en, countryGR: SE.gr, countryDE: SE.de),
        c("gothenburg_se", "Gothenburg", "Γκέτεμποργκ", "Göteborg", country: "SE", flag: SE.flag, countryEN: SE.en, countryGR: SE.gr, countryDE: SE.de),
        c("malmo_se", "Malmö", "Μάλμε", "Malmö", country: "SE", flag: SE.flag, countryEN: SE.en, countryGR: SE.gr, countryDE: SE.de),
        c("uppsala_se", "Uppsala", "Ουψάλα", "Uppsala", country: "SE", flag: SE.flag, countryEN: SE.en, countryGR: SE.gr, countryDE: SE.de),
        c("vasteras_se", "Västerås", "Βάστερος", "Västerås", country: "SE", flag: SE.flag, countryEN: SE.en, countryGR: SE.gr, countryDE: SE.de),
        c("linkoping_se", "Linköping", "Λινκέπινγκ", "Linköping", country: "SE", flag: SE.flag, countryEN: SE.en, countryGR: SE.gr, countryDE: SE.de),
        c("oslo_no", "Oslo", "Όσλο", "Oslo", country: "NO", flag: NO.flag, countryEN: NO.en, countryGR: NO.gr, countryDE: NO.de),
        c("bergen_no", "Bergen", "Μπέργκεν", "Bergen", country: "NO", flag: NO.flag, countryEN: NO.en, countryGR: NO.gr, countryDE: NO.de),
        c("trondheim_no", "Trondheim", "Τρόντχαϊμ", "Trondheim", country: "NO", flag: NO.flag, countryEN: NO.en, countryGR: NO.gr, countryDE: NO.de),
        c("stavanger_no", "Stavanger", "Στάβανγκερ", "Stavanger", country: "NO", flag: NO.flag, countryEN: NO.en, countryGR: NO.gr, countryDE: NO.de),
        c("tromso_no", "Tromsø", "Τρομσέ", "Tromsø", country: "NO", flag: NO.flag, countryEN: NO.en, countryGR: NO.gr, countryDE: NO.de),
        c("copenhagen_dk", "Copenhagen", "Κοπεγχάγη", "Kopenhagen", country: "DK", flag: DK.flag, countryEN: DK.en, countryGR: DK.gr, countryDE: DK.de),
        c("aarhus_dk", "Aarhus", "Οχρχους", "Aarhus", country: "DK", flag: DK.flag, countryEN: DK.en, countryGR: DK.gr, countryDE: DK.de),
        c("odense_dk", "Odense", "Όντενσε", "Odense", country: "DK", flag: DK.flag, countryEN: DK.en, countryGR: DK.gr, countryDE: DK.de),
        c("aalborg_dk", "Aalborg", "Όλμποργκ", "Aalborg", country: "DK", flag: DK.flag, countryEN: DK.en, countryGR: DK.gr, countryDE: DK.de),
        c("helsinki_fi", "Helsinki", "Ελσίνκι", "Helsinki", country: "FI", flag: FI.flag, countryEN: FI.en, countryGR: FI.gr, countryDE: FI.de),
        c("tampere_fi", "Tampere", "Τάμπερε", "Tampere", country: "FI", flag: FI.flag, countryEN: FI.en, countryGR: FI.gr, countryDE: FI.de),
        c("turku_fi", "Turku", "Τούρκου", "Turku", country: "FI", flag: FI.flag, countryEN: FI.en, countryGR: FI.gr, countryDE: FI.de),
        c("oulu_fi", "Oulu", "Ούλου", "Oulu", country: "FI", flag: FI.flag, countryEN: FI.en, countryGR: FI.gr, countryDE: FI.de),
        c("rovaniemi_fi", "Rovaniemi", "Ροβανιέμι", "Rovaniemi", country: "FI", flag: FI.flag, countryEN: FI.en, countryGR: FI.gr, countryDE: FI.de),
        c("reykjavik_is", "Reykjavik", "Ρέικιαβικ", "Reykjavík", country: "IS", flag: IS.flag, countryEN: IS.en, countryGR: IS.gr, countryDE: IS.de),
        c("akureyri_is", "Akureyri", "Άκουρέιρι", "Akureyri", country: "IS", flag: IS.flag, countryEN: IS.en, countryGR: IS.gr, countryDE: IS.de),

        // MARK: Eastern Europe
        c("warsaw_pl", "Warsaw", "Βαρσοβία", "Warschau", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("krakow_pl", "Krakow", "Κρακοβία", "Krakau", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("gdansk_pl", "Gdansk", "Γκντανσκ", "Danzig", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("wroclaw_pl", "Wroclaw", "Βρότσλαβ", "Breslau", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("poznan_pl", "Poznań", "Πόζναν", "Posen", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("lodz_pl", "Łódź", "Λοτζ", "Lodz", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("katowice_pl", "Katowice", "Κατοβίτσε", "Kattowitz", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("lublin_pl", "Lublin", "Λούμπλιν", "Lublin", country: "PL", flag: PL.flag, countryEN: PL.en, countryGR: PL.gr, countryDE: PL.de),
        c("prague_cz", "Prague", "Πράγα", "Prag", country: "CZ", flag: CZ.flag, countryEN: CZ.en, countryGR: CZ.gr, countryDE: CZ.de),
        c("brno_cz", "Brno", "Μπρνο", "Brünn", country: "CZ", flag: CZ.flag, countryEN: CZ.en, countryGR: CZ.gr, countryDE: CZ.de),
        c("ostrava_cz", "Ostrava", "Οστράβα", "Ostrau", country: "CZ", flag: CZ.flag, countryEN: CZ.en, countryGR: CZ.gr, countryDE: CZ.de),
        c("pilsen_cz", "Pilsen", "Πίλζεν", "Pilsen", country: "CZ", flag: CZ.flag, countryEN: CZ.en, countryGR: CZ.gr, countryDE: CZ.de),
        c("budapest_hu", "Budapest", "Βουδαπέστη", "Budapest", country: "HU", flag: HU.flag, countryEN: HU.en, countryGR: HU.gr, countryDE: HU.de),
        c("debrecen_hu", "Debrecen", "Ντέμπρετσεν", "Debrecen", country: "HU", flag: HU.flag, countryEN: HU.en, countryGR: HU.gr, countryDE: HU.de),
        c("szeged_hu", "Szeged", "Σέγκεντ", "Szeged", country: "HU", flag: HU.flag, countryEN: HU.en, countryGR: HU.gr, countryDE: HU.de),
        c("miskolc_hu", "Miskolc", "Μίσκολτς", "Miskolc", country: "HU", flag: HU.flag, countryEN: HU.en, countryGR: HU.gr, countryDE: HU.de),
        c("bratislava_sk", "Bratislava", "Μπρατισλάβα", "Bratislava", country: "SK", flag: SK.flag, countryEN: SK.en, countryGR: SK.gr, countryDE: SK.de),
        c("kosice_sk", "Košice", "Κόσιτσε", "Kaschau", country: "SK", flag: SK.flag, countryEN: SK.en, countryGR: SK.gr, countryDE: SK.de),
        c("bucharest_ro", "Bucharest", "Βουκουρέστι", "Bukarest", country: "RO", flag: RO.flag, countryEN: RO.en, countryGR: RO.gr, countryDE: RO.de),
        c("cluj_ro", "Cluj-Napoca", "Κλουζ-Ναπόκα", "Cluj-Napoca", country: "RO", flag: RO.flag, countryEN: RO.en, countryGR: RO.gr, countryDE: RO.de),
        c("timisoara_ro", "Timișoara", "Τιμισοάρα", "Temeswar", country: "RO", flag: RO.flag, countryEN: RO.en, countryGR: RO.gr, countryDE: RO.de),
        c("iasi_ro", "Iași", "Ιάσιο", "Iași", country: "RO", flag: RO.flag, countryEN: RO.en, countryGR: RO.gr, countryDE: RO.de),
        c("constanta_ro", "Constanța", "Κωνστάντζα", "Konstanza", country: "RO", flag: RO.flag, countryEN: RO.en, countryGR: RO.gr, countryDE: RO.de),
        c("brasov_ro", "Brașov", "Μπρασόβ", "Kronstadt", country: "RO", flag: RO.flag, countryEN: RO.en, countryGR: RO.gr, countryDE: RO.de),
        c("sofia_bg", "Sofia", "Σόφια", "Sofia", country: "BG", flag: BG.flag, countryEN: BG.en, countryGR: BG.gr, countryDE: BG.de),
        c("plovdiv_bg", "Plovdiv", "Φιλιππούπολη", "Plowdiw", country: "BG", flag: BG.flag, countryEN: BG.en, countryGR: BG.gr, countryDE: BG.de),
        c("varna_bg", "Varna", "Βάρνα", "Warna", country: "BG", flag: BG.flag, countryEN: BG.en, countryGR: BG.gr, countryDE: BG.de),
        c("burgas_bg", "Burgas", "Μπουργκάς", "Burgas", country: "BG", flag: BG.flag, countryEN: BG.en, countryGR: BG.gr, countryDE: BG.de),
        c("ljubljana_si", "Ljubljana", "Λιουμπλιάνα", "Ljubljana", country: "SI", flag: SI.flag, countryEN: SI.en, countryGR: SI.gr, countryDE: SI.de),
        c("maribor_si", "Maribor", "Μάριμπορ", "Marburg", country: "SI", flag: SI.flag, countryEN: SI.en, countryGR: SI.gr, countryDE: SI.de),
        c("zagreb_hr", "Zagreb", "Ζάγκρεμπ", "Zagreb", country: "HR", flag: HR.flag, countryEN: HR.en, countryGR: HR.gr, countryDE: HR.de),
        c("split_hr", "Split", "Σπλιτ", "Split", country: "HR", flag: HR.flag, countryEN: HR.en, countryGR: HR.gr, countryDE: HR.de),
        c("dubrovnik_hr", "Dubrovnik", "Ντουμπρόβνικ", "Dubrovnik", country: "HR", flag: HR.flag, countryEN: HR.en, countryGR: HR.gr, countryDE: HR.de),
        c("rijeka_hr", "Rijeka", "Ριέκα", "Rijeka", country: "HR", flag: HR.flag, countryEN: HR.en, countryGR: HR.gr, countryDE: HR.de),
        c("zadar_hr", "Zadar", "Ζαντάρ", "Zadar", country: "HR", flag: HR.flag, countryEN: HR.en, countryGR: HR.gr, countryDE: HR.de),
        c("belgrade_rs", "Belgrade", "Βελιγράδι", "Belgrad", country: "RS", flag: RS.flag, countryEN: RS.en, countryGR: RS.gr, countryDE: RS.de),
        c("novi_sad_rs", "Novi Sad", "Νόβι Σαντ", "Novi Sad", country: "RS", flag: RS.flag, countryEN: RS.en, countryGR: RS.gr, countryDE: RS.de),
        c("nis_rs", "Niš", "Νις", "Niš", country: "RS", flag: RS.flag, countryEN: RS.en, countryGR: RS.gr, countryDE: RS.de),
        c("sarajevo_ba", "Sarajevo", "Σαράγεβο", "Sarajevo", country: "BA", flag: BA.flag, countryEN: BA.en, countryGR: BA.gr, countryDE: BA.de),
        c("banja_luka_ba", "Banja Luka", "Μπάνια Λούκα", "Banja Luka", country: "BA", flag: BA.flag, countryEN: BA.en, countryGR: BA.gr, countryDE: BA.de),
        c("mostar_ba", "Mostar", "Μόσταρ", "Mostar", country: "BA", flag: BA.flag, countryEN: BA.en, countryGR: BA.gr, countryDE: BA.de),
        c("skopje_mk", "Skopje", "Σκόπια", "Skopje", country: "MK", flag: MK.flag, countryEN: MK.en, countryGR: MK.gr, countryDE: MK.de),
        c("bitola_mk", "Bitola", "Μπίτολα", "Bitola", country: "MK", flag: MK.flag, countryEN: MK.en, countryGR: MK.gr, countryDE: MK.de),
        c("tirana_al", "Tirana", "Τίρανα", "Tirana", country: "AL", flag: AL.flag, countryEN: AL.en, countryGR: AL.gr, countryDE: AL.de),
        c("durres_al", "Durrës", "Δυρράχιο", "Durrës", country: "AL", flag: AL.flag, countryEN: AL.en, countryGR: AL.gr, countryDE: AL.de),
        c("vlore_al", "Vlorë", "Αυλώνα", "Vlora", country: "AL", flag: AL.flag, countryEN: AL.en, countryGR: AL.gr, countryDE: AL.de),
        c("podgorica_me", "Podgorica", "Ποντγκόριτσα", "Podgorica", country: "ME", flag: ME.flag, countryEN: ME.en, countryGR: ME.gr, countryDE: ME.de),
        c("kotor_me", "Kotor", "Κότορ", "Kotor", country: "ME", flag: ME.flag, countryEN: ME.en, countryGR: ME.gr, countryDE: ME.de),
        c("moscow_ru", "Moscow", "Μόσχα", "Moskau", country: "RU", flag: RU.flag, countryEN: RU.en, countryGR: RU.gr, countryDE: RU.de),
        c("saint_petersburg_ru", "Saint Petersburg", "Αγία Πετρούπολη", "Sankt Petersburg", country: "RU", flag: RU.flag, countryEN: RU.en, countryGR: RU.gr, countryDE: RU.de),
        c("novosibirsk_ru", "Novosibirsk", "Νοβοσιμπίρσκ", "Nowosibirsk", country: "RU", flag: RU.flag, countryEN: RU.en, countryGR: RU.gr, countryDE: RU.de),
        c("yekaterinburg_ru", "Yekaterinburg", "Γιεκατερίνμπουργκ", "Jekaterinburg", country: "RU", flag: RU.flag, countryEN: RU.en, countryGR: RU.gr, countryDE: RU.de),
        c("kazan_ru", "Kazan", "Καζάν", "Kasan", country: "RU", flag: RU.flag, countryEN: RU.en, countryGR: RU.gr, countryDE: RU.de),
        c("kyiv_ua", "Kyiv", "Κίεβο", "Kiew", country: "UA", flag: UA.flag, countryEN: UA.en, countryGR: UA.gr, countryDE: UA.de),
        c("lviv_ua", "Lviv", "Λβιβ", "Lemberg", country: "UA", flag: UA.flag, countryEN: UA.en, countryGR: UA.gr, countryDE: UA.de),
        c("kharkiv_ua", "Kharkiv", "Χάρκοβο", "Charkiw", country: "UA", flag: UA.flag, countryEN: UA.en, countryGR: UA.gr, countryDE: UA.de),
        c("odesa_ua", "Odesa", "Οδησσός", "Odessa", country: "UA", flag: UA.flag, countryEN: UA.en, countryGR: UA.gr, countryDE: UA.de),

        // MARK: Turkey (🇹🇷)
        c("istanbul_tr", "Istanbul", "Κωνσταντινούπολη", "Istanbul", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("ankara_tr", "Ankara", "Άγκυρα", "Ankara", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("izmir_tr", "Izmir", "Σμύρνη", "Izmir", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("bursa_tr", "Bursa", "Προύσα", "Bursa", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("antalya_tr", "Antalya", "Αττάλεια", "Antalya", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("adana_tr", "Adana", "Αδάνα", "Adana", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("konya_tr", "Konya", "Ικόνιο", "Konya", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("gaziantep_tr", "Gaziantep", "Γκαζιαντέπ", "Gaziantep", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),
        c("bodrum_tr", "Bodrum", "Αλικαρνασσός", "Bodrum", country: "TR", flag: TR.flag, countryEN: TR.en, countryGR: TR.gr, countryDE: TR.de),

        // MARK: USA (🇺🇸) — 60+ πόλεις
        c("new_york_us", "New York", "Νέα Υόρκη", "New York", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("los_angeles_us", "Los Angeles", "Λος Άντζελες", "Los Angeles", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("chicago_us", "Chicago", "Σικάγο", "Chicago", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("houston_us", "Houston", "Χιούστον", "Houston", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("phoenix_us", "Phoenix", "Φοίνιξ", "Phoenix", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("philadelphia_us", "Philadelphia", "Φιλαδέλφεια", "Philadelphia", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("san_francisco_us", "San Francisco", "Σαν Φρανσίσκο", "San Francisco", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("seattle_us", "Seattle", "Σιάτλ", "Seattle", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("boston_us", "Boston", "Βοστώνη", "Boston", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("miami_us", "Miami", "Μαϊάμι", "Miami", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("atlanta_us", "Atlanta", "Ατλάντα", "Atlanta", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("dallas_us", "Dallas", "Ντάλας", "Dallas", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("las_vegas_us", "Las Vegas", "Λας Βέγκας", "Las Vegas", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("denver_us", "Denver", "Ντένβερ", "Denver", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("washington_us", "Washington DC", "Ουάσινγκτον", "Washington D.C.", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("san_diego_us", "San Diego", "Σαν Ντιέγκο", "San Diego", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("austin_us", "Austin", "Όστιν", "Austin", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("portland_us", "Portland", "Πόρτλαντ", "Portland", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("nashville_us", "Nashville", "Νάσβιλ", "Nashville", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("new_orleans_us", "New Orleans", "Νέα Ορλεάνη", "New Orleans", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("detroit_us", "Detroit", "Ντιτρόιτ", "Detroit", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("minneapolis_us", "Minneapolis", "Μινεάπολη", "Minneapolis", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("baltimore_us", "Baltimore", "Βαλτιμόρη", "Baltimore", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("sacramento_us", "Sacramento", "Σακραμέντο", "Sacramento", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("san_jose_us", "San Jose", "Σαν Χοσέ", "San José", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("cleveland_us", "Cleveland", "Κλίβελαντ", "Cleveland", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("tampa_us", "Tampa", "Τάμπα", "Tampa", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("orlando_us", "Orlando", "Ορλάντο", "Orlando", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("kansas_city_us", "Kansas City", "Κάνσας Σίτι", "Kansas City", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("indianapolis_us", "Indianapolis", "Ιντιανάπολη", "Indianapolis", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("columbus_us", "Columbus", "Κολόμπους", "Columbus", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("pittsburgh_us", "Pittsburgh", "Πίτσμπουργκ", "Pittsburgh", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("cincinnati_us", "Cincinnati", "Σινσινάτι", "Cincinnati", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("st_louis_us", "St. Louis", "Άγιος Λουδοβίκος", "St. Louis", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("milwaukee_us", "Milwaukee", "Μιλγουόκι", "Milwaukee", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("jacksonville_us", "Jacksonville", "Τζάκσονβιλ", "Jacksonville", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("memphis_us", "Memphis", "Μέμφις", "Memphis", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("louisville_us", "Louisville", "Λούισβιλ", "Louisville", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("albuquerque_us", "Albuquerque", "Αλμπουκέρκι", "Albuquerque", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("tucson_us", "Tucson", "Τούσον", "Tucson", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("honolulu_us", "Honolulu", "Χονολουλού", "Honolulu", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("anchorage_us", "Anchorage", "Άνκορατζ", "Anchorage", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("salt_lake_city_us", "Salt Lake City", "Σολτ Λέικ Σίτι", "Salt Lake City", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("oklahoma_city_us", "Oklahoma City", "Οκλαχόμα Σίτι", "Oklahoma City", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("raleigh_us", "Raleigh", "Ράλι", "Raleigh", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("charlotte_us", "Charlotte", "Σάρλοτ", "Charlotte", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("virginia_beach_us", "Virginia Beach", "Βιρτζίνια Μπιτς", "Virginia Beach", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("buffalo_us", "Buffalo", "Μπάφαλο", "Buffalo", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("omaha_us", "Omaha", "Ομάχα", "Omaha", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("fresno_us", "Fresno", "Φρέσνο", "Fresno", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("el_paso_us", "El Paso", "Ελ Πάσο", "El Paso", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("fort_worth_us", "Fort Worth", "Φορτ Γουόρθ", "Fort Worth", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("long_beach_us", "Long Beach", "Λονγκ Μπιτς", "Long Beach", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("mesa_us", "Mesa", "Μέσα", "Mesa", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("colorado_springs_us", "Colorado Springs", "Κολοράντο Σπρινγκς", "Colorado Springs", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("boise_us", "Boise", "Μπόιζι", "Boise", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),
        c("des_moines_us", "Des Moines", "Ντε Μόιν", "Des Moines", country: "US", flag: US.flag, countryEN: US.en, countryGR: US.gr, countryDE: US.de),

        // MARK: Canada (🇨🇦)
        c("toronto_ca", "Toronto", "Τορόντο", "Toronto", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("montreal_ca", "Montreal", "Μόντρεαλ", "Montreal", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("vancouver_ca", "Vancouver", "Βανκούβερ", "Vancouver", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("ottawa_ca", "Ottawa", "Οττάβα", "Ottawa", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("calgary_ca", "Calgary", "Κάλγκαρι", "Calgary", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("edmonton_ca", "Edmonton", "Έντμοντον", "Edmonton", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("winnipeg_ca", "Winnipeg", "Γουίνιπεγκ", "Winnipeg", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("quebec_ca", "Quebec City", "Κεμπέκ", "Québec", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("halifax_ca", "Halifax", "Χάλιφαξ", "Halifax", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),
        c("victoria_ca", "Victoria", "Βικτώρια", "Victoria", country: "CA", flag: CA.flag, countryEN: CA.en, countryGR: CA.gr, countryDE: CA.de),

        // MARK: Mexico & Caribbean
        c("mexico_city_mx", "Mexico City", "Πόλη του Μεξικού", "Mexiko-Stadt", country: "MX", flag: MX.flag, countryEN: MX.en, countryGR: MX.gr, countryDE: MX.de),
        c("cancun_mx", "Cancun", "Κανκούν", "Cancún", country: "MX", flag: MX.flag, countryEN: MX.en, countryGR: MX.gr, countryDE: MX.de),
        c("guadalajara_mx", "Guadalajara", "Γκουαδαλαχάρα", "Guadalajara", country: "MX", flag: MX.flag, countryEN: MX.en, countryGR: MX.gr, countryDE: MX.de),
        c("monterrey_mx", "Monterrey", "Μοντερέι", "Monterrey", country: "MX", flag: MX.flag, countryEN: MX.en, countryGR: MX.gr, countryDE: MX.de),
        c("tijuana_mx", "Tijuana", "Τιχουάνα", "Tijuana", country: "MX", flag: MX.flag, countryEN: MX.en, countryGR: MX.gr, countryDE: MX.de),
        c("puerto_vallarta_mx", "Puerto Vallarta", "Πουέρτο Βαγιάρτα", "Puerto Vallarta", country: "MX", flag: MX.flag, countryEN: MX.en, countryGR: MX.gr, countryDE: MX.de),
        c("havana_cu", "Havana", "Αβάνα", "Havanna", country: "CU", flag: "🇨🇺", countryEN: "Cuba", countryGR: "Κούβα", countryDE: "Kuba"),
        c("san_juan_pr", "San Juan", "Σαν Χουάν", "San Juan", country: "PR", flag: "🇵🇷", countryEN: "Puerto Rico", countryGR: "Πουέρτο Ρίκο", countryDE: "Puerto Rico"),
        c("nassau_bs", "Nassau", "Νασάου", "Nassau", country: "BS", flag: "🇧🇸", countryEN: "Bahamas", countryGR: "Μπαχάμες", countryDE: "Bahamas"),
        c("kingston_jm", "Kingston", "Κίνγκστον", "Kingston", country: "JM", flag: "🇯🇲", countryEN: "Jamaica", countryGR: "Τζαμάικα", countryDE: "Jamaika"),

        // MARK: South America
        c("sao_paulo_br", "São Paulo", "Σάο Πάολο", "São Paulo", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("rio_br", "Rio de Janeiro", "Ρίο ντε Τζανέιρο", "Rio de Janeiro", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("brasilia_br", "Brasilia", "Μπραζίλια", "Brasília", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("salvador_br", "Salvador", "Σαλβαδόρ", "Salvador", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("fortaleza_br", "Fortaleza", "Φορταλέζα", "Fortaleza", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("belo_horizonte_br", "Belo Horizonte", "Μπέλο Οριζόντε", "Belo Horizonte", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("recife_br", "Recife", "Ρεσίφε", "Recife", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("porto_alegre_br", "Porto Alegre", "Πόρτο Αλέγκρε", "Porto Alegre", country: "BR", flag: BR.flag, countryEN: BR.en, countryGR: BR.gr, countryDE: BR.de),
        c("buenos_aires_ar", "Buenos Aires", "Μπουένος Άιρες", "Buenos Aires", country: "AR", flag: AR.flag, countryEN: AR.en, countryGR: AR.gr, countryDE: AR.de),
        c("cordoba_ar", "Córdoba", "Κόρδοβα", "Córdoba", country: "AR", flag: AR.flag, countryEN: AR.en, countryGR: AR.gr, countryDE: AR.de),
        c("mendoza_ar", "Mendoza", "Μεντόθα", "Mendoza", country: "AR", flag: AR.flag, countryEN: AR.en, countryGR: AR.gr, countryDE: AR.de),
        c("rosario_ar", "Rosario", "Ροζάριο", "Rosario", country: "AR", flag: AR.flag, countryEN: AR.en, countryGR: AR.gr, countryDE: AR.de),
        c("santiago_cl", "Santiago", "Σαντιάγο", "Santiago", country: "CL", flag: CL.flag, countryEN: CL.en, countryGR: CL.gr, countryDE: CL.de),
        c("valparaiso_cl", "Valparaíso", "Βαλπαραΐσο", "Valparaíso", country: "CL", flag: CL.flag, countryEN: CL.en, countryGR: CL.gr, countryDE: CL.de),
        c("lima_pe", "Lima", "Λίμα", "Lima", country: "PE", flag: PE.flag, countryEN: PE.en, countryGR: PE.gr, countryDE: PE.de),
        c("cusco_pe", "Cusco", "Κούσκο", "Cusco", country: "PE", flag: PE.flag, countryEN: PE.en, countryGR: PE.gr, countryDE: PE.de),
        c("bogota_co", "Bogota", "Μπογκοτά", "Bogotá", country: "CO", flag: CO.flag, countryEN: CO.en, countryGR: CO.gr, countryDE: CO.de),
        c("medellin_co", "Medellín", "Μεντεγίν", "Medellín", country: "CO", flag: CO.flag, countryEN: CO.en, countryGR: CO.gr, countryDE: CO.de),
        c("cartagena_co", "Cartagena", "Καρταχένα", "Cartagena", country: "CO", flag: CO.flag, countryEN: CO.en, countryGR: CO.gr, countryDE: CO.de),
        c("caracas_ve", "Caracas", "Καράκας", "Caracas", country: "VE", flag: "🇻🇪", countryEN: "Venezuela", countryGR: "Βενεζουέλα", countryDE: "Venezuela"),
        c("quito_ec", "Quito", "Κίτο", "Quito", country: "EC", flag: "🇪🇨", countryEN: "Ecuador", countryGR: "Ισημερινός", countryDE: "Ecuador"),
        c("montevideo_uy", "Montevideo", "Μοντεβιδέο", "Montevideo", country: "UY", flag: "🇺🇾", countryEN: "Uruguay", countryGR: "Ουρουγουάη", countryDE: "Uruguay"),
        c("asuncion_py", "Asunción", "Ασουνθιόν", "Asunción", country: "PY", flag: "🇵🇾", countryEN: "Paraguay", countryGR: "Παραγουάη", countryDE: "Paraguay"),
        c("la_paz_bo", "La Paz", "Λα Πας", "La Paz", country: "BO", flag: "🇧🇴", countryEN: "Bolivia", countryGR: "Βολιβία", countryDE: "Bolivien"),

        // MARK: Asia - East
        c("tokyo_jp", "Tokyo", "Τόκιο", "Tokio", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("osaka_jp", "Osaka", "Οσάκα", "Osaka", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("kyoto_jp", "Kyoto", "Κιότο", "Kyoto", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("yokohama_jp", "Yokohama", "Γιοκοχάμα", "Yokohama", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("nagoya_jp", "Nagoya", "Ναγκόγια", "Nagoya", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("sapporo_jp", "Sapporo", "Σαπόρο", "Sapporo", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("fukuoka_jp", "Fukuoka", "Φουκουόκα", "Fukuoka", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("hiroshima_jp", "Hiroshima", "Χιροσίμα", "Hiroshima", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("okinawa_jp", "Okinawa", "Οκινάουα", "Okinawa", country: "JP", flag: JP.flag, countryEN: JP.en, countryGR: JP.gr, countryDE: JP.de),
        c("seoul_kr", "Seoul", "Σεούλ", "Seoul", country: "KR", flag: KR.flag, countryEN: KR.en, countryGR: KR.gr, countryDE: KR.de),
        c("busan_kr", "Busan", "Μπουσάν", "Busan", country: "KR", flag: KR.flag, countryEN: KR.en, countryGR: KR.gr, countryDE: KR.de),
        c("incheon_kr", "Incheon", "Ιντσόν", "Incheon", country: "KR", flag: KR.flag, countryEN: KR.en, countryGR: KR.gr, countryDE: KR.de),
        c("daegu_kr", "Daegu", "Ντέγκου", "Daegu", country: "KR", flag: KR.flag, countryEN: KR.en, countryGR: KR.gr, countryDE: KR.de),
        c("jeju_kr", "Jeju", "Τζέτζου", "Jeju", country: "KR", flag: KR.flag, countryEN: KR.en, countryGR: KR.gr, countryDE: KR.de),
        c("beijing_cn", "Beijing", "Πεκίνο", "Peking", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("shanghai_cn", "Shanghai", "Σανγκάη", "Shanghai", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("guangzhou_cn", "Guangzhou", "Γκουανγκτζόου", "Guangzhou", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("shenzhen_cn", "Shenzhen", "Σεντζέν", "Shenzhen", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("chengdu_cn", "Chengdu", "Τσενγκντού", "Chengdu", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("xian_cn", "Xi'an", "Σιάν", "Xi'an", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("hangzhou_cn", "Hangzhou", "Χανγκτζόου", "Hangzhou", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("tianjin_cn", "Tianjin", "Τιαντζίν", "Tianjin", country: "CN", flag: CN.flag, countryEN: CN.en, countryGR: CN.gr, countryDE: CN.de),
        c("hong_kong_hk", "Hong Kong", "Χονγκ Κονγκ", "Hongkong", country: "HK", flag: "🇭🇰", countryEN: "Hong Kong", countryGR: "Χονγκ Κονγκ", countryDE: "Hongkong"),
        c("macau_mo", "Macau", "Μακάο", "Macau", country: "MO", flag: "🇲🇴", countryEN: "Macau", countryGR: "Μακάο", countryDE: "Macau"),
        c("taipei_tw", "Taipei", "Ταϊπέι", "Taipeh", country: "TW", flag: "🇹🇼", countryEN: "Taiwan", countryGR: "Ταϊβάν", countryDE: "Taiwan"),

        // MARK: Asia - Southeast
        c("singapore_sg", "Singapore", "Σιγκαπούρη", "Singapur", country: "SG", flag: SG.flag, countryEN: SG.en, countryGR: SG.gr, countryDE: SG.de),
        c("bangkok_th", "Bangkok", "Μπανγκόκ", "Bangkok", country: "TH", flag: TH.flag, countryEN: TH.en, countryGR: TH.gr, countryDE: TH.de),
        c("phuket_th", "Phuket", "Πουκέτ", "Phuket", country: "TH", flag: TH.flag, countryEN: TH.en, countryGR: TH.gr, countryDE: TH.de),
        c("chiang_mai_th", "Chiang Mai", "Τσιάνγκ Μάι", "Chiang Mai", country: "TH", flag: TH.flag, countryEN: TH.en, countryGR: TH.gr, countryDE: TH.de),
        c("pattaya_th", "Pattaya", "Παταγιά", "Pattaya", country: "TH", flag: TH.flag, countryEN: TH.en, countryGR: TH.gr, countryDE: TH.de),
        c("jakarta_id", "Jakarta", "Τζακάρτα", "Jakarta", country: "ID", flag: ID.flag, countryEN: ID.en, countryGR: ID.gr, countryDE: ID.de),
        c("bali_id", "Bali", "Μπαλί", "Bali", country: "ID", flag: ID.flag, countryEN: ID.en, countryGR: ID.gr, countryDE: ID.de),
        c("surabaya_id", "Surabaya", "Σουραμπάγια", "Surabaya", country: "ID", flag: ID.flag, countryEN: ID.en, countryGR: ID.gr, countryDE: ID.de),
        c("bandung_id", "Bandung", "Μπαντούνγκ", "Bandung", country: "ID", flag: ID.flag, countryEN: ID.en, countryGR: ID.gr, countryDE: ID.de),
        c("kuala_lumpur_my", "Kuala Lumpur", "Κουάλα Λουμπούρ", "Kuala Lumpur", country: "MY", flag: MY.flag, countryEN: MY.en, countryGR: MY.gr, countryDE: MY.de),
        c("penang_my", "Penang", "Πενάνγκ", "Penang", country: "MY", flag: MY.flag, countryEN: MY.en, countryGR: MY.gr, countryDE: MY.de),
        c("johor_bahru_my", "Johor Bahru", "Τζοχόρ Μπαχρού", "Johor Bahru", country: "MY", flag: MY.flag, countryEN: MY.en, countryGR: MY.gr, countryDE: MY.de),
        c("manila_ph", "Manila", "Μανίλα", "Manila", country: "PH", flag: PH.flag, countryEN: PH.en, countryGR: PH.gr, countryDE: PH.de),
        c("cebu_ph", "Cebu", "Σεμπού", "Cebu", country: "PH", flag: PH.flag, countryEN: PH.en, countryGR: PH.gr, countryDE: PH.de),
        c("davao_ph", "Davao", "Νταβάο", "Davao", country: "PH", flag: PH.flag, countryEN: PH.en, countryGR: PH.gr, countryDE: PH.de),
        c("hanoi_vn", "Hanoi", "Ανόι", "Hanoi", country: "VN", flag: VN.flag, countryEN: VN.en, countryGR: VN.gr, countryDE: VN.de),
        c("ho_chi_minh_vn", "Ho Chi Minh City", "Χο Τσι Μινχ", "Ho-Chi-Minh-Stadt", country: "VN", flag: VN.flag, countryEN: VN.en, countryGR: VN.gr, countryDE: VN.de),
        c("da_nang_vn", "Da Nang", "Ντα Νανγκ", "Da Nang", country: "VN", flag: VN.flag, countryEN: VN.en, countryGR: VN.gr, countryDE: VN.de),
        c("phnom_penh_kh", "Phnom Penh", "Πνομ Πενχ", "Phnom Penh", country: "KH", flag: "🇰🇭", countryEN: "Cambodia", countryGR: "Καμπότζη", countryDE: "Kambodscha"),
        c("siem_reap_kh", "Siem Reap", "Σιέμ Ρίπ", "Siem Reap", country: "KH", flag: "🇰🇭", countryEN: "Cambodia", countryGR: "Καμπότζη", countryDE: "Kambodscha"),
        c("vientiane_la", "Vientiane", "Βιεντιάν", "Vientiane", country: "LA", flag: "🇱🇦", countryEN: "Laos", countryGR: "Λάος", countryDE: "Laos"),
        c("yangon_mm", "Yangon", "Γιανγκόν", "Yangon", country: "MM", flag: "🇲🇲", countryEN: "Myanmar", countryGR: "Μιανμάρ", countryDE: "Myanmar"),

        // MARK: Asia - South
        c("mumbai_in", "Mumbai", "Μουμπάι", "Mumbai", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("delhi_in", "New Delhi", "Νέο Δελχί", "Neu-Delhi", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("bangalore_in", "Bangalore", "Μπανγκαλόρ", "Bangalore", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("kolkata_in", "Kolkata", "Καλκούτα", "Kolkata", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("chennai_in", "Chennai", "Τσενάι", "Chennai", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("hyderabad_in", "Hyderabad", "Χαϊντεραμπάντ", "Hyderabad", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("pune_in", "Pune", "Πούνε", "Pune", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("ahmedabad_in", "Ahmedabad", "Αχμανταμπάντ", "Ahmedabad", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("jaipur_in", "Jaipur", "Τζαϊπούρ", "Jaipur", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("goa_in", "Goa", "Γκόα", "Goa", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("varanasi_in", "Varanasi", "Βαρανάσι", "Varanasi", country: "IN", flag: IN.flag, countryEN: IN.en, countryGR: IN.gr, countryDE: IN.de),
        c("kathmandu_np", "Kathmandu", "Κατμαντού", "Kathmandu", country: "NP", flag: "🇳🇵", countryEN: "Nepal", countryGR: "Νεπάλ", countryDE: "Nepal"),
        c("colombo_lk", "Colombo", "Κολόμπο", "Colombo", country: "LK", flag: "🇱🇰", countryEN: "Sri Lanka", countryGR: "Σρι Λάνκα", countryDE: "Sri Lanka"),
        c("karachi_pk", "Karachi", "Καράτσι", "Karatschi", country: "PK", flag: "🇵🇰", countryEN: "Pakistan", countryGR: "Πακιστάν", countryDE: "Pakistan"),
        c("islamabad_pk", "Islamabad", "Ισλαμαμπάντ", "Islamabad", country: "PK", flag: "🇵🇰", countryEN: "Pakistan", countryGR: "Πακιστάν", countryDE: "Pakistan"),
        c("lahore_pk", "Lahore", "Λαχόρη", "Lahore", country: "PK", flag: "🇵🇰", countryEN: "Pakistan", countryGR: "Πακιστάν", countryDE: "Pakistan"),
        c("dhaka_bd", "Dhaka", "Ντάκα", "Dhaka", country: "BD", flag: "🇧🇩", countryEN: "Bangladesh", countryGR: "Μπαγκλαντές", countryDE: "Bangladesch"),
        c("male_mv", "Malé", "Μάλε", "Malé", country: "MV", flag: "🇲🇻", countryEN: "Maldives", countryGR: "Μαλδίβες", countryDE: "Malediven"),

        // MARK: Middle East
        c("dubai_ae", "Dubai", "Ντουμπάι", "Dubai", country: "AE", flag: AE.flag, countryEN: AE.en, countryGR: AE.gr, countryDE: AE.de),
        c("abu_dhabi_ae", "Abu Dhabi", "Άμπου Ντάμπι", "Abu Dhabi", country: "AE", flag: AE.flag, countryEN: AE.en, countryGR: AE.gr, countryDE: AE.de),
        c("sharjah_ae", "Sharjah", "Σάρτζα", "Sharjah", country: "AE", flag: AE.flag, countryEN: AE.en, countryGR: AE.gr, countryDE: AE.de),
        c("doha_qa", "Doha", "Ντόχα", "Doha", country: "QA", flag: "🇶🇦", countryEN: "Qatar", countryGR: "Κατάρ", countryDE: "Katar"),
        c("riyadh_sa", "Riyadh", "Ριάντ", "Riad", country: "SA", flag: SA.flag, countryEN: SA.en, countryGR: SA.gr, countryDE: SA.de),
        c("jeddah_sa", "Jeddah", "Τζέντα", "Dschidda", country: "SA", flag: SA.flag, countryEN: SA.en, countryGR: SA.gr, countryDE: SA.de),
        c("mecca_sa", "Mecca", "Μέκκα", "Mekka", country: "SA", flag: SA.flag, countryEN: SA.en, countryGR: SA.gr, countryDE: SA.de),
        c("kuwait_city_kw", "Kuwait City", "Κουβέιτ Σίτι", "Kuwait-Stadt", country: "KW", flag: "🇰🇼", countryEN: "Kuwait", countryGR: "Κουβέιτ", countryDE: "Kuwait"),
        c("muscat_om", "Muscat", "Μουσκάτ", "Maskat", country: "OM", flag: "🇴🇲", countryEN: "Oman", countryGR: "Ομάν", countryDE: "Oman"),
        c("manama_bh", "Manama", "Μαναμά", "Manama", country: "BH", flag: "🇧🇭", countryEN: "Bahrain", countryGR: "Μπαχρέιν", countryDE: "Bahrain"),
        c("amman_jo", "Amman", "Αμμάν", "Amman", country: "JO", flag: "🇯🇴", countryEN: "Jordan", countryGR: "Ιορδανία", countryDE: "Jordanien"),
        c("petra_jo", "Petra", "Πέτρα", "Petra", country: "JO", flag: "🇯🇴", countryEN: "Jordan", countryGR: "Ιορδανία", countryDE: "Jordanien"),
        c("tel_aviv_il", "Tel Aviv", "Τελ Αβίβ", "Tel Aviv", country: "IL", flag: IL.flag, countryEN: IL.en, countryGR: IL.gr, countryDE: IL.de),
        c("jerusalem_il", "Jerusalem", "Ιερουσαλήμ", "Jerusalem", country: "IL", flag: IL.flag, countryEN: IL.en, countryGR: IL.gr, countryDE: IL.de),
        c("haifa_il", "Haifa", "Χάιφα", "Haifa", country: "IL", flag: IL.flag, countryEN: IL.en, countryGR: IL.gr, countryDE: IL.de),
        c("beirut_lb", "Beirut", "Βηρυτός", "Beirut", country: "LB", flag: "🇱🇧", countryEN: "Lebanon", countryGR: "Λίβανος", countryDE: "Libanon"),
        c("damascus_sy", "Damascus", "Δαμασκός", "Damaskus", country: "SY", flag: "🇸🇾", countryEN: "Syria", countryGR: "Συρία", countryDE: "Syrien"),
        c("baghdad_iq", "Baghdad", "Βαγδάτη", "Bagdad", country: "IQ", flag: "🇮🇶", countryEN: "Iraq", countryGR: "Ιράκ", countryDE: "Irak"),
        c("tehran_ir", "Tehran", "Τεχεράνη", "Teheran", country: "IR", flag: "🇮🇷", countryEN: "Iran", countryGR: "Ιράν", countryDE: "Iran"),

        // MARK: Africa
        c("cairo_eg", "Cairo", "Κάιρο", "Kairo", country: "EG", flag: EG.flag, countryEN: EG.en, countryGR: EG.gr, countryDE: EG.de),
        c("alexandria_eg", "Alexandria", "Αλεξάνδρεια", "Alexandria", country: "EG", flag: EG.flag, countryEN: EG.en, countryGR: EG.gr, countryDE: EG.de),
        c("sharm_el_sheikh_eg", "Sharm El Sheikh", "Σαρμ ελ Σέιχ", "Scharm el-Scheich", country: "EG", flag: EG.flag, countryEN: EG.en, countryGR: EG.gr, countryDE: EG.de),
        c("luxor_eg", "Luxor", "Λούξορ", "Luxor", country: "EG", flag: EG.flag, countryEN: EG.en, countryGR: EG.gr, countryDE: EG.de),
        c("hurghada_eg", "Hurghada", "Χουργκάντα", "Hurghada", country: "EG", flag: EG.flag, countryEN: EG.en, countryGR: EG.gr, countryDE: EG.de),
        c("cape_town_za", "Cape Town", "Κέιπ Τάουν", "Kapstadt", country: "ZA", flag: ZA.flag, countryEN: ZA.en, countryGR: ZA.gr, countryDE: ZA.de),
        c("johannesburg_za", "Johannesburg", "Γιοχάνεσμπουργκ", "Johannesburg", country: "ZA", flag: ZA.flag, countryEN: ZA.en, countryGR: ZA.gr, countryDE: ZA.de),
        c("durban_za", "Durban", "Ντέρμπαν", "Durban", country: "ZA", flag: ZA.flag, countryEN: ZA.en, countryGR: ZA.gr, countryDE: ZA.de),
        c("pretoria_za", "Pretoria", "Πρετόρια", "Pretoria", country: "ZA", flag: ZA.flag, countryEN: ZA.en, countryGR: ZA.gr, countryDE: ZA.de),
        c("nairobi_ke", "Nairobi", "Ναϊρόμπι", "Nairobi", country: "KE", flag: KE.flag, countryEN: KE.en, countryGR: KE.gr, countryDE: KE.de),
        c("mombasa_ke", "Mombasa", "Μομπάσα", "Mombasa", country: "KE", flag: KE.flag, countryEN: KE.en, countryGR: KE.gr, countryDE: KE.de),
        c("lagos_ng", "Lagos", "Λάγος", "Lagos", country: "NG", flag: NG.flag, countryEN: NG.en, countryGR: NG.gr, countryDE: NG.de),
        c("abuja_ng", "Abuja", "Αμπούτζα", "Abuja", country: "NG", flag: NG.flag, countryEN: NG.en, countryGR: NG.gr, countryDE: NG.de),
        c("casablanca_ma", "Casablanca", "Καζαμπλάνκα", "Casablanca", country: "MA", flag: MA.flag, countryEN: MA.en, countryGR: MA.gr, countryDE: MA.de),
        c("marrakech_ma", "Marrakech", "Μαρακές", "Marrakesch", country: "MA", flag: MA.flag, countryEN: MA.en, countryGR: MA.gr, countryDE: MA.de),
        c("rabat_ma", "Rabat", "Ραμπάτ", "Rabat", country: "MA", flag: MA.flag, countryEN: MA.en, countryGR: MA.gr, countryDE: MA.de),
        c("fez_ma", "Fez", "Φες", "Fès", country: "MA", flag: MA.flag, countryEN: MA.en, countryGR: MA.gr, countryDE: MA.de),
        c("tangier_ma", "Tangier", "Ταγγέρη", "Tanger", country: "MA", flag: MA.flag, countryEN: MA.en, countryGR: MA.gr, countryDE: MA.de),
        c("tunis_tn", "Tunis", "Τύνιδα", "Tunis", country: "TN", flag: "🇹🇳", countryEN: "Tunisia", countryGR: "Τυνησία", countryDE: "Tunesien"),
        c("algiers_dz", "Algiers", "Αλγέρι", "Algier", country: "DZ", flag: "🇩🇿", countryEN: "Algeria", countryGR: "Αλγερία", countryDE: "Algerien"),
        c("accra_gh", "Accra", "Άκκρα", "Accra", country: "GH", flag: "🇬🇭", countryEN: "Ghana", countryGR: "Γκάνα", countryDE: "Ghana"),
        c("addis_ababa_et", "Addis Ababa", "Αντίς Αμπέμπα", "Addis Abeba", country: "ET", flag: "🇪🇹", countryEN: "Ethiopia", countryGR: "Αιθιοπία", countryDE: "Äthiopien"),
        c("dar_es_salaam_tz", "Dar es Salaam", "Νταρ ες Σαλάμ", "Daressalam", country: "TZ", flag: "🇹🇿", countryEN: "Tanzania", countryGR: "Τανζανία", countryDE: "Tansania"),
        c("kampala_ug", "Kampala", "Καμπάλα", "Kampala", country: "UG", flag: "🇺🇬", countryEN: "Uganda", countryGR: "Ουγκάντα", countryDE: "Uganda"),
        c("kigali_rw", "Kigali", "Κιγκάλι", "Kigali", country: "RW", flag: "🇷🇼", countryEN: "Rwanda", countryGR: "Ρουάντα", countryDE: "Ruanda"),
        c("windhoek_na", "Windhoek", "Βιντχούκ", "Windhuk", country: "NA", flag: "🇳🇦", countryEN: "Namibia", countryGR: "Ναμίμπια", countryDE: "Namibia"),
        c("zanzibar_tz", "Zanzibar", "Ζανζιβάρη", "Sansibar", country: "TZ", flag: "🇹🇿", countryEN: "Tanzania", countryGR: "Τανζανία", countryDE: "Tansania"),
        c("victoria_sc", "Victoria", "Βικτώρια", "Victoria", country: "SC", flag: "🇸🇨", countryEN: "Seychelles", countryGR: "Σεϋχέλλες", countryDE: "Seychellen"),
        c("port_louis_mu", "Port Louis", "Πορτ Λουί", "Port Louis", country: "MU", flag: "🇲🇺", countryEN: "Mauritius", countryGR: "Μαυρίκιος", countryDE: "Mauritius"),

        // MARK: Australia & Oceania
        c("sydney_au", "Sydney", "Σίδνεϊ", "Sydney", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("melbourne_au", "Melbourne", "Μελβούρνη", "Melbourne", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("brisbane_au", "Brisbane", "Μπρίσμπεϊν", "Brisbane", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("perth_au", "Perth", "Περθ", "Perth", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("adelaide_au", "Adelaide", "Αδελαΐδα", "Adelaide", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("canberra_au", "Canberra", "Καμπέρα", "Canberra", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("gold_coast_au", "Gold Coast", "Γκολντ Κόουστ", "Gold Coast", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("hobart_au", "Hobart", "Χόμπαρτ", "Hobart", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("darwin_au", "Darwin", "Ντάργουιν", "Darwin", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("cairns_au", "Cairns", "Κερνς", "Cairns", country: "AU", flag: AU.flag, countryEN: AU.en, countryGR: AU.gr, countryDE: AU.de),
        c("auckland_nz", "Auckland", "Όκλαντ", "Auckland", country: "NZ", flag: NZ.flag, countryEN: NZ.en, countryGR: NZ.gr, countryDE: NZ.de),
        c("wellington_nz", "Wellington", "Ουέλινγκτον", "Wellington", country: "NZ", flag: NZ.flag, countryEN: NZ.en, countryGR: NZ.gr, countryDE: NZ.de),
        c("christchurch_nz", "Christchurch", "Κράιστσερτς", "Christchurch", country: "NZ", flag: NZ.flag, countryEN: NZ.en, countryGR: NZ.gr, countryDE: NZ.de),
        c("queenstown_nz", "Queenstown", "Κουίνσταουν", "Queenstown", country: "NZ", flag: NZ.flag, countryEN: NZ.en, countryGR: NZ.gr, countryDE: NZ.de),
        c("fiji_fj", "Suva", "Σούβα", "Suva", country: "FJ", flag: "🇫🇯", countryEN: "Fiji", countryGR: "Φίτζι", countryDE: "Fidschi"),
        c("honiara_sb", "Honiara", "Χονιάρα", "Honiara", country: "SB", flag: "🇸🇧", countryEN: "Solomon Islands", countryGR: "Νησιά Σολομώντα", countryDE: "Salomonen"),
        c("port_moresby_pg", "Port Moresby", "Πορτ Μόρεσμπι", "Port Moresby", country: "PG", flag: "🇵🇬", countryEN: "Papua New Guinea", countryGR: "Παπούα Νέα Γουινέα", countryDE: "Papua-Neuguinea")
    ]
}
