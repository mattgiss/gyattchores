import SwiftUI

struct AdminView: View {
    @EnvironmentObject var store: ChoreStore
    @Environment(\.dismiss) private var dismiss
    @State private var adminCode = ""
    @State private var isUnlocked = false
    @State private var showError = false
    @State private var shakeOffset: CGFloat = 0

    private let correctCode = "7874"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundDark
                    .ignoresSafeArea()

                Group {
                    if isUnlocked {
                        approvalList
                    } else {
                        codeEntry
                    }
                }
            }
            .navigationTitle(isUnlocked ? "Pending" : "Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        HapticManager.shared.tabSwitch()
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent)
                }

                if isUnlocked && !store.pendingLogs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                store.approveAll()
                            }
                        } label: {
                            Text("Approve All")
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.accentGradient)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Code Entry

    private var codeEntry: some View {
        VStack(spacing: 32) {
            Spacer()

            // Lock icon with glow
            ZStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .blur(radius: 20)
                    .opacity(0.5)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.primaryGradient)
            }

            // Code input
            SecureField("Enter Code", text: $adminCode)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.backgroundCard)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(showError ? Color.red : AppTheme.backgroundCardLight, lineWidth: 2)
                        }
                }
                .frame(maxWidth: 200)
                .offset(x: shakeOffset)
                .onChange(of: adminCode) { _, newValue in
                    if newValue.count == 4 {
                        checkCode()
                    }
                }

            if showError {
                Text("Incorrect code")
                    .foregroundStyle(.red)
                    .font(.caption.weight(.medium))
                    .transition(.opacity)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    private func checkCode() {
        if adminCode == correctCode {
            HapticManager.shared.approved()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isUnlocked = true
            }
        } else {
            HapticManager.shared.rejected()
            withAnimation {
                showError = true
            }
            adminCode = ""

            // Shake animation
            withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                shakeOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    shakeOffset = -10
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    shakeOffset = 0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showError = false
                }
            }
        }
    }

    // MARK: - Approval List

    private var approvalList: some View {
        Group {
            if store.pendingLogs.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.accentGradient)
                            .blur(radius: 15)
                            .opacity(0.5)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(AppTheme.accentGradient)
                    }

                    Text("All Caught Up!")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    Text("No chores waiting for approval")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.pendingLogs) { log in
                            PendingLogCard(log: log)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Pending Log Card

struct PendingLogCard: View {
    let log: ChoreLog
    @EnvironmentObject var store: ChoreStore

    private var player: Player? {
        store.players.first { $0.id == log.playerId }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Chore icon
            Text(log.choreIcon)
                .font(.system(size: 40))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(log.choreName)
                    .font(.headline)
                    .foregroundColor(.white)

                if let player = player {
                    HStack(spacing: 6) {
                        Text(player.avatar)
                        Text(player.name)
                            .foregroundStyle(player.theme.gradient)
                    }
                    .font(.subheadline)
                }

                Text(log.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Points
            Text("+\(log.points)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accentGradient)

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.reject(log)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.2), in: Circle())
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        store.approve(log)
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.accent.opacity(0.2), in: Circle())
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.backgroundCard)
        }
    }
}

#Preview {
    AdminView()
        .environmentObject(ChoreStore())
}
