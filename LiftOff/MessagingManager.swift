// MessagingManager.swift
// Picksy
//
// Manages end-to-end encrypted in-app messaging between anonymous device pairs.
// Uses Supabase `messages` table. Public keys are stored in `device_tokens`.

import Foundation
import Observation

// MARK: - PicksyMessage

struct PicksyMessage: Identifiable, Codable {
    let id: String
    let senderDeviceID: String
    let receiverDeviceID: String
    let encryptedText: String
    let sentAt: Date
    let expiresAt: Date
    var isRead: Bool
    var decryptedText: String?

    /// How much time is left before the message expires.
    var timeUntilExpiry: TimeInterval { expiresAt.timeIntervalSinceNow }
    var isExpired: Bool { timeUntilExpiry <= 0 }

    /// Human-readable expiry label: "23h left", "45m left", etc.
    var expiryLabel: String {
        let secs = max(timeUntilExpiry, 0)
        let hours = Int(secs / 3600)
        let mins  = Int((secs.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours >= 1 { return "\(hours)h left" }
        if mins  >= 1 { return "\(mins)m left" }
        return "< 1m left"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case senderDeviceID   = "sender_device_id"
        case receiverDeviceID = "receiver_device_id"
        case encryptedText    = "encrypted_text"
        case sentAt           = "sent_at"
        case expiresAt        = "expires_at"
        case isRead           = "is_read"
    }

    // decryptedText is transient — not stored in Supabase
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        senderDeviceID   = try c.decode(String.self, forKey: .senderDeviceID)
        receiverDeviceID = try c.decode(String.self, forKey: .receiverDeviceID)
        encryptedText    = try c.decode(String.self, forKey: .encryptedText)
        isRead           = try c.decode(Bool.self,   forKey: .isRead)
        decryptedText    = nil

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        let sentAtStr   = try c.decode(String.self, forKey: .sentAt)
        sentAt = fmt.date(from: sentAtStr) ?? fallback.date(from: sentAtStr) ?? Date()

        // expiresAt may be absent in old rows — default to sentAt + 24h
        if let expiresAtStr = try? c.decode(String.self, forKey: .expiresAt) {
            expiresAt = fmt.date(from: expiresAtStr) ?? fallback.date(from: expiresAtStr) ?? sentAt.addingTimeInterval(86400)
        } else {
            expiresAt = sentAt.addingTimeInterval(86400)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,               forKey: .id)
        try c.encode(senderDeviceID,   forKey: .senderDeviceID)
        try c.encode(receiverDeviceID, forKey: .receiverDeviceID)
        try c.encode(encryptedText,    forKey: .encryptedText)
        try c.encode(isRead,           forKey: .isRead)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try c.encode(fmt.string(from: sentAt),   forKey: .sentAt)
        try c.encode(fmt.string(from: expiresAt), forKey: .expiresAt)
    }
}

// MARK: - MessagingManager

@Observable
final class MessagingManager {

    static let shared = MessagingManager()

    private static let supabaseURL     = "https://igbtosqmtdrxzmoblvpp.supabase.co"
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"

    // MARK: - Observable state

    var conversations: [String: [PicksyMessage]] = [:]

    var unreadCount: Int {
        conversations.values.flatMap { $0 }.filter { !$0.isRead }.count
    }

    func unreadCountForFriend(_ deviceID: String) -> Int {
        (conversations[deviceID] ?? []).filter { !$0.isRead && $0.senderDeviceID == deviceID }.count
    }

    private init() {}

    // MARK: - Public Key Management

    /// Uploads this device's public key to the `device_tokens` row.
    func uploadPublicKey() async {
        guard let publicKey = try? MessageCryptoManager.shared.publicKeyBase64 else {
            print("[Messaging] ❌ Could not get public key")
            return
        }

        let myDeviceID = FriendSyncManager.shared.deviceID
        let escaped    = myDeviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? myDeviceID

        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/device_tokens?device_id=eq.\(escaped)&token_type=eq.device") else {
            return
        }

        let body: [String: Any] = ["public_key": publicKey]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = makeRequest(url: url, method: "PATCH")
        request.httpBody = jsonData

        if let (_, resp) = try? await URLSession.shared.data(for: request),
           let http = resp as? HTTPURLResponse {
            print("[Messaging] 📤 Public key uploaded — HTTP \(http.statusCode)")
        }
    }

    /// Fetches the public key for a given device from `device_tokens`.
    func fetchPublicKey(for deviceID: String) async -> String? {
        let escaped = deviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceID
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/device_tokens?device_id=eq.\(escaped)&token_type=eq.device&select=public_key&limit=1") else {
            return nil
        }

        var request = makeRequest(url: url, method: "GET")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let row  = rows.first,
              let key  = row["public_key"] as? String,
              !key.isEmpty
        else { return nil }

