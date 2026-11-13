import SwiftUI
import LocalAuthentication
import GyattCore

/// The admin area: approving chores, and changing the players, the chore list and this device's
/// settings. Opened with any admin's code, or with Face ID / Touch ID if an admin switched that on.
struct AdminView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    /// Set when this is shown in a pane, not presented over the app: closes the pane.
    var onBack: (() -> Void)? = nil
    // Not saved: closing the screen locks it again.
    @State private var authed = false
    @State private var code = ""
    @State private var wrong = false
    private var canBio: Bool {
        store.settings.biometricUnlock && LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← back") { fb.tap(); if let onBack { onBack() } else { dismiss() } }
                Text("ADMIN").font(.headline).foregroundStyle(Theme.accent).padding(.leading, 8)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if authed { AdminContent() } else {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("admin code", text: $code).textFieldStyle(.roundedBorder).textContentType(.oneTimeCode)
                        .onSubmit(verify)
                        // Clear the message once they start typing again — not when a wrong code empties the field.
                        .onChange(of: code) { _, now in if !now.isEmpty { wrong = false } }
                    if wrong { Text("that code didn't match").font(.footnote).foregroundStyle(Theme.bad) }
                    TermButton(label: "UNLOCK", enabled: !code.isEmpty, action: verify)
                    if canBio { OutlineButton(label: "use face id / touch id", action: biometric) }
                    Text("forgot the code? it's kept only on this device, so it can't be looked up. deleting the app erases this scoreboard and lets you start a new one.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    Spacer()
                }
                .padding(20)
                .task { if canBio { biometric() } }
            }
        }
        .onChange(of: authed) { _, now in if now { fb.unlock() } }
        // The scoreboard was erased from in here: there's nothing left to administer.
        .onChange(of: store.isSetUp) { _, now in if !now { if let onBack { onBack() } else { dismiss() } } }
    }

    private func verify() {
        if store.checkAdminCode(code) { authed = true } else { wrong = true; code = ""; fb.error() }
    }

    private func biometric() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use code"
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Open the admin area") { ok, _ in
            if ok { Task { @MainActor in authed = true } }
        }
    }
}

private struct AdminContent: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    private enum Section: String, CaseIterable { case approve, players, chores, device }
    @State private var section = Section.approve

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Picker("section", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 12)

                switch section {
                case .approve: Approvals()
                case .players: Members()
                case .chores: ChoreList()
                case .device: Device()
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Approvals

private struct Approvals: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var filter = Status.pending

    var body: some View {
        let shown = store.logs.filter { filter == "all" || $0.status == filter }.sorted { $0.timestamp > $1.timestamp }
        let names = Dictionary(store.members.map { ($0.id, store.adminLabel($0)) }, uniquingKeysWith: { first, _ in first })
        Picker("show", selection: $filter) {
            ForEach([Status.pending, Status.approved, Status.rejected, "all"], id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)

        if shown.isEmpty { Text("nothing \(filter == "all" ? "logged yet" : filter)").foregroundStyle(.secondary).padding(.vertical, 24) }
        // The one list here that can run to hundreds of rows.
        LazyVStack(alignment: .leading, spacing: 0) { ForEach(shown) { l in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(names[l.playerId] ?? l.playerName) · \(l.choreName)")
                Text("\(l.points) xp · \(l.minutes.map { "\($0)m · " } ?? "")\(l.timestamp.formatted(date: .numeric, time: .shortened)) · \(l.status)")
                    .font(.footnote).foregroundStyle(.secondary)
                if l.status == Status.pending {
                    HStack(spacing: 8) {
                        Button("✓ approve") { if store.approve(l) { fb.levelUp() } else { fb.approve() } }.buttonStyle(.bordered).tint(Theme.good)
                        Button("✗ reject") { store.setStatus(l, Status.rejected); fb.reject() }.buttonStyle(.bordered).tint(Theme.bad)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 10)
            Divider()
        } }
    }
}

// MARK: - Players

private struct Members: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var editing: Player?
    @State private var adding = false

    var body: some View {
        Text("admins approve chores and can change everything here. each admin has their own code.")
            .font(.footnote).foregroundStyle(.secondary)
        ForEach(store.members) { m in
            VStack(spacing: 0) {
                HStack {
                    Text(store.adminLabel(m)).lineLimit(1)
                    Text([m.isAdmin ? "admin" : nil, m.plays ? nil : "not playing"].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button("edit") { fb.tap(); editing = m }.accessibilityLabel("edit \(m.name)")
                }
                .frame(minHeight: 48)
                Divider()
            }
        }
        Button("+ add player") { fb.tap(); adding = true }.buttonStyle(.bordered).padding(.vertical, 12)
            .sheet(item: $editing) { m in MemberEditor(member: m).appChrome(store, fb) }
            .sheet(isPresented: $adding) { MemberEditor(member: nil).appChrome(store, fb) }
    }
}

private struct MemberEditor: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    let member: Player?
    @State private var draft = AppStore.MemberDraft()
    @State private var confirmingRemove = false

    var body: some View {
        let problem = store.problem(with: draft, for: member?.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(member == nil ? "ADD PLAYER" : "EDIT PLAYER").font(.headline).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("cancel") { dismiss() }
                }
                TextField("username", text: $draft.name)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("member-name")
                TextField("display name (optional)", text: $draft.displayName)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("the display name is only what's shown; the username is what chores and points are kept under.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("does chores", isOn: $draft.plays)
                Toggle("admin", isOn: $draft.isAdmin)
                if draft.isAdmin {
                    SecureField(member?.isAdmin == true ? "new admin code (leave empty to keep theirs)" : "their admin code (\(AdminCode.minLength) or more)",
                                text: $draft.newCode)
                        .textFieldStyle(.roundedBorder).textContentType(.oneTimeCode)
                        .accessibilityIdentifier("member-code")
                }
                if let problem, !draft.name.isEmpty { Text(problem).font(.footnote).foregroundStyle(Theme.bad) }
                TermButton(label: "SAVE", enabled: problem == nil) {
                    if store.saveMember(draft, id: member?.id) { fb.approve(); dismiss() }
                }
                if let member, store.canRemove(member) {
                    Button("remove \(member.name)…", role: .destructive) { confirmingRemove = true }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .confirmationDialog("Remove \(member.name)?", isPresented: $confirmingRemove, titleVisibility: .visible) {
                            Button("Remove and delete their history", role: .destructive) { store.removeMember(member); dismiss() }
                            Button("Cancel", role: .cancel) {}
                        } message: { Text("Their chores and points are deleted from this device. This can't be undone.") }
                }
            }
            .padding(20)
        }
        .onAppear { if let member { draft = store.draft(for: member) } }
        .presentationDetents([.large])
    }
}

