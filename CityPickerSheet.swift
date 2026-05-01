//
//  CityPickerSheet.swift
//  Picksy
//
//  Created by Fotios Pongas on 24.04.2026
//
//  Searchable list με 200+ πόλεις οργανωμένες ανά χώρα.

import SwiftUI

struct CityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    let onSelect: (City) -> Void

    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    private var filteredCities: [City] {
        CitiesDatabase.search(query: searchText)
    }

    private var grouped: [(country: String, flag: String, cities: [City])] {
        CitiesDatabase.grouped(cities: filteredCities, language: appLanguage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    TextField(
                        t("Search city or country", "Αναζήτηση πόλης ή χώρας", "Stadt oder Land suchen"),
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($searchFocused)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if grouped.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(t("No cities found", "Δεν βρέθηκαν πόλεις", "Keine Städte gefunden"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    // Cities list
                    List {
                        ForEach(grouped, id: \.country) { group in
                            Section {
                                ForEach(group.cities) { city in
                                    Button(action: { selectCity(city) }) {
                                        HStack(spacing: 12) {
                                            Text(city.countryFlag)
                                                .font(.system(size: 20))
                                            Text(city.localizedName(language: appLanguage))
                                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                    }
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Text(group.flag)
                                    Text(group.country)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle(t("Choose your city", "Επίλεξε πόλη", "Stadt auswählen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text(t("Cancel", "Ακύρωση", "Abbrechen"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                    }
                }
            }
        }
    }

    private func selectCity(_ city: City) {
        onSelect(city)
        dismiss()
    }
}

#Preview {
    CityPickerSheet { city in
        print("Selected: \(city.nameEN)")
    }
}
