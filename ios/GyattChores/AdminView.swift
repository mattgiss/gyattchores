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
    @FocusState private var codeFocused: Bool
    private var canBio: Bool {
        store.settings.biometricUnlock && LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            // The admin area is in Clear's ocean theme, so it's plain at a glance which mode you're in.
            HStack(spacing: 12) {
                Button("Back") { fb.tap(); if let onBack { onBack() } else { dismiss() } }
                    .font(.app(.callout)).fontWeight(.bold).frame(minWidth: 44, minHeight: 44, alignment: .leading)
                Text("Admin").font(.app(fixedSize: 24, weight: .black))
                Spacer()
            }
            .foregroundStyle(Palette.ocean.ink).tint(Palette.ocean.ink)
            .padding(.horizontal, 16).padding(.bottom, 10)
            .background(Palette.ocean.stops[0].ignoresSafeArea(edges: .top))

            if authed { AdminContent() } else {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("Your admin code", text: $code).textFieldStyle(.roundedBorder).textContentType(.oneTimeCode)
                        .focused($codeFocused)
                        .onSubmit(verify)
                        // Clear the message once they start typing again — not when a wrong code empties the field.
                        .onChange(of: code) { _, now in if !now.isEmpty { wrong = false } }
                    if wrong { Text("That code didn't match. Try again?").font(.app(.footnote)).foregroundStyle(Theme.bad) }
                    TermButton(label: "Unlock", enabled: !code.isEmpty, action: verify).padding(.horizontal, -20)
                    if canBio { OutlineButton(label: "Use Face ID or Touch ID", action: biometric).padding(.horizontal, -20) }
                    Text(forgotCodeNote).font(.app(.footnote)).foregroundStyle(Color.done).padding(.top, 8)
                    Spacer()
                }
                .padding(20)
                // Face ID first when it's on; otherwise the keyboard is up and ready for the code.
                .task { if canBio { biometric() } else { codeFocused = true } }
            }
        }
        .background(Color.appBackground)
        .environment(\.palette, .ocean)
        .tint(Color.appText)
        .onChange(of: authed) { _, now in if now { fb.unlock() } }
        // The scoreboard was erased from in here: there's nothing left to administer.
        .onChange(of: store.isSetUp) { _, now in if !now { if let onBack { onBack() } else { dismiss() } } }
    }

    private var forgotCodeNote: String {
        #if FAMILY_SYNC
        "Forgot your code? Another admin can set a new one for you from their phone."
        #else
        "Forgot your code? It's only kept on this device, so it can't be looked up. Deleting the app erases this scoreboard and lets you start a new one."
        #endif
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
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue.prefix(1).uppercased() + $0.rawValue.dropFirst()).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 14)

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
        let spoken = Dictionary(store.members.map { ($0.id, store.shownName($0)) }, uniquingKeysWith: { first, _ in first })
        Picker("Show", selection: $filter) {
            ForEach([Status.pending, Status.approved, Status.rejected, "all"], id: \.self) { f in
                Text(f == Status.pending ? "Waiting" : f == Status.approved ? "Approved" : f == Status.rejected ? "Turned down" : "Everything").tag(f)
            }
        }
        .pickerStyle(.menu)

        if shown.isEmpty {
            Text(filter == Status.pending ? "Nothing's waiting for you. All caught up!" : filter == Status.approved ? "Nothing's been approved yet."
                 : filter == Status.rejected ? "Nothing's been turned down." : "Nobody's logged a chore yet.")
                .foregroundStyle(Color.done).padding(.vertical, 24)
        }
        // A day's card is usually several chores from one person: approve them in one go.
        if filter == Status.pending {
            let byPlayer = Dictionary(grouping: shown, by: \.playerId)
            ForEach(byPlayer.keys.sorted { (names[$0] ?? $0) < (names[$1] ?? $1) }, id: \.self) { id in
                if let list = byPlayer[id], list.count > 1 {
                    Button("Approve all \(list.count) of \(spoken[id] ?? list[0].playerName)'s chores") {
                        var leveled = false
                        for l in list where store.approve(l) { leveled = true }
                        if leveled { fb.levelUp() } else { fb.approve() }
                    }
                    .buttonStyle(TermButtonStyle(filled: true)).padding(.horizontal, -20).padding(.top, 6)
                    .accessibilityIdentifier("approve-all-\(id)")
                }
            }
        }
        // The one list here that can run to hundreds of rows.
        // Waiting chores are bands down the ocean gradient, with a tick and a cross at the end;
        // ones already judged drop to black, as in Clear.
        LazyVStack(alignment: .leading, spacing: 0) { ForEach(Array(shown.enumerated()), id: \.element.id) { i, l in
            let waiting = l.status == Status.pending
            Band(index: i, count: shown.count, done: !waiting, minHeight: 60) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Said the way you'd hear about it: "Sam emptied the kids bathroom trash today."
                        Text(Phrase.sentence(spoken[l.playerId] ?? l.playerName, l.choreName, on: l.timestamp, today: Date(), calendar: store.calendar))
                            .foregroundStyle(waiting ? Palette.ocean.ink : Color.appText.opacity(0.75))
                        Text(waiting ? "Worth \(l.points) points. Approve it?" : l.status == Status.approved ? "Approved · \(l.points) points" : "Turned down")
                            .font(.app(.callout)).fontWeight(.regular)
                            .foregroundStyle(waiting ? Palette.ocean.ink.opacity(0.85) : l.status == Status.approved ? Theme.good : Theme.bad)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if waiting {
                        Button { if store.approve(l) { fb.levelUp() } else { fb.approve() } } label: {
                            Text("Yes").font(.app(.callout)).fontWeight(.black).foregroundStyle(Palette.ocean.stops[0])
                                .padding(.horizontal, 16).frame(minHeight: 44).background(Palette.ocean.ink, in: Capsule())
                        }
                        .accessibilityLabel("Approve this chore")
                        Button { store.setStatus(l, Status.rejected); fb.reject() } label: {
                            Text("No").font(.app(.callout)).fontWeight(.black).foregroundStyle(Palette.ocean.ink)
                                .padding(.horizontal, 16).frame(minHeight: 44).overlay(Capsule().strokeBorder(Palette.ocean.ink.opacity(0.8), lineWidth: 2))
                        }
                        .accessibilityLabel("Turn down this chore")
                    } else {
                        Text(l.status == Status.approved ? "yes" : "no").font(.app(.footnote)).fontWeight(.black).foregroundStyle(l.status == Status.approved ? Theme.good : Theme.bad)
                    }
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        } }
        .padding(.horizontal, -20)
    }
}

