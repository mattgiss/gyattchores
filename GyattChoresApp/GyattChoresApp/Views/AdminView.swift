import SwiftUI

struct AdminView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataManager: DataManager
    @State private var showAdminCodePrompt = true
    @State private var adminCode = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Group {
                if showAdminCodePrompt && !authManager.isAdmin {
                    adminCodeEntry
                } else {
                    adminContent
                }
            }
            .navigationTitle("Admin")
        }
    }

    // MARK: - Admin Code Entry

    private var adminCodeEntry: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Admin Access Required")
                .font(.title2.bold())

            SecureField("Enter Admin Code", text: $adminCode)
                .textFieldStyle(.plain)
                .font(.system(size: 20, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showError ? Color.red : Color.clear, lineWidth: 2)
                        )
                )
                .frame(maxWidth: 200)

            Button("Verify") {
                if authManager.verifyAdmin(code: adminCode) {
                    showAdminCodePrompt = false
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
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(adminCode.isEmpty)

            if showError {
                Text("Incorrect code")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    // MARK: - Admin Content

    private var adminContent: some View {
        List {
            // Pending Approvals
            Section {
                ForEach(dataManager.pendingCompletions) { completion in
                    PendingApprovalRow(completion: completion) {
                        Task {
                            try? await dataManager.approveCompletion(completion)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } onReject: {
                        Task {
                            try? await dataManager.rejectCompletion(completion)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Pending Approvals")
                    Spacer()
                    Text("\(dataManager.pendingCompletions.count)")
                        .foregroundColor(.orange)
                }
            }

            // Quick Actions
            Section("Quick Actions") {
                Button {
                    // Reset cooldowns
                } label: {
                    Label("Reset All Cooldowns", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    // Backfill entry
                } label: {
                    Label("Add Backfill Entry", systemImage: "plus.circle")
                }

                Button {
                    // View logs
                } label: {
                    Label("View Activity Logs", systemImage: "list.bullet.rectangle")
                }
            }

            // Players Management
            Section("Players") {
                ForEach(dataManager.players) { player in
                    HStack {
                        Text(player.avatarUrl)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text(player.name)
                                .font(.body.weight(.medium))
                            Text("Best: \(player.bestWeekTotal) pts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            // Edit player
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Danger Zone
            Section {
                Button(role: .destructive) {
                    // Clear all pending
                } label: {
                    Label("Clear All Pending", systemImage: "trash")
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("These actions cannot be undone.")
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct PendingApprovalRow: View {
    let completion: ChoreCompletion
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(completion.choreIcon ?? "❓")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(completion.choreName ?? "Unknown Chore")
                        .font(.body.weight(.medium))

                    Text(completion.playerName ?? "Unknown Player")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(completion.valueAwarded) pts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 12) {
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    AdminView()
        .environmentObject(AuthManager())
        .environmentObject(DataManager())
}
