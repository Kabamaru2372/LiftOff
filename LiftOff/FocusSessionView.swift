// FocusSessionView.swift
// Picksy
//
// Created by Fotios Pongas
//
// Sheet view for starting / monitoring / reviewing a Focus Session.
// Three states: idle (start), active (in-progress), completed (results).

import SwiftUI

struct FocusSessionView: View {

    @Environment(FocusSessionManager.self) var focusManager
    @Environment(DataStore.self) var store
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @Environment(\.dismiss) private var dismiss

    /// Καλείται όταν ξεκινάει η session — περνάει το endTime για Live Activity
    var onFocusStart: (Date?) -> Void = { _ in }
    /// Καλείται όταν τελειώνει/σταματάει η session
    var onFocusEnd: () -> Void = {}

    // Duration picker selection (in seconds)
    @State private var selectedDuration: TimeInterval = 1800

    private let durationOptions: [(label: String, seconds: TimeInterval)] = [
        ("5 min", 300),
        ("15 min", 900),
        ("30 min", 1800),
        ("60 min", 3600)
    ]

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.08, green: 0.08, blue: 0.10)
                .ignoresSafeArea()

            switch focusManager.sessionState {
            case .idle:
                startView
            case .active:
                activeView
            case .completed(let pickupsDuring, let durationMinutes, let success):
                completedView(pickupsDuring: pickupsDuring, durationMinutes: durationMinutes, success: success)
            }
        }
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 28) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // Title
            VStack(spacing: 8) {
                Text(t("Focus Session", "Περίοδος Εστίασης", "Fokus-Session"))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(t(
                    "How long do you want to stay present?",
                    "Πόσο θέλεις να παραμείνεις παρών;",
                    "Wie lange möchtest du präsent bleiben?"
                ))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }

            // 2x2 Duration grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(durationOptions, id: \.seconds) { option in
                    Button(action: {
                        selectedDuration = option.seconds
                    }) {
                        Text(option.label)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(selectedDuration == option.seconds ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedDuration == option.seconds
                                          ? Color.orange
                                          : Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            // Start button
            Button(action: {
                focusManager.start(duration: selectedDuration, currentPickups: store.todayPickups)
                onFocusStart(focusManager.endTime)
            }) {
                Text(t("Start", "Έναρξη", "Starten"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color(red: 1.0, green: 0.55, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            // Cancel
            Button(action: { dismiss() }) {
                Text(t("Cancel", "Ακύρωση", "Abbrechen"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Active View

    private var activeView: some View {
        VStack(spacing: 28) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Text("Stay present 🍃")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Circular progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 10)
                    .frame(width: 200, height: 200)

                // Progress ring
                Circle()
                    .trim(from: 0, to: focusManager.sessionProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, Color(red: 1.0, green: 0.7, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: focusManager.sessionProgress)

                // Time remaining
                Text(focusManager.formattedTimeRemaining)
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Pickup count during session
            let count = focusManager.pickupsDuringSession
            Text(count == 0
                 ? t("No pickups yet — great job!", "Καμία λήψη ακόμα — μπράβο!", "Noch keine Griffe — super!")
                 : t("\(count) pickup\(count == 1 ? "" : "s") during session",
                     "\(count) λήψη\(count == 1 ? "" : "ψεις") κατά τη σύνοδο",
                     "\(count) Griff\(count == 1 ? "" : "e") während der Session"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(count == 0 ? .green : .red)
                .padding(.top, 4)

            Spacer()

            // End session button
            Button(action: {
                onFocusEnd()
                focusManager.stop()
                dismiss()
            }) {
                Text(t("End Session", "Τέλος Συνόδου", "Session beenden"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Completed View

    private func completedView(pickupsDuring: Int, durationMinutes: Int, success: Bool) -> some View {
        VStack(spacing: 24) {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            Spacer()

            // Result icon
            Image(systemName: success ? "checkmark.circle.fill" : "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundColor(success ? .green : .orange)

            // Title
            Text(success
                 ? t("You did it! 🎉", "Τα κατάφερες! 🎉", "Geschafft! 🎉")
                 : t("Good try!", "Καλή προσπάθεια!", "Guter Versuch!"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Subtitle
            VStack(spacing: 8) {
                if success {
                    Text(t(
                        "You stayed present for \(durationMinutes) minutes with zero pickups.",
                        "Παρέμεινες παρών για \(durationMinutes) λεπτά χωρίς καμία λήψη.",
                        "Du warst \(durationMinutes) Minuten lang präsent — ohne einen einzigen Griff."
                    ))
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                } else {
                    Text(t(
                        "You completed a \(durationMinutes)-minute session with \(pickupsDuring) pickup\(pickupsDuring == 1 ? "" : "s").",
                        "Ολοκλήρωσες μια σύνοδο \(durationMinutes) λεπτών με \(pickupsDuring) λήψ\(pickupsDuring == 1 ? "η" : "εις").",
                        "Du hast eine \(durationMinutes)-Minuten-Session mit \(pickupsDuring) Griff\(pickupsDuring == 1 ? "" : "en") abgeschlossen."
                    ))
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }
            }

            // Stats card (show even on success for completeness)
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(durationMinutes)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(t("minutes", "λεπτά", "Minuten"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 44)

                VStack(spacing: 4) {
                    Text("\(pickupsDuring)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(pickupsDuring == 0 ? .green : .orange)
                    Text(t("pickups", "λήψεις", "Griffe"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )

            Spacer()

            // Done button
            Button(action: {
                focusManager.dismissCompleted()
                dismiss()
            }) {
                Text(t("Done", "Τέλος", "Fertig"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: success
                                ? [Color.green.opacity(0.8), Color(red: 0.2, green: 0.75, blue: 0.35)]
                                : [Color.orange, Color(red: 1.0, green: 0.55, blue: 0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
