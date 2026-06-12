// ForceUpdateView.swift
// Picksy
//
// Full-screen blocking overlay shown when ForceUpdateManager.isForceUpdateRequired == true.
// The user cannot dismiss this — the only action is "Update Now" which opens the App Store.
//
// SoftUpdateBanner is the dismissible top banner shown when isSoftUpdateAvailable == true.

import SwiftUI

// MARK: - Force Update (blocking)

struct ForceUpdateView: View {

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    let onUpdate: () -> Void

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12),
                         Color(red: 0.08, green: 0.04, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 0.7, green: 0.8, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .padding(.bottom, 32)

                // Title
                Text(t("Update Required", "Απαιτείται ενημέρωση", "Update erforderlich"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 12)

                // Message
                Text(t(
                    "A new version of Picksy is required to continue.\nPlease update from the App Store.",
                    "Απαιτείται νέα έκδοση του Picksy.\nΠαρακαλώ ενημέρωσε από το App Store.",
                    "Eine neue Version von Picksy ist erforderlich.\nBitte im App Store aktualisieren."
                ))
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 48)

                Spacer()

                // Update button
                Button(action: onUpdate) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(t("Update Now", "Ενημέρωση τώρα", "Jetzt aktualisieren"))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

                // Current version info
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text(t("Current version: \(version)", "Τρέχουσα έκδοση: \(version)", "Aktuelle Version: \(version)"))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.bottom, 48)
                }
            }
        }
    }
}

// MARK: - Soft Update Banner (dismissible)

struct SoftUpdateBanner: View {

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(t("Update available", "Διαθέσιμη ενημέρωση", "Update verfügbar"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(t("A newer version of Picksy is ready.", "Νέα έκδοση του Picksy είναι έτοιμη.", "Eine neue Picksy-Version ist bereit."))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Button(action: onUpdate) {
                Text(t("Update", "Ενημέρωση", "Update"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.4, blue: 0.9),
                                 Color(red: 0.3, green: 0.2, blue: 0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview("Force Update") {
    ForceUpdateView(onUpdate: {})
}

#Preview("Soft Banner") {
    VStack {
        SoftUpdateBanner(onUpdate: {}, onDismiss: {})
        Spacer()
    }
    .padding(.top, 60)
    .background(Color.gray.opacity(0.2))
}
