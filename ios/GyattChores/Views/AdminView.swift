import GyattCore
import SwiftUI

/// Parent controls: enter the family code, then approve or reject what the
/// kids submitted. Approval is what turns chores into XP, streaks and log days.
struct AdminView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false

    var body: some View {
        NavigationStack {
            Group {
                if unlocked {
                    ApprovalList()
                } else {
                    AdminGateView { unlocked = true }
                }
            }
            .navigationTitle("ADMIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
    }
}

private struct AdminGateView: View {
    let onUnlock: () -> Void
    @State private var code = ""
    @State private var wrongAttempts = 0
    @FocusState private var codeFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Eyebrow("ADMIN ACCESS")

            SecureField("code", text: $code)
                .font(.mono(.title2))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
                .submitLabel(.go)
                .focused($codeFocused)
                .onSubmit(verify)
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .overlay(Rectangle().strokeBorder(wrongAttempts > 0 ? Theme.danger : Theme.hairline, lineWidth: 1))
                .accessibilityLabel("Admin code")
                .accessibilityIdentifier("admin-code")

            if wrongAttempts > 0 {
                Text("that's not the code")
                    .font(.mono(.caption))
                    .foregroundStyle(Theme.danger)
                    .accessibilityIdentifier("admin-wrong-code")
            }

            Button("ENTER", action: verify)
                .buttonStyle(TerminalButtonStyle(kind: .filled))
                .disabled(code.isEmpty)
                .accessibilityIdentifier("admin-enter")
        }
        .frame(maxWidth: 320)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { codeFocused = true }
        .sensoryFeedback(.error, trigger: wrongAttempts)
    }

    private func verify() {
        if AdminGate.verify(code) {
            onUnlock()
        } else {
            wrongAttempts += 1
            code = ""
            codeFocused = true
        }
    }
}

private struct ApprovalList: View {
    enum Filter: String, CaseIterable, Identifiable {
        case pending, approved, rejected, all
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: GameStore
    @State private var filter: Filter = .pending

    /// Like the web app, show the most recent slice rather than all history.
    private static let limit = 60

    private var shown: [ChoreLog] {
        let matching = store.logs.filter { log in
            switch filter {
            case .all: return true
            case .pending: return log.status == .pending
            case .approved: return log.status == .approved
            case .rejected: return log.status == .rejected
            }
        }
        return Array(matching.prefix(Self.limit))
    }

    var body: some View {
        let shown = self.shown

        VStack(spacing: 0) {
            Picker("Show", selection: $filter) {
                ForEach(Filter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Hairline()

            ScrollView {
                LazyVStack(spacing: 8) {
                    if shown.isEmpty {
                        Text("no \(filter == .all ? "" : filter.rawValue + " ")logs")
                            .font(.mono(.footnote))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 48)
                    }
                    ForEach(shown) { log in
                        ApprovalRow(log: log)
                    }
                }
                .frame(maxWidth: Theme.contentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.success, trigger: store.pendingCount)
    }
}

private struct ApprovalRow: View {
    let log: ChoreLog
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(log.choreName)
                        .font(.mono(.callout, weight: .semibold))
                    Text("\(log.playerName) · \(log.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.mono(.caption2))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("\(log.points)pts")
                    .font(.mono(.footnote, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            if log.status == .pending {
                HStack(spacing: 8) {
                    Button("APPROVE") { store.setStatus(.approved, for: log) }
                        .buttonStyle(TerminalButtonStyle(kind: .outline, color: Theme.success))
                        .accessibilityLabel("Approve \(log.choreName) for \(log.playerName)")
                    Button("REJECT") { store.setStatus(.rejected, for: log) }
                        .buttonStyle(TerminalButtonStyle(kind: .outline, color: Theme.danger))
                        .accessibilityLabel("Reject \(log.choreName) for \(log.playerName)")
                }
            } else {
                Text(log.status.rawValue)
                    .font(.mono(.caption))
                    .tracking(1)
                    .foregroundStyle(log.status == .approved ? Theme.success : Theme.danger)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
