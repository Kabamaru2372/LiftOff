// MessageCryptoManager.swift
// Picksy
//
// End-to-end encryption using ECIES (Curve25519 + ChaChaPoly + HKDF-SHA256).
// The device's private key is generated once and stored in the Keychain.
// Public key is shared with Supabase so friends can encrypt messages to this device.

import Foundation
import CryptoKit
import Security

enum MessageCryptoError: Error {
    case keyGenerationFailed
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case invalidPublicKey
    case encryptionFailed
    case decryptionFailed
    case invalidCiphertext
}

final class MessageCryptoManager {

    static let shared = MessageCryptoManager()

    private static let keychainService  = "com.picksy.messagekey"
    private static let keychainAccount  = "curve25519_private_key"

    // MARK: - Key Access

    /// Raw base64-encoded Curve25519 public key for this device.
    var publicKeyBase64: String {
        get throws {
            let privateKey = try loadOrCreatePrivateKey()
            return privateKey.publicKey.rawRepresentation.base64EncodedString()
        }
    }

    // MARK: - Encryption

    /// Encrypts `message` for the recipient identified by their base64 public key.
    /// Output is base64-encoded: [32 bytes ephemeral pubkey | ChaChaPoly combined ciphertext]
    func encrypt(message: String, recipientPublicKeyBase64: String) throws -> String {
        guard let recipientKeyData = Data(base64Encoded: recipientPublicKeyBase64),
              let recipientPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientKeyData)
        else {
            throw MessageCryptoError.invalidPublicKey
        }

        // Generate ephemeral key pair
        let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublicKey  = ephemeralPrivateKey.publicKey

        // Derive shared symmetric key
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )

        // Encrypt
        guard let messageData = message.data(using: .utf8) else {
            throw MessageCryptoError.encryptionFailed
        }

        let sealedBox = try ChaChaPoly.seal(messageData, using: symmetricKey)

        // Combine: ephemeral public key (32 bytes) + sealed box combined
        var combined = ephemeralPublicKey.rawRepresentation
        combined.append(contentsOf: sealedBox.combined)

        return combined.base64EncodedString()
    }

    // MARK: - Decryption

    /// Decrypts a base64-encoded ciphertext produced by `encrypt(message:recipientPublicKeyBase64:)`.
    func decrypt(encryptedBase64: String) throws -> String {
        guard let combined = Data(base64Encoded: encryptedBase64) else {
            throw MessageCryptoError.invalidCiphertext
        }

        // First 32 bytes = ephemeral public key
        guard combined.count > 32 else {
            throw MessageCryptoError.invalidCiphertext
        }

        let ephemeralKeyData  = combined.prefix(32)
        let sealedBoxData     = combined.dropFirst(32)

        guard let ephemeralPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralKeyData) else {
            throw MessageCryptoError.invalidCiphertext
        }

        let sealedBox = try ChaChaPoly.SealedBox(combined: sealedBoxData)

        let privateKey   = try loadOrCreatePrivateKey()
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )

        let plainData = try ChaChaPoly.open(sealedBox, using: symmetricKey)

        guard let result = String(data: plainData, encoding: .utf8) else {
            throw MessageCryptoError.decryptionFailed
        }

        return result
    }

    // MARK: - Private Key Lifecycle

    private init() {}

    private func loadOrCreatePrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let existing = try? loadPrivateKeyFromKeychain() {
            return existing
        }
        let newKey = Curve25519.KeyAgreement.PrivateKey()
        try savePrivateKeyToKeychain(newKey)
        return newKey
    }

    // MARK: - Keychain Helpers

    private func savePrivateKeyToKeychain(_ key: Curve25519.KeyAgreement.PrivateKey) throws {
        let keyData = key.rawRepresentation
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Self.keychainService,
            kSecAttrAccount as String:      Self.keychainAccount,
            kSecValueData as String:        keyData,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete any existing entry first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MessageCryptoError.keychainSaveFailed(status)
        }
    }

    private func loadPrivateKeyFromKeychain() throws -> Curve25519.KeyAgreement.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  Self.keychainService,
            kSecAttrAccount as String:  Self.keychainAccount,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw MessageCryptoError.keychainLoadFailed(status)
        }

        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    }
}
