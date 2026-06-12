//
//  PasscodeView.swift
//  Picksy
//
//  4-digit passcode UI used in two modes:
//   • .setup  — choose a new passcode (enter + confirm) for the time limit.
//   • .unlock — enter the passcode to grant another session past the limit.
//

import SwiftUI

struct PasscodeView: View {
    enum Mode { case setup, unlock }

    let mode: Mode
    var onUnlock: (() -> Void)? = nil
    var onSet: ((String) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var entry: String = ""
    @State private var firstEntry: String? = nil   // setup: holds the first pass
    @State private var error: String? = nil
    @State private var shake: Bool = false

    private let codeLength = 4

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage { case "Ελληνικά": return gr; case "Deutsch": return de; default: return en }
    }

    private var title: String {
        switch mode {
        case .unlock: return t("Enter passcode", "Βάλε τον κωδικό", "Code eingeben")
        case .setup:
            return firstEntry == nil
                ? t("Set a passcode", "Όρισε κωδικό", "Code festlegen")
                : t("Confirm passcode", "Επιβεβαίωσε τον κωδικό", "Code bestätigen")
        }
    }

    private var subtitle: String {
        switch mode {
        case .unlock: return t("Unlock another session for your apps.",
                               "Ξεκλείδωσε άλλη μια session για τις apps.",
                               "Schalte eine weitere Sitzung frei.")
        case .setup: return t("4 digits. You'll need it to grant more time.",
                              "4 ψηφία. Θα τον χρειάζεσαι για να δίνεις χρόνο.",
                              "4 Ziffern. Du brauchst ihn, um mehr Zeit zu geben.")
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundColor(.indigo)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(error ?? subtitle)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(error == nil ? .secondary : .red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Dots
            HStack(spacing: 18) {
                ForEach(0..<codeLength, id: \.self) { i in
                    Circle()
                        .fill(i < entry.count ? Color.indigo : Color.indigo.opacity(0.18))
                        .frame(width: 16, height: 16)
                }
            }
            .offset(x: shake ? -8 : 0)
            .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(6) : .default, value: shake)

            // Number pad
            VStack(spacing: 16) {
                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                    HStack(spacing: 24) {
                        ForEach(row, id: \.self) { n in padButton("\(n)") }
                    }
                }
                HStack(spacing: 24) {
                    Color.clear.frame(width: 72, height: 72)
                    padButton("0")
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .frame(width: 72, height: 72)
                    }
                    .disabled(entry.isEmpty)
                }
            }

            Spacer()

            if let onCancel {
                Button(action: onCancel) {
                    Text(t("Cancel", "Άκυρο", "Abbrechen"))
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 12)
            }
        }
        .padding()
    }

    private func padButton(_ digit: String) -> some View {
        Button(action: { addDigit(digit) }) {
            Text(digit)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color(.systemGray6)))
        }
    }

    private func addDigit(_ d: String) {
        guard entry.count < codeLength else { return }
        error = nil
        entry += d
        if entry.count == codeLength { handleComplete() }
    }

    private func deleteDigit() {
        guard !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func handleComplete() {
        switch mode {
        case .unlock:
            if PasscodeManager.shared.verify(entry) {
                onUnlock?()
            } else {
                fail(t("Wrong passcode. Try again.", "Λάθος κωδικός. Ξαναπροσπάθησε.", "Falscher Code. Versuch es erneut."))
            }
        case .setup:
            if let first = firstEntry {
                if first == entry {
                    onSet?(entry)
                } else {
                    firstEntry = nil
                    fail(t("Codes didn't match. Start over.", "Δεν ταίριαξαν. Ξεκίνα ξανά.", "Codes stimmen nicht. Von vorn."))
                }
            } else {
                firstEntry = entry
                entry = ""
            }
        }
    }

    private func fail(_ message: String) {
        error = message
        shake = true
        let e = entry
        entry = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false; _ = e }
    }
}
