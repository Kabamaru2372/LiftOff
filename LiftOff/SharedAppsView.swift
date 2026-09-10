// SharedAppsView.swift
// Picksy
//
// SharedAppsPickerView — user selects which apps they're willing to share with duel partners.
// FriendAppsSheet — shows a friend's shared app list (read-only).

import SwiftUI

// MARK: - Color helper

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let val = UInt64(h, radix: 16) ?? 0
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8)  & 0xFF) / 255
        let b = Double(val         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Picker (own apps)

struct SharedAppsPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = SharedAppsManager.shared
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String) -> String {
        appLanguage == "Ελληνικά" ? gr : en
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(t(
                        "Choose which apps you want your duel and tournament partners to see. This helps everyone track the same apps for a fair comparison.",
                        "Επέλεξε ποιες εφαρμογές θες να βλέπουν οι αντίπαλοί σου στις μονομαχίες. Έτσι μετράτε τα ίδια για δίκαιη σύγκριση."
                    ))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section(t("Select apps", "Επέλεξε εφαρμογές")) {
                    ForEach(SharedAppsManager.popularApps) { entry in
                        Button {
                            if manager.mySelectedApps.contains(entry.name) {
                                manager.mySelectedApps.remove(entry.name)
                            } else {
                                manager.mySelectedApps.insert(entry.name)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: entry.colorHex))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: entry.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(entry.colorHex == "FFFC00" ? Color.black : Color.white)
                                }
                                Text(entry.name)
                                    .font(.system(size: 16, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if manager.mySelectedApps.contains(entry.name) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 20))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(t("My tracked apps", "Οι εφαρμογές μου"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "Άκυρο")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Save", "Αποθήκευση")) {
                        Task {
                            await manager.syncToSupabase()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Friend's app sheet (read-only)

struct FriendAppsSheet: View {
    let deviceID: String
    let friendName: String

    @State private var apps: [String] = []
    @State private var isLoading = true
    @State private var showMyPicker = false
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String) -> String {
        appLanguage == "Ελληνικά" ? gr : en
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(t("Loading…", "Φόρτωση…"))
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(t(
                            "\(friendName) hasn't shared their app list yet.",
                            "Ο \(friendName) δεν έχει μοιραστεί τη λίστα εφαρμογών του ακόμα."
                        ))
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text(t(
                                "These are the apps \(friendName) is tracking. Select the same ones for a fair duel!",
                                "Αυτές είναι οι εφαρμογές που παρακολουθεί ο \(friendName). Επέλεξε τις ίδιες για δίκαιη μονομαχία!"
                            ))
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(apps, id: \.self) { appName in
                                let entry = SharedAppsManager.popularApps.first(where: { $0.name == appName })
                                HStack(spacing: 14) {
                                    if let e = entry {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: e.colorHex))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: e.symbol)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(e.colorHex == "FFFC00" ? Color.black : Color.white)
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray4))
                                            .frame(width: 32, height: 32)
                                    }
                                    Text(appName)
                                        .font(.system(size: 16, design: .rounded))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(t("\(friendName)'s apps", "Εφαρμογές \(friendName)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("Done", "Τέλος")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !apps.isEmpty {
                    Button {
                        SharedAppsManager.shared.mySelectedApps = Set(apps)
                        copied = true
                        showMyPicker = true
                    } label: {
                        Label(
                            copied
                                ? t("Copied!", "Αντιγράφηκε!")
                                : t("Copy to my list", "Αντιγραφή στη λίστα μου"),
                            systemImage: copied ? "checkmark.circle.fill" : "arrow.down.circle.fill"
                        )
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(copied ? Color.green : Color.blue))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                    .sheet(isPresented: $showMyPicker) {
                        SharedAppsPickerView()
                    }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        apps = await SharedAppsManager.shared.fetchFriendApps(deviceID: deviceID)
        isLoading = false
    }
}