        return key
    }

    // MARK: - Send Message

    /// Encrypts and sends a message to `pair`. Triggers an APNs push via Edge Function.
    func sendMessage(to pair: RegisteredPair, text: String) async throws {
        guard let recipientPublicKey = await fetchPublicKey(for: pair.deviceID) else {
            throw MessagingError.recipientKeyNotFound
        }

        let encrypted = try MessageCryptoManager.shared.encrypt(message: text, recipientPublicKeyBase64: recipientPublicKey)
        let myDeviceID = FriendSyncManager.shared.deviceID

        // Insert into messages table
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/messages") else {
            throw MessagingError.networkError
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now       = Date()
        let expiresAt = now.addingTimeInterval(86400)   // 24 hours
        let body: [String: Any] = [
            "sender_device_id":   myDeviceID,
            "receiver_device_id": pair.deviceID,
            "encrypted_text":     encrypted,
            "sent_at":            fmt.string(from: now),
            "expires_at":         fmt.string(from: expiresAt),
            "is_read":            false
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw MessagingError.networkError
        }

        var request = makeRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 201 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("[Messaging] ❌ Message insert failed — HTTP \(code): \(String(data: data, encoding: .utf8) ?? "")")
            throw MessagingError.networkError
        }

        print("[Messaging] ✅ Message sent to \(pair.name)")

        // Add optimistically to local conversations
        if let rows = try? JSONDecoder().decode([PicksyMessage].self, from: data),
           let inserted = rows.first {
            var msg = inserted
            msg.decryptedText = text
            await MainActor.run {
                var conv = conversations[pair.deviceID] ?? []
                conv.insert(msg, at: 0)
                conversations[pair.deviceID] = conv
            }
        }

        // Trigger push notification via Edge Function
        await sendMessagePush(to: pair)
    }

    // MARK: - Fetch Messages

    /// Fetches incoming messages for this device, decrypts them, and updates `conversations`.
    func fetchMessages() async {
        let myDeviceID = FriendSyncManager.shared.deviceID
        let escaped    = myDeviceID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? myDeviceID

        // Only fetch non-expired messages (server-side filter)
        guard let url = URL(string:
            "\(Self.supabaseURL)/rest/v1/messages?receiver_device_id=eq.\(escaped)&expires_at=gt.NOW()&order=sent_at.desc&limit=50"
        ) else { return }

        var request = makeRequest(url: url, method: "GET")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }

        let decoder = JSONDecoder()
        guard var messages = try? decoder.decode([PicksyMessage].self, from: data) else {
            print("[Messaging] ⚠️ Failed to decode messages")
            return
        }

        // Decrypt each message
        let crypto = MessageCryptoManager.shared
        for i in messages.indices {
            messages[i].decryptedText = try? crypto.decrypt(encryptedBase64: messages[i].encryptedText)
        }

        // Merge with outgoing messages already in conversations, grouped by sender
        await MainActor.run {
            var newConversations: [String: [PicksyMessage]] = [:]

            // Group incoming by sender
            for msg in messages {
                let key = msg.senderDeviceID
                var list = newConversations[key] ?? []
                list.append(msg)
                newConversations[key] = list
            }

            // Preserve outgoing messages from existing conversations
            for (friendID, existing) in conversations {
                let outgoing = existing.filter { $0.senderDeviceID == myDeviceID }
                if !outgoing.isEmpty {
                    var merged = newConversations[friendID] ?? []
                    merged.append(contentsOf: outgoing)
                    merged.sort { $0.sentAt > $1.sentAt }
                    newConversations[friendID] = merged
                }
            }

            conversations = newConversations
        }

        print("[Messaging] 📥 Fetched \(messages.count) messages")
    }

    // MARK: - Mark Read

    func markRead(messageID: String) async {
        let escaped = messageID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? messageID
        guard let url = URL(string: "\(Self.supabaseURL)/rest/v1/messages?id=eq.\(escaped)") else { return }

        let body: [String: Any] = ["is_read": true]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = makeRequest(url: url, method: "PATCH")
        request.httpBody = jsonData

        if let (_, resp) = try? await URLSession.shared.data(for: request),
           let http = resp as? HTTPURLResponse {
            print("[Messaging] 👁 Marked read — HTTP \(http.statusCode)")
        }

        // Update locally
        await MainActor.run {
            for (key, messages) in conversations {
                if messages.contains(where: { $0.id == messageID }) {
                    conversations[key] = messages.map { msg in
                        guard msg.id == messageID else { return msg }
                        var updated = msg
                        updated.isRead = true
                        return updated
                    }
                    break
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func sendMessagePush(to pair: RegisteredPair) async {
        guard let url = URL(string: "\(Self.supabaseURL)/functions/v1/send-message") else { return }

        let myName = UserDefaults.standard.string(forKey: "challengeDisplayName")
                     ?? "A friend"
        let senderName = myName.trimmingCharacters(in: .whitespaces).isEmpty ? "A friend" : myName

        let body: [String: Any] = [
            "receiver_device_id": pair.deviceID,
            "sender_name":        senderName
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = makeRequest(url: url, method: "POST")
        request.httpBody = jsonData

        if let (_, resp) = try? await URLSession.shared.data(for: request),
           let http = resp as? HTTPURLResponse {
            print("[Messaging] 🔔 Push triggered — HTTP \(http.statusCode)")
        }
    }

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Self.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        return req
    }
}

// MARK: - MessagingError

enum MessagingError: Error {
    case recipientKeyNotFound
    case networkError
    case encryptionFailed
}
