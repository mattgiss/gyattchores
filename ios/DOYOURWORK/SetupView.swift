import SwiftUI
import LocalAuthentication
import DoYourWorkCore

/// First run: who's in charge, who's playing, what needs doing. No account is made and nothing is
/// sent anywhere; at the end the family exists on this device and nowhere else.
struct SetupView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback

    private enum Step: Int { case welcome, admin, players, chores }
    @State private var step = Step.welcome
    @State private var joining = false
    @State private var adminName = ""
    @State private var code = ""
    @State private var codeAgain = ""
    @State private var adminPlays = false
    @State private var biometricUnlock = false
    @State private var playerNames: [String] = []
    @State private var newName = ""
    @State private var writingChores = false

    private var canBio: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) }
    /// People already here from an earlier version of the app: they stay.
    private var alreadyHere: [String] { store.existingPlayerNames }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("DOYOURWORK").font(.app(fixedSize: 34, weight: .black)).lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(Palette.heat.stops[0])
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if step != .welcome { Text("Step \(step.rawValue) of 3").font(.app(.footnote)).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
            // The same column as the steps below, so the title sits above them on an iPad too.
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch step {
                    case .welcome: welcome
                    case .admin: admin
                    case .players: players
                    case .chores: chores
                    }
                    if step != .welcome {
                        Button("Back") { fb.tap(); back() }.foregroundStyle(.secondary).frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
                // Reads better as a column than stretched across an iPad.
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func back() {
        if step == .chores, writingChores { writingChores = false; return }
        step = Step(rawValue: step.rawValue - 1) ?? .welcome
    }

    // MARK: Welcome

    @ViewBuilder private var welcome: some View {
        Text("A chore scoreboard for your family.").font(.app(.headline)).padding(.top, 8)
        VStack(alignment: .leading, spacing: 6) {
            Text("Everyone picks \(Engine.dailyMinutes) minutes of chores a day.")
            Text("An admin approves what got done.")
            Text("Points, streaks and a weekly winner follow.")
        }
        .foregroundStyle(.secondary)
        SectionLabel("private by design")
        VStack(alignment: .leading, spacing: 6) {
            Text("Everything stays on this device.")
            Text("Add a phone later and it's encrypted before it's sent, so only your family's phones can read it.")
            Text("No accounts, no sign-in, no ads, no tracking.")
        }
        .foregroundStyle(.secondary)
        if !alreadyHere.isEmpty && !store.isLinked {
            Text("Your players and their points are still here. This device now keeps its own scoreboard and no longer shares with other phones.")
                .font(.app(.footnote)).foregroundStyle(Theme.warn).padding(.top, 4)
        }
        TermButton(label: "Set up this device") { fb.tap(); step = .admin }.padding(.top, 12)
        // A new phone for a family that's already on another phone.
        OutlineButton(label: "Join a family") { fb.tap(); joining = true }.padding(.horizontal, -20)
            .sheet(isPresented: $joining) { JoinSheet().appChrome(store, fb) }
        // A new phone for a family that already has a scoreboard saved as a file.
        BackupControls(canSave: false).padding(.top, 4)
        Link("Privacy policy", destination: Links.privacy).font(.app(.footnote)).frame(maxWidth: .infinity, minHeight: 44)
    }

    // MARK: Admin

    private var codeProblem: String? {
        if code.isEmpty { return nil }
        if !AdminCode.isLongEnough(code) { return "The code needs \(AdminCode.minLength) or more characters." }
        if !codeAgain.isEmpty, code != codeAgain { return "Those two codes don't match." }
        return nil
    }
    private var adminReady: Bool {
        !adminName.trimmingCharacters(in: .whitespaces).isEmpty && AdminCode.isLongEnough(code) && code == codeAgain
    }

    @ViewBuilder private var admin: some View {
        Text("Who's in charge?").font(.app(.headline)).padding(.top, 8)
        Text("An admin approves chores and can change the players and the chore list. You can make more people admins later.")
            .font(.app(.callout)).foregroundStyle(.secondary)
        TextField("Your name", text: $adminName)
            .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
            .submitLabel(.done).accessibilityIdentifier("admin-name")
        SecureField("Admin code (\(AdminCode.minLength) or more)", text: $code)
            .textFieldStyle(.roundedBorder).textContentType(.oneTimeCode).submitLabel(.done)
            .accessibilityIdentifier("admin-code")
        SecureField("The same code again", text: $codeAgain)
            .textFieldStyle(.roundedBorder).textContentType(.oneTimeCode).submitLabel(.done)
            .accessibilityIdentifier("admin-code-again")
        if let codeProblem { Text(codeProblem).font(.app(.footnote)).foregroundStyle(Theme.bad) }
        Text(store.isLinked
             ? "Keep the code from the players. Only a scrambled copy is shared with the family's phones. If it's forgotten, another admin can set a new one."
             : "Keep the code from the players. It isn't stored anywhere but this device, so nobody can look it up for you. If it's forgotten, the way back in is to delete the app and start a new scoreboard.")
            .font(.app(.footnote)).foregroundStyle(.secondary)
        Toggle("I do chores too", isOn: $adminPlays)
        if canBio {
            Toggle("Face ID or Touch ID also opens Admin", isOn: $biometricUnlock)
            Text("Only turn this on if this is your own device, not a player's.").font(.app(.footnote)).foregroundStyle(.secondary)
        }
        TermButton(label: "Next", enabled: adminReady) { fb.tap(); step = .players }.padding(.top, 4)
    }

    // MARK: Players

    private var adminIsListed: Bool {
        let name = adminName.trimmingCharacters(in: .whitespaces).lowercased()
        return (alreadyHere + playerNames).contains { $0.lowercased() == name }
    }
    private var anyoneToPlay: Bool {
        adminPlays || !alreadyHere.isEmpty || !playerNames.isEmpty || !newName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addName() {
        let name = newName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        newName = ""
        let taken = (alreadyHere + playerNames + [adminName.trimmingCharacters(in: .whitespaces)]).map { $0.lowercased() }
        guard !name.isEmpty, !taken.contains(name.lowercased()) else { return }
        playerNames.append(name)
    }

    @ViewBuilder private var players: some View {
        Text("Who's playing?").font(.app(.headline)).padding(.top, 8)
        Text("Everyone who does chores. First names or nicknames are plenty, and you can add or change them later.")
            .font(.app(.callout)).foregroundStyle(.secondary)
        if adminPlays, !adminIsListed { nameRow(adminName.trimmingCharacters(in: .whitespaces), note: "you") }
        ForEach(alreadyHere, id: \.self) { nameRow($0, note: "Already here") }
        ForEach(playerNames, id: \.self) { name in
            nameRow(name, note: nil) { fb.tap(); playerNames.removeAll { $0 == name } }
        }
        HStack(spacing: 8) {
            TextField("A player's name", text: $newName)
                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.done).onSubmit(addName).accessibilityIdentifier("player-name")
            Button("+ add") { fb.tick(true); addName() }.buttonStyle(.bordered)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        // A name still sitting in the box counts: it's easy to type it and forget to press add.
        TermButton(label: "Next", enabled: anyoneToPlay) { fb.tap(); addName(); step = .chores }.padding(.top, 4)
    }

    private func nameRow(_ name: String, note: String?, onRemove: (() -> Void)? = nil) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("> ").foregroundStyle(Theme.accent)
                Text(name).lineLimit(1)
                if let note { Text("· \(note)").font(.app(.footnote)).foregroundStyle(.secondary) }
                Spacer()
                if let onRemove { Button("Remove", action: onRemove).font(.app(.footnote)) }
            }
            .frame(minHeight: 44)
            Divider()
        }
    }

    // MARK: Chores

    private func finish(with chores: [Chore]) {
        fb.lockIn()
        store.finishSetup(adminName: adminName, adminPlays: adminPlays, code: code, biometricUnlock: biometricUnlock,
                          playerNames: playerNames, chores: chores)
    }

    @ViewBuilder private var chores: some View {
        Text("What needs doing?").font(.app(.headline)).padding(.top, 8)
        if writingChores {
            ChoreIntakeView(existing: []) { finish(with: $0) }
        } else {
            Text("Start from a list of \(store.starterChores.count) everyday chores, or write your own. Either way, an admin can add, change and remove chores at any time.")
                .font(.app(.callout)).foregroundStyle(.secondary)
            TermButton(label: "Use the starter list") { finish(with: store.starterChores) }
            OutlineButton(label: "Write or say your own") { fb.tap(); writingChores = true }
        }
    }
}