// MARK: - Players

private struct Members: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var editing: Player?
    @State private var adding = false

    var body: some View {
        Text("Admins approve chores and can change everything here. Each admin has their own code.")
            .font(.app(.footnote)).foregroundStyle(.secondary)
        ForEach(store.members) { m in
            VStack(spacing: 0) {
                HStack {
                    Text(store.adminLabel(m)).lineLimit(1)
                    Text([m.isAdmin ? "Admin" : nil, m.plays ? nil : (m.isAdmin ? "not playing" : "Not playing")].compactMap { $0 }.joined(separator: " · "))
                        .font(.app(.footnote)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button("Edit") { fb.tap(); editing = m }.accessibilityLabel("Edit \(m.name)")
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
                    Text(member == nil ? "Add a player" : "Edit player").font(.app(.headline)).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("Cancel") { dismiss() }
                }
                TextField("Username", text: $draft.name)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("member-name")
                TextField("Display name (optional)", text: $draft.displayName)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("The display name is only what's shown. The username is what chores and points are kept under.")
                    .font(.app(.footnote)).foregroundStyle(.secondary)
                Toggle("does chores", isOn: $draft.plays)
                Toggle("Admin", isOn: $draft.isAdmin)
                if draft.isAdmin {
                    SecureField(member?.isAdmin == true ? "New admin code (leave empty to keep theirs)" : "Their admin code (\(AdminCode.minLength) or more)",
                                text: $draft.newCode)
                        .textFieldStyle(.roundedBorder).textContentType(.oneTimeCode)
                        .accessibilityIdentifier("member-code")
                }
                if let problem, !draft.name.isEmpty { Text(problem).font(.app(.footnote)).foregroundStyle(Theme.bad) }
                TermButton(label: "Save", enabled: problem == nil) {
                    if store.saveMember(draft, id: member?.id) { fb.approve(); dismiss() }
                }
                if let member, store.canRemove(member) {
                    Button("Remove \(member.name)…", role: .destructive) { confirmingRemove = true }
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
            .font(.app(.footnote)).foregroundStyle(.secondary)
        Button("+ add chores") { fb.tap(); adding = true }.buttonStyle(.bordered).padding(.vertical, 12)
            .sheet(item: $editing) { c in ChoreEditor(chore: c).appChrome(store, fb) }
            .sheet(isPresented: $adding) { ChoreAdder().appChrome(store, fb) }
        ForEach(store.pool) { c in
            VStack(spacing: 0) {
                HStack {
                    Text(c.name).lineLimit(1)
                    Spacer()
                    Text("\(c.tiers.first ?? 0)m").foregroundStyle(.secondary)
                    Button("Edit") { fb.tap(); editing = c }.accessibilityLabel("Edit \(c.name)").padding(.leading, 8)
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
                    Text("Add chores").font(.app(.headline)).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("Cancel") { dismiss() }
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
                    Text("Edit chore").font(.app(.headline)).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("Cancel") { dismiss() }
                }
                TextField("Chore", text: $name)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                    .accessibilityIdentifier("chore-name")
                Stepper("\(minutes) minutes", value: $minutes, in: ChoreIntake.minuteRange)
                Text("Worth \(ChoreIntake.make(name: "x", minutes: minutes).pts) points.").font(.app(.footnote)).foregroundStyle(.secondary)
                if clash { Text("There's already a chore with that name.").font(.app(.footnote)).foregroundStyle(Theme.bad) }
                TermButton(label: "Save", enabled: clean != nil && !clash) {
                    store.updateChore(chore, name: name, minutes: minutes); fb.approve(); dismiss()
                }
                if store.pool.count > 1 {
                    Button("Remove this chore", role: .destructive) { store.removeChore(chore); fb.reject(); dismiss() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Text("Points already earned for it are kept.").font(.app(.footnote)).foregroundStyle(.secondary)
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
            Toggle("Face ID or Touch ID opens Admin", isOn: Binding(get: { store.settings.biometricUnlock }, set: { store.setBiometricUnlock($0) }))
            Text("Only turn this on if this is your own device, not a player's.").font(.app(.footnote)).foregroundStyle(.secondary)
        }
        #if FAMILY_SYNC
        SectionLabel("this phone belongs to")
        Text("Dares are made as this person.").font(.app(.footnote)).foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.players) { p in
                    if p.id == store.me { Button(store.shownName(p)) {}.buttonStyle(.borderedProminent) }
                    else { Button(store.shownName(p)) { fb.tap(); store.setMe(p) }.buttonStyle(.bordered) }
                }
            }
        }
        SectionLabel("your data")
        Text("This is the family build. Players, chores, codes and points are shared with the family's other phones. Sync: \(store.syncStatus).")
            .font(.app(.callout)).foregroundStyle(.secondary)
        SectionLabel("backup")
        Text("Save the whole scoreboard as a file, or add one saved earlier (from this app or the public one, on iPhone or Android) to the family.")
            .font(.app(.footnote)).foregroundStyle(.secondary)
        BackupControls().padding(.top, 4)
        Text("Version \(AppInfo.version)").font(.app(.footnote)).foregroundStyle(.secondary).padding(.top, 8)
        #else
        SectionLabel("your data")
        Text("Everything this app knows, from names to chores and points, is kept on this device and nowhere else. There's no account and nothing is sent to anyone, including us. Deleting the app deletes it all.")
            .font(.app(.callout)).foregroundStyle(.secondary)
        Link("Privacy policy", destination: Links.privacy).font(.app(.callout)).frame(minHeight: 44)
        SectionLabel("backup")
        Text("Save the whole scoreboard as a file you keep, in Files, iCloud Drive or anywhere you like. Restore it on a new phone, or bring it into a family account later.")
            .font(.app(.footnote)).foregroundStyle(.secondary)
        BackupControls().padding(.top, 4)
        eraseButton
        #endif
    }

    private var eraseButton: some View {
        Button("Erase everything…", role: .destructive) { confirmingErase = true }
            .buttonStyle(.bordered).padding(.vertical, 12)
            .confirmationDialog("Erase this scoreboard?", isPresented: $confirmingErase, titleVisibility: .visible) {
                Button("Erase players, chores and points", role: .destructive) { fb.reject(); store.eraseEverything() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Everything is deleted from this device and the app starts over. This can't be undone — save a backup first if you might want it back.") }
    }
}

extension View {
    /// Sheets are their own window: hand them the app's objects and look.
    func appChrome(_ store: AppStore, _ fb: Feedback) -> some View {
        environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent).preferredColorScheme(.dark)
    }
}
