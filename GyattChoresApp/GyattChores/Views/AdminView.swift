import SwiftUI

struct AdminView: View {
    @EnvironmentObject var store: ChoreStore
    @Environment(\.dismiss) private var dismiss
    @State private var adminCode = ""
    @State private var isUnlocked = false
    @State private var showError = false

    private let correctCode = "7874"

    var body: some View {
        NavigationStack {
            Group {
                if isUnlocked {
                    approvalList
                } else {
                    codeEntry
                }
            }
            .navigationTitle(isUnlocked ? "Pending Approval" : "Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                if isUnlocked && !store.pendingLogs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Approve All") {
                            store.approveAll()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Code Entry

    private var codeEntry: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)

            SecureField("Enter Code", text: $adminCode)
                .textFieldStyle(.plain)
                .font(.system(size: 24, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showError ? Color.red : Color.clear, lineWidth: 2)
                        }
                }
                .frame(maxWidth: 180)
                .onChange(of: adminCode) { _, newValue in
                    if newValue.count == 4 {
                        checkCode()
                    }
                }

            if showError {
                Text("Incorrect code")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    private func checkCode() {
        if adminCode == correctCode {
            withAnimation {
                isUnlocked = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            showError = true
            adminCode = ""
            UINotificationFeedbackGenerator().notificationOccurred(.error)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showError = false
            }
        }
    }

    // MARK: - Approval List

    private var approvalList: some View {
        Group {
            if store.pendingLogs.isEmpty {
                ContentUnavailableView(
                    "All Caught Up",
                    systemImage: "checkmark.circle.fill",
                    description: Text("No chores waiting for approval")
                )
            } else {
                List {
                    ForEach(store.pendingLogs) { log in
                        PendingLogRow(log: log)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    store.approve(log)
                                } label: {
                                    Label("Approve", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.reject(log)
                                } label: {
                                    Label("Reject", systemImage: "xmark")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Pending Log Row

struct PendingLogRow: View {
    let log: ChoreLog
    @EnvironmentObject var store: ChoreStore

    private var playerName: String {
        store.players.first { $0.id == log.playerId }?.name ?? "Unknown"
    }

    private var playerAvatar: String {
        store.players.first { $0.id == log.playerId }?.avatar ?? "👤"
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(log.choreIcon)
                .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
                Text(log.choreName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(playerAvatar)
                    Text(playerName)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Text(log.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(log.points)")
                .font(.headline)
                .foregroundStyle(.cyan)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    AdminView()
        .environmentObject(ChoreStore())
}
