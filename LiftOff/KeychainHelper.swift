
//
//  KeychainHelper.swift
//  Picksy
//
//  Created by Fotios Pongas on 19.04.26.
//  Αποθηκεύει δεδομένα στο Keychain που παραμένουν
//  ακόμα και μετά τη διαγραφή της εφαρμογής.

import Foundation
import Security

struct KeychainHelper {

    static let service = "dev.fotiospongas.picksy"

    // MARK: - Save

    static func save(_ key: String, date: Date) {
        let timestamp = date.timeIntervalSince1970
        let data = withUnsafeBytes(of: timestamp) { Data($0) }
        save(key, data: data)
    }

    static func save(_ key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Load

    static func loadDate(_ key: String) -> Date? {
        guard let data = load(key), data.count == MemoryLayout<Double>.size else { return nil }
        let timestamp = data.withUnsafeBytes { $0.load(as: Double.self) }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func load(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Delete

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Exists

    static func exists(_ key: String) -> Bool {
        return load(key) != nil
    }
}
