// TournamentListView.swift
// Picksy
//
// Entry point for tournaments: lists active tournaments + create/join flow.

import SwiftUI

struct TournamentListView: View {
    @State private var manager = TournamentManager.shared
    @State private var showCreate = false
    @State private var showJoin   = false
    @AppStorage("challengeDisplayName") private var userName: String = ""
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage {
        case "Ελληνικά": return gr
        case "Deutsch":  return de
        default:         return en
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if manager.activeTournaments.isEmpty {
                    emptyState
                } else {
                    tournamentList
                }
            }
            .navigationTitle(t("Tournaments", "Τουρνουά", "Turniere"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showJoin = true } label: {
                        Label(t("Join", "Συμμετοχή", "Beitreten"), systemImage: "person.badge.plus")
                    }
                    Button { showCreate = true } label: {
                        Label(t("Create", "Δημιουργία", "Erstellen"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateTournamentView(userName: userName)
            }
            .sheet(isPresented: $showJoin) {
                JoinTournamentView(userName: userName)
            }
            .task { await manager.poll() }
            .refreshable { await manager.poll() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("⚔️")
                .font(.system(size: 56))
            Text(t("No active tournaments", "Δεν υπάρχουν ενεργά τουρνουά", "Keine aktiven Turniere"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(t(
                "Create a tournament and challenge your friends to use their phones less this week!",
                "Δημιούργησε ένα τουρνουά και πρόκλεσε τους φίλους σου να χρησιμοποιούν λιγότερο το κινητό αυτή την εβδομάδα!",
                "Erstelle ein Turnier und fordere deine Freunde heraus, diese Woche ihr Handy weniger zu nutzen!"
            ))
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button { showCreate = true } label: {
                    Label(t("Create", "Δημιουργία", "Erstellen"), systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                }
                Button { showJoin = true } label: {
                    Label(t("Join", "Συμμετοχή", "Beitreten"), systemImage: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1.5))
                }
            }
        }
    }

    private var tournamentList: some View {
        List {
            ForEach(manager.activeTournaments) { tournament in
                let participants = manager.participantsByTournament[tournament.id] ?? []
                NavigationLink {
                    TournamentView(
                        tournament: tournament,
                        participants: participants,
                        onLeave: { Task { await leaveTournament(tournament) } }
                    )
                } label: {
                    TournamentRowView(tournament: tournament, participants: participants)
                }
            }
        }
    }

    private func leaveTournament(_ tournament: TournamentRecord) async {
        // Remove participant row from Supabase
        let urlStr = "https://igbtosqmtdrxzmoblvpp.supabase.co/rest/v1/tournament_participants"
            + "?tournament_id=eq.\(tournament.id)&device_id=eq.\(TournamentManager.shared.myDeviceID)"
        var req = URLRequest(url: URL(string: urlStr)!)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlnYnRvc3FtdGRyeHptb2JsdnBwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTUyMzYsImV4cCI6MjA5Mzk3MTIzNn0.Kbzm3Ev1s48inU2YvkS0v3I6rhBM0evffrb3nRBhfok"
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)

        await MainActor.run {
            manager.activeTournaments.removeAll { $0.id == tournament.id }
        }
    }
}

// MARK: - Tournament Row

private struct TournamentRowView: View {
    let tournament: TournamentRecord
    let participants: [TournamentParticipant]

    @AppStorage("appLanguage") private var appLanguage: String = "English"
    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage { case "Ελληνικά": return gr; case "Deutsch": return de; default: return en }
    }

    private var myParticipant: TournamentParticipant? {
        participants.first(where: { $0.isMe })
    }

    private var myRank: Int? {
        let sorted = participants.sorted { $0.effectiveScore < $1.effectiveScore }
        return sorted.firstIndex(where: { $0.isMe }).map { $0 + 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tournament.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                if let rank = myRank {
                    Text(rankLabel(rank))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(rank == 1 ? .green : .secondary)
                }
            }
            HStack(spacing: 12) {
                Label("\(participants.count)/\(tournament.maxParticipants)", systemImage: "person.2")
                Label(t("\(tournament.daysRemaining)d left", "\(tournament.daysRemaining) μέρες", "\(tournament.daysRemaining) T. übrig"), systemImage: "clock")
            }
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank { case 1: return "🥇 #1"; case 2: return "🥈 #2"; case 3: return "🥉 #3"; default: return "#\(rank)" }
    }
}

// MARK: - Create Tournament Sheet

struct CreateTournamentView: View {
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var created: TournamentRecord? = nil
    @State private var manager = TournamentManager.shared
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage { case "Ελληνικά": return gr; case "Deutsch": return de; default: return en }
    }

