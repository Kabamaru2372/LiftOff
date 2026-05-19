// MessageView.swift
// Picksy
//
// End-to-end encrypted chat sheet between two anonymous Picksy friends.
// Design: clean, minimal, consistent with the rest of the app.

import SwiftUI

struct MessageView: View {

    let pair: RegisteredPair

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("challengeDisplayName") private var challengeDisplayName: String = ""

    @State private var draftText: String = ""
    @State private var isSending: Bool   = false
    @State private var sendError: String? = nil

    private let maxChars = 120
    private var messaging: MessagingManager { MessagingManager.shared }

    private var messages: [PicksyMessage] {
        (messaging.conversations[pair.deviceID] ?? []).sorted { $0.sentAt < $1.sentAt }
    }

    private var myDeviceID: String { FriendSyncManager.shared.deviceID }

    // MARK: - Localisation

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // E2E + ephemeral label
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(t(
                        "End-to-end encrypted · messages disappear after 24h",
                        "Κρυπτογραφημένο · τα μηνύματα εξαφανίζονται μετά από 24ώ",
                        "Ende-zu-Ende-verschlüsselt · Nachrichten verschwinden nach 24h"
                    ))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))

                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if messages.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(messages) { message in
                                    MessageBubble(
                                        message: message,
                                        isFromMe: message.senderDeviceID == myDeviceID,
                                        appLanguage: appLanguage
                                    )
                                    .id(message.id)
                                    .onAppear {
                                        if !message.isRead && message.senderDeviceID != myDeviceID {
                                            Task { await messaging.markRead(messageID: message.id) }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Compose area
                composeArea
            }
            .navigationTitle(pair.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Done", "Τέλος", "Fertig")) {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                }
            }
        }
        .task {
            // Ensure our public key is uploaded so this friend can reply
            await messaging.uploadPublicKey()
            await messaging.fetchMessages()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
                .padding(.top, 40)
            Text(t(
                "Send \(pair.name) an encrypted message",
                "Στείλε κρυπτογραφημένο μήνυμα στον \(pair.name)",
                "Sende \(pair.name) eine verschlüsselte Nachricht"
            ))
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Compose Area

    private var composeArea: some View {
        VStack(spacing: 0) {
            if let err = sendError {
                HStack(spacing: 8) {
                    Text(err)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Button { sendError = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    TextField(
                        t("Message…", "Μήνυμα…", "Nachricht…"),
                        text: $draftText,
                        axis: .vertical
                    )
                    .font(.system(size: 15, design: .rounded))
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .padding(.trailing, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                    .onChange(of: draftText) { _, newValue in
                        if newValue.count > maxChars {
                            draftText = String(newValue.prefix(maxChars))
                        }
                    }

                    // Character counter
                    Text("\(draftText.count)/\(maxChars)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(draftText.count >= maxChars ? .red : .secondary)
                        .padding(.trailing, 10)
                        .padding(.bottom, 8)
                }

                // Send button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(canSend ? Color.blue : Color(.systemGray4))
                            .frame(width: 36, height: 36)
                        if isSending {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(!canSend || isSending)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespaces).isEmpty && draftText.count <= maxChars
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = draftText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isSending = true
        sendError = nil
        let capturedText = text
        draftText = ""

        Task {
            do {
                try await messaging.sendMessage(to: pair, text: capturedText)
            } catch MessagingError.recipientKeyNotFound {
                await MainActor.run {
                    sendError = t(
                        "⚠️ \(pair.name) needs to update Picksy and open it once before you can message them.",
                        "⚠️ Ο \(pair.name) πρέπει να ενημερώσει το Picksy και να το ανοίξει μία φορά πριν μπορέσεις να του στείλεις μήνυμα.",
                        "⚠️ \(pair.name) muss Picksy aktualisieren und einmal öffnen, bevor du schreiben kannst."
                    )
                    draftText = capturedText
                }
            } catch {
                await MainActor.run {
                    sendError = t("Failed to send. Please try again.", "Αποτυχία αποστολής. Δοκίμασε ξανά.", "Senden fehlgeschlagen. Bitte erneut versuchen.")
                    draftText = capturedText
                }
            }
            await MainActor.run { isSending = false }
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {

    let message: PicksyMessage
    let isFromMe: Bool
    let appLanguage: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isFromMe { Spacer(minLength: 50) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 3) {
                Text(message.decryptedText ?? "…")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(isFromMe ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if isFromMe {
                                RoundedRectangle(cornerRadius: 18).fill(Color.blue)
                            } else {
                                RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isFromMe ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                    )

                HStack(spacing: 4) {
                    Text(relativeTime(message.sentAt))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)

                    // Ephemeral countdown — only show when < 6h left
                    if message.timeUntilExpiry < 6 * 3600 {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: "timer")
                                .font(.system(size: 9))
                            Text(message.expiryLabel)
                                .font(.system(size: 10, design: .rounded))
                        }
                        .foregroundColor(message.timeUntilExpiry < 3600 ? .orange : .secondary)
                    }
                }
            }

            if !isFromMe { Spacer(minLength: 50) }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60  { return localise("Just now", "Μόλις τώρα", "Gerade eben") }
        if seconds < 3600 {
            let m = seconds / 60
            return localise("\(m)m ago", "πριν \(m) λεπτά", "vor \(m) Min.")
        }
        if seconds < 86400 {
            let h = seconds / 3600
            return localise("\(h)h ago", "πριν \(h) ώρες", "vor \(h) Std.")
        }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func localise(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }
}

#Preview {
    MessageView(pair: RegisteredPair(
        deviceID: "preview-device",
        name: "Maria",
        registeredAt: Date()
    ))
}
