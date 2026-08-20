import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: ChoreStore
    @State private var showSuccess = false
    @State private var lastLoggedChore: Chore?
    @State private var animatePoints = false
    @State private var streakCount = 0

    private var selectedTheme: PlayerTheme? {
        store.selectedPlayer?.theme
    }

    var body: some View {
        ZStack {
            // Dark background
            AppTheme.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Player Cards - Horizontal scroll
                playerSelector
                    .padding(.top, 8)

                // Chore Grid
                ScrollView(showsIndicators: false) {
                    choreGrid
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                }
            }

            // Success Overlay
            if showSuccess, let chore = lastLoggedChore {
                successOverlay(chore: chore)
            }
        }
        .navigationTitle("GyattChores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.backgroundDark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Player Selector

    private var playerSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.players) { player in
                    PlayerCard(
                        player: player,
                        isSelected: store.selectedPlayer?.id == player.id,
                        isLeader: store.leader?.id == player.id,
                        weeklyPoints: store.weeklyPoints(for: player),
                        todayPoints: store.todayPoints(for: player)
                    ) {
                        HapticManager.shared.playerSelected()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            store.selectedPlayer = player
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Chore Grid

    private var choreGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(store.chores) { chore in
                ChoreCard(
                    chore: chore,
                    playerTheme: selectedTheme,
                    isEnabled: store.selectedPlayer != nil
                ) {
                    logChore(chore)
                }
            }
        }
    }

    // MARK: - Log Chore

    private func logChore(_ chore: Chore) {
        guard let player = store.selectedPlayer else { return }

        store.logChore(chore, for: player)
        lastLoggedChore = chore
        streakCount += 1

        HapticManager.shared.choreLogged(points: chore.points)

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showSuccess = true
            animatePoints = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSuccess = false
                animatePoints = false
            }
        }
    }

    // MARK: - Success Overlay

    private func successOverlay(chore: Chore) -> some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showSuccess = false }
                }

            // Success Card
            VStack(spacing: 0) {
                // Glowing emoji
                ZStack {
                    // Glow effect
                    Text(chore.icon)
                        .font(.system(size: 80))
                        .blur(radius: 20)
                        .opacity(0.6)

                    Text(chore.icon)
                        .font(.system(size: 70))
                }
                .scaleEffect(animatePoints ? 1.1 : 0.8)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: animatePoints)

                // Points
                HStack(spacing: 4) {
                    Text("+")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(chore.points)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(AppTheme.accentGradient)
                .padding(.top, 8)

                // Player attribution
                if let player = store.selectedPlayer {
                    HStack(spacing: 6) {
                        Text(player.avatar)
                            .font(.title3)
                        Text(player.name)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 12)
                }

                // Streak indicator
                if streakCount > 1 {
                    Text("🔥 \(streakCount) streak!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.top, 8)
                }
            }
            .padding(32)
            .background {
                RoundedRectangle(cornerRadius: 32)
                    .fill(AppTheme.backgroundCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [selectedTheme?.primary ?? .white, selectedTheme?.secondary ?? .gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
            }
            .scaleEffect(animatePoints ? 1 : 0.9)
            .opacity(animatePoints ? 1 : 0)
        }
    }
}

// MARK: - Player Card

struct PlayerCard: View {
    let player: Player
    let isSelected: Bool
    let isLeader: Bool
    let weeklyPoints: Int
    let todayPoints: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Avatar with crown
                ZStack(alignment: .topTrailing) {
                    // Glowing avatar background when selected
                    if isSelected {
                        Circle()
                            .fill(player.theme.gradient)
                            .frame(width: 56, height: 56)
                            .blur(radius: 12)
                            .opacity(0.6)
                    }

                    Text(player.avatar)
                        .font(.system(size: 44))

                    if isLeader && weeklyPoints > 0 {
                        Text("👑")
                            .font(.system(size: 18))
                            .offset(x: 8, y: -4)
                    }
                }

                // Full name - no truncation
                Text(player.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .fixedSize(horizontal: true, vertical: false)

                // Points display
                VStack(spacing: 2) {
                    Text("\(weeklyPoints)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? player.theme.gradient : LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.3)], startPoint: .leading, endPoint: .trailing))

                    Text("this week")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Today's points pill
                if todayPoints > 0 {
                    Text("+\(todayPoints) today")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.2), in: Capsule())
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(minWidth: 110)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AppTheme.backgroundCardLight : AppTheme.backgroundCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? player.theme.gradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                                lineWidth: isSelected ? 2 : 0
                            )
                    }
                    .shadow(color: isSelected ? player.theme.primary.opacity(0.4) : .clear, radius: 12, y: 4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1)
        .animation(.spring(response: 0.35), value: isSelected)
    }
}

// MARK: - Chore Card

struct ChoreCard: View {
    let chore: Chore
    let playerTheme: PlayerTheme?
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Emoji with tier glow
                ZStack {
                    if isEnabled {
                        Text(chore.icon)
                            .font(.system(size: 32))
                            .blur(radius: 8)
                            .opacity(0.4)
                    }
                    Text(chore.icon)
                        .font(.system(size: 28))
                }

                // Chore name
                Text(chore.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 26)

                // Points with tier color
                Text("\(chore.points)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(
                        isEnabled
                            ? (playerTheme?.gradient ?? LinearGradient(colors: [chore.tier.color], startPoint: .leading, endPoint: .trailing))
                            : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.backgroundCard)
                    .overlay {
                        // Subtle tier accent at bottom
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, chore.tier.color.opacity(isEnabled ? 0.15 : 0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 40)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(isPressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed && isEnabled {
                        isPressed = true
                        HapticManager.shared.chorePressed()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .animation(.easeOut(duration: 0.15), value: isPressed)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(ChoreStore())
    }
}
