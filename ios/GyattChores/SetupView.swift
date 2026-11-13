import SwiftUI
import LocalAuthentication
import GyattCore

/// First run: who's in charge, who's playing, what needs doing. No account is made and nothing is
/// sent anywhere; at the end the family exists on this device and nowhere else.
struct SetupView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback

    private enum Step: Int { case welcome, admin, players, chores }
    @State private var step = Step.welcome
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
                Text("GYATTCHORES").font(.title).bold().kerning(4).foregroundStyle(Theme.accent)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if step != .welcome { Text("step \(step.rawValue) of 3").font(.footnote).foregroundStyle(.secondary) }
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
                        Button("← back") { fb.tap(); back() }.foregroundStyle(.secondary).frame(minHeight: 44)
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
        Text("a chore scoreboard for your family.").font(.headline).padding(.top, 8)
        VStack(alignment: .leading, spacing: 6) {
            Text("· everyone picks \(Engine.dailyMinutes) minutes of chores a day")
            Text("· an admin approves what got done")
            Text("· points, streaks and a weekly winner follow")
        }
        .foregroundStyle(.secondary)
        SectionLabel("private by design")
        VStack(alignment: .leading, spacing: 6) {
            Text("· everything stays on this device")
            Text("· no accounts, no sign-in, no ads, no tracking")
            Text("· delete the app and it's all gone")
        }
        .foregroundStyle(.secondary)
        if !alreadyHere.isEmpty {
            Text("your players and their points are still here. this device now keeps its own scoreboard: it no longer shares with other phones.")
                .font(.footnote).foregroundStyle(Theme.warn).padding(.top, 4)
        }
        TermButton(label: "SET UP THIS DEVICE") { fb.tap(); step = .admin }.padding(.top, 12)
        Link("privacy policy", destination: Links.privacy).font(.footnote).frame(maxWidth: .infinity, minHeight: 44)
    }

    // MARK: Admin

    private var codeProblem: String? {
        if code.isEmpty { return nil }
        if !AdminCode.isLongEnough(code) { return "the code needs \(AdminCode.minLength) or more characters" }
        if !codeAgain.isEmpty, code != codeAgain { return "those two codes don't match" }
        return nil
    }
    private var adminReady: Bool {
        !adminName.trimmingCharacters(in: .whitespaces).isEmpty && AdminCode.isLongEnough(code) && code == codeAgain
    }

    @ViewBuilder private var admin: some View {
        Text("who's in charge?").font(.headline).padding(.top, 8)
        Text("an admin approves chores and can change the players and the chore list. you can make more people admins later.")
            .font(.callout).foregroundStyle(.secondary)
        TextField("your name", text: $adminName)
            .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
            .submitLabel(.done).accessibilityIdentifier("admin-name")
        SecureField("admin code (\(AdminCode.minLength) or more)", text: $code)
            .textFieldStyle(.roundedBorder).textContentType(.oneTimeCode).submitLabel(.done)
            .accessibilityIdentifier("admin-code")
        SecureField("the same code again", text: $codeAgain)
            .textFieldStyle(.roundedBorder).textContentType(.oneTimeCode).submitLabel(.done)
            .accessibilityIdentifier("admin-code-again")
        if let codeProblem { Text(codeProblem).font(.footnote).foregroundStyle(Theme.bad) }
        Text("keep the code from the players. it isn't stored anywhere but this device, so nobody can look it up for you: if it's forgotten, the way back in is to delete the app and start a new scoreboard.")
            .font(.footnote).foregroundStyle(.secondary)
        Toggle("i do chores too", isOn: $adminPlays)
        if canBio {
            Toggle("face id / touch id also opens the admin area", isOn: $biometricUnlock)
            Text("only turn this on if this is your own device, not a player's.").font(.footnote).foregroundStyle(.secondary)
        }
        TermButton(label: "NEXT", enabled: adminReady) { fb.tap(); step = .players }.padding(.top, 4)
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
        Text("who's playing?").font(.headline).padding(.top, 8)
        Text("everyone who does chores. first names or nicknames are plenty, and you can add or change them later.")
            .font(.callout).foregroundStyle(.secondary)
        if adminPlays, !adminIsListed { nameRow(adminName.trimmingCharacters(in: .whitespaces), note: "you") }
        ForEach(alreadyHere, id: \.self) { nameRow($0, note: "already here") }
        ForEach(playerNames, id: \.self) { name in
            nameRow(name, note: nil) { fb.tap(); playerNames.removeAll { $0 == name } }
        }
        HStack(spacing: 8) {
            TextField("a player's name", text: $newName)
                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.done).onSubmit(addName).accessibilityIdentifier("player-name")
            Button("+ add") { fb.tick(true); addName() }.buttonStyle(.bordered)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        // A name still sitting in the box counts: it's easy to type it and forget to press add.
        TermButton(label: "NEXT", enabled: anyoneToPlay) { fb.tap(); addName(); step = .chores }.padding(.top, 4)
    }

    private func nameRow(_ name: String, note: String?, onRemove: (() -> Void)? = nil) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("> ").foregroundStyle(Theme.accent)
                Text(name).lineLimit(1)
                if let note { Text("· \(note)").font(.footnote).foregroundStyle(.secondary) }
                Spacer()
                if let onRemove { Button("remove", action: onRemove).font(.footnote) }
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
        Text("what needs doing?").font(.headline).padding(.top, 8)
        if writingChores {
            ChoreIntakeView(existing: []) { finish(with: $0) }
        } else {
            Text("start from a list of \(store.starterChores.count) everyday chores, or write your own. either way an admin can add, change and remove chores at any time.")
                .font(.callout).foregroundStyle(.secondary)
            TermButton(label: "USE THE STARTER LIST") { finish(with: store.starterChores) }
            OutlineButton(label: "write or say your own") { fb.tap(); writingChores = true }
        }
    }
}
