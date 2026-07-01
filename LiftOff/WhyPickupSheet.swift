// WhyPickupSheet.swift
// Picksy
//
// Every 5th pickup, ask the user why they picked up the phone.
// Builds awareness of unconscious habits without blocking usage.

import SwiftUI

// MARK: - Pickup Reason

enum PickupReason: String, CaseIterable {
    case social   = "social"
    case work     = "work"
    case bored    = "bored"
    case message  = "message"
    case habit    = "habit"

    var emoji: String {
        switch self {
        case .social:  return "📱"
        case .work:    return "💼"
        case .bored:   return "😐"
        case .message: return "💬"
        case .habit:   return "🔄"
        }
    }

    func title(for language: String) -> String {
        switch self {
        case .social:
            switch language {
            case "Ελληνικά": return "Social media"
            case "Deutsch":  return "Social Media"
            default:         return "Social media"
            }
        case .work:
            switch language {
            case "Ελληνικά": return "Δουλειά / Email"
            case "Deutsch":  return "Arbeit / E-Mail"
            default:         return "Work / Email"
            }
        case .bored:
            switch language {
            case "Ελληνικά": return "Ανία / Πλήξη"
            case "Deutsch":  return "Langeweile"
            default:         return "Boredom"
            }
        case .message:
            switch language {
            case "Ελληνικά": return "Μήνυμα / Κλήση"
            case "Deutsch":  return "Nachricht / Anruf"
            default:         return "Message / Call"
            }
        case .habit:
            switch language {
            case "Ελληνικά": return "Απλώς συνήθεια"
            case "Deutsch":  return "Einfach Gewohnheit"
            default:         return "Just habit"
            }
        }
    }

    var defaultsKey: String { "why_pickup_\(rawValue)" }

    static func record(_ reason: PickupReason) {
        let key = reason.defaultsKey
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
        UserDefaults.standard.set(
            (UserDefaults.standard.integer(forKey: "why_pickup_total")) + 1,
            forKey: "why_pickup_total"
        )
    }

    static func topReason() -> PickupReason? {
        allCases.max(by: {
            UserDefaults.standard.integer(forKey: $0.defaultsKey) <
            UserDefaults.standard.integer(forKey: $1.defaultsKey)
        })
    }
}

// MARK: - Sheet View

struct WhyPickupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            Text("🤔")
                .font(.system(size: 32))

            Text(t("Why did you pick up?",
                   "Γιατί σήκωσες το τηλέφωνο;",
                   "Warum hast du das Handy genommen?"))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    reasonButton(.social)
                    reasonButton(.work)
                }
                HStack(spacing: 10) {
                    reasonButton(.bored)
                    reasonButton(.message)
                }
                reasonButton(.habit)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)

            Button(t("Skip", "Παράλειψη", "Überspringen")) {
                dismiss()
            }
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private func reasonButton(_ reason: PickupReason) -> some View {
        Button {
            PickupReason.record(reason)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text(reason.emoji)
                    .font(.system(size: 18))
                Text(reason.title(for: appLanguage))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}
