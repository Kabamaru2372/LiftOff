//
//  DuoFoldStore.swift
//  Picksy
//
//  Persistence for DuoFoldData in the shared App Group, plus Duo detection.
//  record(_:) is called from the App Intent, which Shortcuts runs in the app's
//  process even when Picksy is closed, so it must be synchronous and cheap.
//

import Foundation
import os

extension Notification.Name {
    /// Posted (main thread) after a fold event was stored, so open screens refresh.
    static let duoFoldRecorded = Notification.Name("picksy.duoFoldRecorded")
}

enum DuoFoldStore {

    private static let suiteName = "group.fotiospongas.picksy"
    private static let key = "duoFolds_v1"
    private static let lock = NSLock()
    private static let log = Logger(subsystem: "fotiospongas.dev.UnPluq", category: "DuoFold")

    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    // MARK: Read / write

    static func load() -> DuoFoldData {
        lock.lock(); defer { lock.unlock() }
        return loadLocked()
    }

    private static func loadLocked() -> DuoFoldData {
        guard let raw = defaults?.data(forKey: key) else { return DuoFoldData() }
        do {
            return try JSONDecoder().decode(DuoFoldData.self, from: raw)
        } catch {
            // Never silently drop the user's history: keep the unreadable blob aside.
            log.error("Duo fold data unreadable, keeping backup: \(error.localizedDescription)")
            defaults?.set(raw, forKey: key + ".corrupt")
            return DuoFoldData()
        }
    }

    private static func saveLocked(_ data: DuoFoldData) {
        do {
            defaults?.set(try JSONEncoder().encode(data), forKey: key)
        } catch {
            log.error("Duo fold data not saved: \(error.localizedDescription)")
        }
    }

    // MARK: Mutations

    /// Stores one fold event and returns the updated data.
    @discardableResult
    static func record(_ kind: DuoFoldKind = .any, at date: Date = Date()) -> DuoFoldData {
        lock.lock()
        let next = loadLocked().recording(kind, at: date)
        saveLocked(next)
        lock.unlock()
        notifyChanged()
        return next
    }

    /// One-shot import of the Scriptable `duo_folds.json` history.
    static func importScriptable(_ json: Data) throws -> DuoFoldData {
        lock.lock()
        defer { lock.unlock() }
        let next = try loadLocked().importingScriptable(json, now: Date())
        saveLocked(next)
        notifyChanged()
        return next
    }

    private static func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .duoFoldRecorded, object: nil)
        }
    }

    // MARK: Device

    /// Hardware identifier, e.g. "iPhone19,4"; the simulator reports its modelled device.
    static var modelIdentifier: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
    }

    /// iPhone Duo (iPhone19,4). Fold UI is shown on a Duo, or anywhere fold
    /// events have already been recorded.
    static var isDuo: Bool { modelIdentifier == "iPhone19,4" }

    static var shouldShowFoldFeatures: Bool { isDuo || load().hasData }
}
