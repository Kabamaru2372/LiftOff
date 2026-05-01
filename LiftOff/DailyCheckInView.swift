//
//  DailyCheckInView.swift
//  Picksy
//
//  Created by Fotios Pongas on 22.04.2026

import SwiftUI

struct DailyCheckInView: View {
    @Environment(CheckInManager.self) var checkInManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    @State private var selectedMood: CheckInMood? = nil
    @State private var note: String = ""

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch": return de
        default: return en
        }
    }

    var body: some View {
        VStack(spacing: 24) {

            // Header
            VStack(spacing: 8) {
                Text(t("Daily Check-in", "Ημερήσιος απολογισμός", "Tages-Check-in"))
                    .font(.system(size: 22, weight: .medium, design: .rounded))

                Text(t(
                    "How was your relationship with your phone today?",
                    "Πώς ήταν η σχέση σου με το κινητό σήμερα;",
                    "Wie war deine Beziehung zum Handy heute?"
                ))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Mood buttons
            VStack(spacing: 12) {
                MoodButton(
                    mood: .great,
                    title: t("Great", "Τέλεια", "Großartig"),
                    description: t("I was mindful and present", "Ήμουν συνειδητός και παρών", "Ich war bewusst und präsent"),
                    isSelected: selectedMood == .great,
                    onTap: { selectedMood = .great }
                )

                MoodButton(
                    mood: .okay,
                    title: t("Okay", "Μέτρια", "Okay"),
                    description: t("Some slip-ups but not bad", "Κάποια ολισθήματα αλλά όχι άσχημα", "Einige Ausrutscher, aber nicht schlimm"),
                    isSelected: selectedMood == .okay,
                    onTap: { selectedMood = .okay }
                )

                MoodButton(
                    mood: .rough,
                    title: t("Rough", "Δύσκολη", "Schwierig"),
                    description: t("I was glued to my phone", "Ήμουν κολλημένος στο κινητό", "Ich klebte am Handy"),
                    isSelected: selectedMood == .rough,
                    onTap: { selectedMood = .rough }
                )
            }
            .padding(.horizontal, 24)

            // Optional note
            if selectedMood != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Add a note (optional)", "Πρόσθεσε σημείωση (προαιρετικό)", "Notiz hinzufügen (optional)"))
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)

                    TextField(
                        t("What happened today?", "Τι συνέβη σήμερα;", "Was ist heute passiert?"),
                        text: $note,
                        axis: .vertical
                    )
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    .lineLimit(3...5)
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            // Save button
            Button(action: saveAndDismiss) {
                Text(t("Save", "Αποθήκευση", "Speichern"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedMood == nil ? Color.gray : Color.blue)
                    )
            }
            .disabled(selectedMood == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Skip button
            Button(action: { dismiss() }) {
                Text(t("Skip for today", "Παράλειψη για σήμερα", "Heute überspringen"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedMood)
    }

    private func saveAndDismiss() {
        guard let mood = selectedMood else { return }
        checkInManager.saveCheckIn(mood: mood, note: note)
        dismiss()
    }
}

// MARK: - Mood Button

struct MoodButton: View {
    let mood: CheckInMood
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(mood.emoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(mood.color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? mood.color : Color(.systemGray4), lineWidth: isSelected ? 2 : 0.5)
                    )
            )
        }
    }
}

#Preview {
    DailyCheckInView()
        .environment(CheckInManager())
}

