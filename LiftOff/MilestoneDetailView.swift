// MilestoneDetailView.swift
// Picksy
//
// Shown as a sheet when the user taps a screen-time milestone notification.
// Displays the activity suggestion in full detail with an optional deep-link button.

import SwiftUI

// MARK: - Data model

struct MilestoneNotificationData: Identifiable, Equatable {
    let id   = UUID()
    let minutes:  Int
    let bodyEN:   String
    let bodyGR:   String
    let bodyDE:   String
    let link:     URL?

    static func == (lhs: MilestoneNotificationData, rhs: MilestoneNotificationData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - View

struct MilestoneDetailView: View {

    let data:     MilestoneNotificationData
    let language: String

    @Environment(\.dismiss)  private var dismiss
    @Environment(\.openURL)  private var openURL
    @State private var appeared = false

    // MARK: Helpers

    private var activityBody: String {
        switch language {
        case "Ελληνικά": return data.bodyGR
        case "Deutsch":  return data.bodyDE
        default:         return data.bodyEN
        }
    }

    private var timeTitle: String {
        let h = data.minutes / 60
        let m = data.minutes % 60
        switch language {
        case "Ελληνικά":
            let t = h > 0 && m == 0
                ? "\(h) \(h == 1 ? "ώρα" : "ώρες")"
                : "\(data.minutes) λεπτά"
            return "\(t) στο κινητό σήμερα"
        case "Deutsch":
            let t = h > 0 && m == 0
                ? "\(h) \(h == 1 ? "Stunde" : "Stunden")"
                : "\(data.minutes) Minuten"
            return "\(t) am Handy heute"
        default:
            let t = h == 1 ? "1 hour" : h > 1 ? "\(h) hours" : "\(data.minutes) min"
            return "\(t) on your phone today"
        }
    }

    private var couldHaveLabel: String {
        switch language {
        case "Ελληνικά": return "Σε αυτόν τον χρόνο μπορούσες να..."
        case "Deutsch":  return "In dieser Zeit hättest du..."
        default:         return "In that time you could have..."
        }
    }

    private var openButtonLabel: String {
        guard let host = data.link?.host else { return "Open →" }
        if host.contains("allrecipes") { return "Open AllRecipes 🍳" }
        if host.contains("alltrails")  { return "Open AllTrails 🥾" }
        if host.contains("justwatch")  { return "Open JustWatch 🎬" }
        if host.contains("goodreads")  { return "Open Goodreads 📚" }
        if host.contains("youtube")    { return "Open YouTube 💡" }
        if host.contains("750words")   { return "Open 750 Words ✍️" }
        if host.contains("google")     { return "Open Google Arts 🏛️" }
        return "Open →"
    }

    private var dismissLabel: String {
        switch language {
        case "Ελληνικά": return "Ίσως αργότερα"
        case "Deutsch":  return "Vielleicht später"
        default:         return "Maybe later"
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.13)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Close button ──────────────────────────
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                VStack(spacing: 20) {

                    // ── Phone time badge ──────────────────
                    HStack(spacing: 6) {
                        Text("📱")
                            .font(.system(size: 18))
                        Text(timeTitle)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)

                    // ── "Could have" label ────────────────
                    Text(couldHaveLabel)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)

                    // ── Activity card ─────────────────────
                    Text(activityBody)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)
                        .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.2), value: appeared)

                    // ── Deep-link button ──────────────────
                    if let link = data.link {
                        Button {
                            openURL(link)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Text(openButtonLabel)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .white.opacity(0.15), radius: 20, y: 4)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)
                    }
                }

                Spacer()

                // ── Dismiss ───────────────────────────────
                Button { dismiss() } label: {
                    Text(dismissLabel)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                }
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn.delay(0.42), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }
}
