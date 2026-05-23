//
//  AppsView.swift
//  Picksy
//
//  Created by Fotios Pongas on 27.04.2026
//
//  v1.6 UPDATE - Filter μόνο για selected apps (αντί για όλες).
//

import SwiftUI
import DeviceActivity
import FamilyControls

// MARK: - Shared Contexts

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let top3Activity = Self("Top 3 Activity")
}

// MARK: - Apps View

struct AppsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @State private var refreshTrigger = AppsViewRefreshTrigger.shared
    @State private var isAuthorized: Bool = false
    @State private var hasSelectedApps: Bool = false
    @State private var showAppPicker: Bool = false
    @State private var pickerSelection: FamilyActivitySelection = FamilyActivitySelection()
    @State private var midnightTimer: Timer? = nil
    @State private var currentDate: Date = Date()
    @State private var hasAppeared: Bool = false

    /// v1.6 FIX: Filter για σήμερα ΚΑΙ μόνο για selected apps/categories.
    /// Παλιά έδειχνε όλες τις apps που είχαν activity, τώρα μόνο τις tracked.
    private var todayFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .day, for: currentDate)
            ?? DateInterval(start: currentDate, duration: 86400)

        let selection = AppSelectionStore.shared.selection

        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )
    }

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Apps", "Εφαρμογές", "Apps"))
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                    Text(t("Today's usage", "Χρήση σήμερα", "Heutige Nutzung"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()

                if isAuthorized && hasSelectedApps {
                    HStack(spacing: 8) {
                        Button(action: { refreshTrigger.refresh() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.gray.opacity(0.1)))
                        }

                        Button(action: { showAppPicker = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.blue.opacity(0.1)))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Content
            if !isAuthorized {
                authorizationNeededView
            } else if !hasSelectedApps {
                noAppsSelectedView
            } else {
                reportView
            }

            Spacer()
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $pickerSelection)
        .onAppear {
            currentDate = Date()   // always reset to today — fixes stale date after midnight
            refreshState()
            startMidnightTimer()
            // DeviceActivityReport runs in a separate process and can take 2–5 s to warm up.
            // Strategy:
            //   • First visit  → immediate UUID change (cold start) + retry at 4 s + 9 s.
            //   • Later visits → single retry at 1.5 s (extension is already warm, no need
            //                    to blast it; avoid interrupting a load that's in progress).
            // The 0.6 s retry we used before was CANCELLING the extension's first load — removed.
            if !hasAppeared {
                hasAppeared = true
                refreshTrigger.refresh()
                refreshTrigger.refreshAfter(seconds: 4.0)
                refreshTrigger.refreshAfter(seconds: 9.0)
            } else {
                refreshTrigger.refreshAfter(seconds: 1.5)
            }
        }
        .onDisappear {
            // Cancel pending retries so a stale timer doesn't fire after the user
            // has already switched tabs and the extension is mid-load on the new context.
            refreshTrigger.cancelPendingRefreshes()
            midnightTimer?.invalidate()
            midnightTimer = nil
        }
        .onChange(of: pickerSelection) { _, newValue in
            AppSelectionStore.shared.selection = newValue
            refreshState()
            UsageThresholdManager.shared.restartMonitoring()
            refreshTrigger.refreshAfter(seconds: 0.3)
        }
    }

    // MARK: - States

    private var authorizationNeededView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle().fill(Color.purple.opacity(0.12)).frame(width: 80, height: 80)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.purple)
            }

            VStack(spacing: 12) {
                Text(t(
                    "Enable Screen Time access",
                    "Ενεργοποίηση Screen Time",
                    "Bildschirmzeit aktivieren"
                ))
                .font(.system(size: 20, weight: .medium, design: .rounded))

                Text(t(
                    "To see your app usage, Picksy needs permission to read your Screen Time data.",
                    "Για να δεις τη χρήση των εφαρμογών σου, το Picksy χρειάζεται πρόσβαση στα δεδομένα Screen Time.",
                    "Um deine App-Nutzung zu sehen, benötigt Picksy Zugriff auf deine Bildschirmzeit-Daten."
                ))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
            }

            Button(action: { requestFamilyControls() }) {
                Text(t("Enable", "Ενεργοποίηση", "Aktivieren"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple))
            }
            .padding(.top, 8)
        }
    }

    private var noAppsSelectedView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle().fill(Color.indigo.opacity(0.12)).frame(width: 80, height: 80)
                Image(systemName: "apps.iphone")
                    .font(.system(size: 36))
                    .foregroundColor(.indigo)
            }

            VStack(spacing: 12) {
                Text(t(
                    "Choose your apps",
                    "Επίλεξε τις εφαρμογές σου",
                    "Wähle deine Apps"
                ))
                .font(.system(size: 20, weight: .medium, design: .rounded))

                Text(t(
                    "Select the apps you want to track and we'll show you your daily usage time.",
                    "Επίλεξε τις εφαρμογές που θέλεις να παρακολουθείς και θα σου δείξουμε τον ημερήσιο χρόνο χρήσης.",
                    "Wähle die Apps aus, die du verfolgen möchtest, und wir zeigen dir deine tägliche Nutzungszeit."
                ))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
            }

            Button(action: { showAppPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 14))
                    Text(t("Choose apps", "Επιλογή εφαρμογών", "Apps auswählen"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo))
            }
            .padding(.top, 8)
        }
    }

    private var reportView: some View {
        DeviceActivityReport(.totalActivity, filter: todayFilter)
            .id(refreshTrigger.refreshID)
            .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    @MainActor
    private func refreshState() {
        let status = AuthorizationCenter.shared.authorizationStatus
        let authorized = (status == .approved)

        isAuthorized = authorized
        FamilyControlsManager.shared.isAuthorized = authorized

        let selection = AppSelectionStore.shared.selection
        hasSelectedApps = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        pickerSelection = selection
    }

    private func requestFamilyControls() {
        Task { @MainActor in
            let granted = await FamilyControlsManager.shared.requestAuthorization()
            isAuthorized = granted
        }
    }

    // MARK: - Midnight Auto-Refresh

    private func startMidnightTimer() {
        midnightTimer?.invalidate()
        midnightTimer = nil

        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 1),
            matchingPolicy: .nextTime
        ) else { return }

        let secondsUntilMidnight = midnight.timeIntervalSinceNow
        guard secondsUntilMidnight > 0 else { return }

        midnightTimer = Timer.scheduledTimer(withTimeInterval: secondsUntilMidnight, repeats: false) { _ in
            DispatchQueue.main.async {
                self.currentDate = Date()
                self.refreshTrigger.refresh()
                self.startMidnightTimer()
            }
        }
    }
}

#Preview {
    AppsView()
}