    var body: some View {
        NavigationStack {
            if let tournament = created {
                createdState(tournament)
            } else {
                formState
            }
        }
    }

    private var formState: some View {
        VStack(spacing: 24) {
            Text("⚔️").font(.system(size: 48))
            Text(t("New Tournament", "Νέο Τουρνουά", "Neues Turnier"))
                .font(.system(size: 22, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Tournament name", "Όνομα τουρνουά", "Turniername"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField(t("e.g. Office Challenge", "π.χ. Πρόκληση γραφείου", "z.B. Büro-Challenge"), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16, design: .rounded))
            }
            .padding(.horizontal, 24)

            if let msg = manager.errorMessage {
                Text(msg)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Button {
                Task {
                    let result = await manager.createTournament(name: name, myName: userName)
                    if let t = result { created = t }
                }
            } label: {
                Group {
                    if manager.isLoading {
                        ProgressView()
                    } else {
                        Text(t("Create & Get Code", "Δημιουργία & Κωδικός", "Erstellen & Code erhalten"))
                    }
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(name.isEmpty ? Color.gray : Color.blue))
            }
            .disabled(name.isEmpty || manager.isLoading)
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 32)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(t("Cancel", "Άκυρο", "Abbrechen")) { dismiss() }
            }
        }
    }

    private func createdState(_ tournament: TournamentRecord) -> some View {
        VStack(spacing: 20) {
            Text("🎉").font(.system(size: 56))
            Text(t("Tournament created!", "Το τουρνουά δημιουργήθηκε!", "Turnier erstellt!"))
                .font(.system(size: 22, weight: .bold, design: .rounded))

            VStack(spacing: 6) {
                Text(t("Share this code with your friends:", "Μοιράσου αυτόν τον κωδικό με τους φίλους σου:", "Teile diesen Code mit deinen Freunden:"))
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(tournament.inviteCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.1)))
            }

            ShareLink(
                item: shareText(tournament),
                label: {
                    Label(t("Share Invite", "Μοιράσου την πρόσκληση", "Einladung teilen"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                }
            )
            .padding(.horizontal, 24)

            Button(t("Done", "Τέλος", "Fertig")) { dismiss() }
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 32)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shareText(_ tournament: TournamentRecord) -> String {
        t(
            "I'm challenging you to a weekly screen time tournament on Picksy! 📱⚔️\n\nJoin my group with code: \(tournament.inviteCode)\n\nDownload Picksy 👉 https://apps.apple.com/app/picksy-be-present/id6761116771",
            "Σε προκαλώ σε εβδομαδιαία μονομαχία screen time στο Picksy! 📱⚔️\n\nΜπες στην ομάδα μου με κωδικό: \(tournament.inviteCode)\n\nΚατέβασε το Picksy 👉 https://apps.apple.com/app/picksy-be-present/id6761116771",
            "Ich fordere dich zu einem wöchentlichen Bildschirmzeit-Turnier auf Picksy heraus! 📱⚔️\n\nTritt meiner Gruppe mit Code bei: \(tournament.inviteCode)\n\nPicksy herunterladen 👉 https://apps.apple.com/app/picksy-be-present/id6761116771"
        )
    }
}

// MARK: - Join Tournament Sheet

struct JoinTournamentView: View {
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var manager = TournamentManager.shared
    @AppStorage("appLanguage") private var appLanguage: String = "English"

    private func t(_ en: String, _ gr: String, _ de: String) -> String {
        switch appLanguage { case "Ελληνικά": return gr; case "Deutsch": return de; default: return en }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("🔑").font(.system(size: 48))
                Text(t("Join a Tournament", "Συμμετοχή σε Τουρνουά", "Turnier beitreten"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Enter invite code", "Βάλε κωδικό πρόσκλησης", "Einladungscode eingeben"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    TextField("ABC-XYZ", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                if let msg = manager.errorMessage {
                    Text(msg)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task {
                        let ok = await manager.joinTournament(code: code, myName: userName)
                        if ok { dismiss() }
                    }
                } label: {
                    Group {
                        if manager.isLoading {
                            ProgressView()
                        } else {
                            Text(t("Join", "Συμμετοχή", "Beitreten"))
                        }
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(code.count < 3 ? Color.gray : Color.blue))
                }
                .disabled(code.count < 3 || manager.isLoading)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("Cancel", "Άκυρο", "Abbrechen")) { dismiss() }
                }
            }
        }
    }
}
