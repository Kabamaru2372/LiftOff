// SettingsView.swift
// Unpluq
//
// Created by Fotios Pongas 24.03.2026
// Ρυθμίσεις — daily goal, quiet hours, timer toggle.
//
// SettingsView.swift
// Unpluq

import SwiftUI

struct SettingsView: View {
    @AppStorage("dailyGoal") private var dailyGoal: Int = 15
    @AppStorage("showTimer") private var showTimer: Bool = true
    @AppStorage("quietStart") private var quietStart: Int = 22
    @AppStorage("quietEnd") private var quietEnd: Int = 7
    @AppStorage("appLanguage") private var appLanguage: String = "English"
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled: Bool = true
    
    @Environment(ProManager.self) var proManager
    @Environment(LiveActivityManager.self) var liveActivity
    @Environment(DataStore.self) var store
    @State private var showPaywall: Bool = false
    
    private var isGreek: Bool { appLanguage == "Ελληνικά" }
    
    private var quietStartDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: quietStart)) ?? Date()
            },
            set: { newDate in
                quietStart = Calendar.current.component(.hour, from: newDate)
            }
        )
    }
    
    private var quietEndDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: quietEnd)) ?? Date()
            },
            set: { newDate in
                quietEnd = Calendar.current.component(.hour, from: newDate)
            }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                Text(isGreek ? "Ρυθμίσεις" : "Settings")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // LiftOff+ status
                if proManager.isPro {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                        Text("LiftOff+")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        Text(isGreek ? "Ενεργό" : "Active")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.08))
                    )
                    .padding(.bottom, 20)
                } else {
                    Button(action: { showPaywall = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isGreek ? "Αναβάθμιση σε LiftOff+" : "Upgrade to LiftOff+")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Heatmap, rewards, quote packs")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("€4.99")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 20)
                }
                
                // Language
                SettingRow(
                    title: isGreek ? "Γλώσσα" : "Language",
                    subtitle: isGreek ? "Γλώσσα nudge μηνυμάτων" : "Nudge message language"
                ) {
                    Picker("", selection: $appLanguage) {
                        ForEach(QuoteBank.Language.allCases, id: \.rawValue) { lang in
                            Text(lang.rawValue).tag(lang.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Divider()
                
                // Daily Goal
                SettingRow(
                    title: isGreek ? "Ημερήσιος στόχος" : "Daily goal",
                    subtitle: isGreek ? "Μέγιστα pickups ανά μέρα" : "Max pickups per day"
                ) {
                    Stepper("\(dailyGoal)", value: $dailyGoal, in: 5...50, step: 5)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                
                Divider()
                
                // Timer visible
                SettingRow(
                    title: isGreek ? "Χρονόμετρο" : "Timer visible",
                    subtitle: isGreek ? "Δείξε live μετρητή" : "Show live counter on nudge"
                ) {
                    Toggle("", isOn: $showTimer)
                        .labelsHidden()
                }
                
                Divider()
                
                // Live Activity toggle
                SettingRow(
                    title: "Live Activity",
                    subtitle: isGreek ? "Δείξε pickups στο Lock Screen" : "Show pickups on Lock Screen"
                ) {
                    Toggle("", isOn: Binding(
                        get: { liveActivityEnabled },
                        set: { newValue in
                            liveActivityEnabled = newValue
                            if newValue {
                                let goal = UserDefaults.standard.integer(forKey: "dailyGoal")
                                liveActivity.start(
                                    pickupCount: store.todayPickups,
                                    dailyGoal: goal > 0 ? goal : 15
                                )
                            } else {
                                liveActivity.stopAll()
                            }
                        }
                    ))
                    .labelsHidden()
                }
                
                Divider()
                
                // Quiet Hours Start
                SettingRow(
                    title: isGreek ? "Ώρες ησυχίας — Από" : "Quiet hours — From",
                    subtitle: isGreek ? "Χωρίς nudges από" : "No nudges from"
                ) {
                    DatePicker("", selection: quietStartDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                Divider()
                
                // Quiet Hours End
                SettingRow(
                    title: isGreek ? "Ώρες ησυχίας — Μέχρι" : "Quiet hours — Until",
                    subtitle: isGreek ? "Χωρίς nudges μέχρι" : "No nudges until"
                ) {
                    DatePicker("", selection: quietEndDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                Divider()
                
                // About
                VStack(alignment: .leading, spacing: 8) {
                    Text(isGreek ? "Σχετικά" : "About")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 24)
                    
                    Text(isGreek
                         ? "Το LiftOff σε βοηθάει να συνειδητοποιείς τις συνήθειές σου με το κινητό. Χωρίς κριτική — απλά μια ήρεμη υπενθύμιση να είσαι πιο συνειδητός."
                         : "LiftOff helps you build awareness of your phone habits. No judgment, no shaming — just a gentle reminder to be intentional.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                    
                    Text("v1.0 — Made with care")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            content()
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    SettingsView()
        .environment(ProManager.shared)
        .environment(LiveActivityManager())
        .environment(DataStore())
}
