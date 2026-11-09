# Picksy 2.2.0 (build 33) — App Store Connect copy-paste

Fields that change versus 2.1.1: **What's New**, **Promotional Text** (optional, no review needed), **App Review notes**.
Name, Subtitle, Keywords, Description stay as they are.

## 🇬🇧 English (en-US)

**Promotional Text (≤170):**
Made for iPhone Duo: both screens, landscape on the inner one, and every fold counted. Plus a gentle heads-up before your busiest hours, all on your device.

**What's New:**
Picksy 2.2 📱

📱 Even better on iPhone Duo: a two-column layout in landscape on the inner screen, and a bigger fold counter chip.
🔮 Pickup forecast (optional, off by default): Picksy learns your busy hours on your phone and can send up to 2 gentle heads-ups a day, 10 minutes before. Turn it on in Settings → Pickup forecast. Nothing leaves your device.
🌍 Better Greek: weekdays, dates and several texts now read naturally.

Thanks for being present. 💜

## 🇬🇷 Ελληνικά (el)

**Promotional Text (≤170):**
Φτιαγμένο για iPhone Duo: και οι δύο οθόνες, οριζόντια στην εσωτερική, και κάθε δίπλωμα μετράει. Συν μια απαλή υπενθύμιση πριν τις πιο έντονες ώρες σου, όλα στη συσκευή σου.

**What's New:**
Picksy 2.2 📱

📱 Ακόμα καλύτερο στο iPhone Duo: διάταξη δύο στηλών σε οριζόντια θέση στην εσωτερική οθόνη και μεγαλύτερο chip μέτρησης διπλωμάτων.
🔮 Πρόβλεψη σηκωμάτων (προαιρετική, κλειστή από προεπιλογή): το Picksy μαθαίνει στο κινητό σου τις ώρες που το χρησιμοποιείς πιο πολύ και μπορεί να στέλνει έως 2 απαλές υπενθυμίσεις τη μέρα, 10 λεπτά πριν. Την ενεργοποιείς στις Ρυθμίσεις → Πρόβλεψη σηκωμάτων. Τίποτα δεν φεύγει από τη συσκευή σου.
🌍 Καλύτερα ελληνικά: ημέρες, ημερομηνίες και αρκετά κείμενα διαβάζονται πλέον πιο φυσικά.

Ευχαριστούμε που είσαι παρών. 💜

## 🇩🇪 Deutsch (de-DE)

**Promotional Text (≤170):**
Fürs iPhone Duo gemacht: beide Displays, innen auch im Querformat, und jedes Zuklappen zählt. Dazu ein sanfter Hinweis vor deinen aktivsten Stunden, alles auf deinem Gerät.

**What's New:**
Picksy 2.2 📱

📱 Noch besser auf dem iPhone Duo: zweispaltiges Layout im Querformat auf dem inneren Display und ein größerer Falt-Zähler.
🔮 Griff-Vorhersage (optional, standardmäßig aus): Picksy lernt auf deinem Handy, wann du am aktivsten bist, und kann bis zu 2 sanfte Hinweise pro Tag senden, 10 Minuten vorher. Einschalten unter Einstellungen → Griff-Vorhersage. Nichts verlässt dein Gerät.
🌍 Bessere griechische Texte: Wochentage, Datumsangaben und mehrere Texte lesen sich jetzt natürlicher.

Danke, dass du präsent bist. 💜

## App Review notes (add to existing notes)

Version 2.2.0 adds two things:
1. Pickup forecast (Settings → Pickup forecast). It is OFF by default. When the user switches it on, Picksy
   learns on the device which hours of the week are usually busy and schedules at most 2 local
   notifications per day, 10 minutes before a busy hour. It needs about 10 days of history before the
   first heads-up, so it will not fire during a short review. It uses the notification permission the
   user already granted for Picksy and respects the Quiet Hours setting. All data stays in the App Group
   on the device; nothing is uploaded and no new permissions or tracking are involved.
2. iPhone Duo: landscape is allowed on the inner screen only (two-column Nudge layout). Other iPhones stay
   portrait-only. The Duo fold counter from 2.1.1 is unchanged.
All other behavior is unchanged from 2.1.1.

## Release checklist

- Version 2.2.0, build 33 (all targets, project.pbxproj).
- Merge `dev` into `main` only when ready: the push to `main` starts Xcode Cloud and uploads to App Store Connect.
- Duo screenshots: same slot as 2.1.1 (2007x2853 px). Optional: add the landscape two-column screen.
- Privacy policy: no change required (Forecast is on-device only). Optional one-line mention.
