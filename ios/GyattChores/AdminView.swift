import SwiftUI
import LocalAuthentication
import GyattCore

/// Parent area: Face ID / Touch ID first, the web app's admin code as the fallback.
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
    private var canBio: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← back") { fb.tap(); if let onBack { onBack() } else { dismiss() } }
                Text("ADMIN").font(.headline).foregroundStyle(Theme.accent).padding(.leading, 8)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if authed { AdminContent() } else {
                VStack(spacing: 12) {
                    SecureField("admin code", text: $code).textFieldStyle(.roundedBorder).textContentType(.oneTimeCode)
                        .onSubmit(verify)
                        // Clear the message once they start typing again — not when a wrong code empties the field.
                        .onChange(of: code) { _, now in if !now.isEmpty { wrong = false } }
                    if wrong { Text("that code didn't match").font(.footnote).foregroundStyle(Theme.bad).frame(maxWidth: .infinity, alignment: .leading) }
                    TermButton(label: "UNLOCK", enabled: !code.isEmpty, action: verify)
                    if canBio { OutlineButton(label: "use face id / touch id", action: biometric) }
                    Spacer()
                }
                .padding(20)
                .task { if canBio { biometric() } }
            }
        }
        .onChange(of: authed) { _, now in if now { fb.unlock() } }
    }

    private func verify() {
        if store.checkAdminCode(code) { authed = true } else { wrong = true; code = ""; fb.error() }
    }

    private func biometric() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use code"
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock chore approvals") { ok, _ in
            if ok { Task { @MainActor in authed = true } }
        }
    }
}

private struct AdminContent: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var filter = Status.pending
    @State private var editing: Player?
    @State private var adding = false
    @State private var name = ""

    var body: some View {
        let shown = store.logs.filter { filter == "all" || $0.status == filter }.sorted { $0.timestamp > $1.timestamp }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Picker("filter", selection: $filter) {
                    ForEach([Status.pending, Status.approved, Status.rejected, "all"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)

                if shown.isEmpty { Text("nothing \(filter)").foregroundStyle(.secondary).padding(.vertical, 24) }
                ForEach(shown) { l in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(l.playerName) · \(l.choreName)")
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
                }

                SectionLabel("this phone belongs to")
                Text("dares are made as this person. only a parent can change it.").font(.footnote).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.players) { p in
                            if p.id == store.me { Button(p.name) {}.buttonStyle(.borderedProminent) }
                            else { Button(p.name) { fb.tap(); store.setMe(p) }.buttonStyle(.bordered) }
                        }
                    }
                }
                .padding(.vertical, 6)

                SectionLabel("players")
                ForEach(store.players) { p in
                    HStack { Text(p.name); Spacer(); Button("edit") { name = p.name; editing = p } }.frame(minHeight: 44)
                }
                Button("+ add player") { name = ""; adding = true }.buttonStyle(.bordered).padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .alert("Edit player", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("name", text: $name)
            Button("Save") { if let p = editing { store.renamePlayer(p, name) } }
            if store.players.count > 1 { Button("Remove player", role: .destructive) { if let p = editing { store.removePlayer(p) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Removing a player keeps their history.") }
        .alert("Add player", isPresented: $adding) {
            TextField("name", text: $name)
            Button("Save") { store.addPlayer(name) }
            Button("Cancel", role: .cancel) {}
        }
    }
}