// MARK: - Chores

private struct ChoreList: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var editing: Chore?
    @State private var adding = false

    var body: some View {
        Text("\(store.pool.count) chores. left undone, a chore takes longer the next time it's picked.")
            .font(.footnote).foregroundStyle(.secondary)
        Button("+ add chores") { fb.tap(); adding = true }.buttonStyle(.bordered).padding(.vertical, 12)
            .sheet(item: $editing) { c in ChoreEditor(chore: c).appChrome(store, fb) }
            .sheet(isPresented: $adding) { ChoreAdder().appChrome(store, fb) }
        ForEach(store.pool) { c in
            VStack(spacing: 0) {
                HStack {
                    Text(c.name).lineLimit(1)
                    Spacer()
                    Text("\(c.tiers.first ?? 0)m").foregroundStyle(.secondary)
                    Button("edit") { fb.tap(); editing = c }.accessibilityLabel("edit \(c.name)").padding(.leading, 8)
                }
                .frame(minHeight: 48)
                Divider()
            }
        }
    }
}

private struct ChoreAdder: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ADD CHORES").font(.headline).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("cancel") { dismiss() }
                }
                ChoreIntakeView(existing: store.pool) { store.addChores($0); fb.approve(); dismiss() }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct ChoreEditor: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    let chore: Chore
    @State private var name = ""
    @State private var minutes = 5

    var body: some View {
        let clean = ChoreIntake.tidyName(name)
        let clash = clean.map { n in store.pool.contains { $0.id != chore.id && $0.name == n } } ?? false
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("EDIT CHORE").font(.headline).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("cancel") { dismiss() }
                }
                TextField("chore", text: $name)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                    .accessibilityIdentifier("chore-name")
                Stepper("\(minutes) minutes", value: $minutes, in: ChoreIntake.minuteRange)
                Text("worth \(ChoreIntake.make(name: "x", minutes: minutes).pts) points.").font(.footnote).foregroundStyle(.secondary)
                if clash { Text("there's already a chore with that name").font(.footnote).foregroundStyle(Theme.bad) }
                TermButton(label: "SAVE", enabled: clean != nil && !clash) {
                    store.updateChore(chore, name: name, minutes: minutes); fb.approve(); dismiss()
                }
                if store.pool.count > 1 {
                    Button("remove this chore", role: .destructive) { store.removeChore(chore); fb.reject(); dismiss() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Text("points already earned for it are kept.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .onAppear { name = chore.name; minutes = chore.tiers.first ?? 5 }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Device

private struct Device: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var confirmingErase = false
    private var hasBio: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) }

    var body: some View {
        if hasBio {
            Toggle("face id / touch id opens the admin area", isOn: Binding(get: { store.settings.biometricUnlock }, set: { store.setBiometricUnlock($0) }))
            Text("only turn this on if this is your own device, not a player's.").font(.footnote).foregroundStyle(.secondary)
        }
        SectionLabel("your data")
        Text("everything this app knows — names, chores and points — is kept on this device and nowhere else. there's no account and nothing is sent to anyone, including us. deleting the app deletes it all.")
            .font(.callout).foregroundStyle(.secondary)
        Button("erase everything…", role: .destructive) { confirmingErase = true }
            .buttonStyle(.bordered).padding(.vertical, 12)
            .confirmationDialog("Erase this scoreboard?", isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Erase players, chores and points", role: .destructive) { fb.reject(); store.eraseEverything() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Everything is deleted from this device and the app starts over. This can't be undone.") }
    }
}

extension View {
    /// Sheets are their own window: hand them the app's objects and look.
    func appChrome(_ store: AppStore, _ fb: Feedback) -> some View {
        environmentObject(store).environmentObject(fb).fontDesign(.monospaced).tint(Theme.accent)
    }
}
