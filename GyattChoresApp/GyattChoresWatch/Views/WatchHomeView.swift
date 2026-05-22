import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var store: WatchChoreStore

    var body: some View {
        NavigationStack {
            if let player = store.selectedPlayer {
                // Chore list for selected player
                ChoreListView(player: player)
            } else {
                // Player selection
                PlayerSelectionView()
            }
        }
    }
}

// MARK: - Player Selection

struct PlayerSelectionView: View {
    @EnvironmentObject var store: WatchChoreStore

    var body: some View {
        List {
            ForEach(store.players) { player in
                Button {
                    store.selectedPlayer = player
                } label: {
                    HStack {
                        Text(player.avatar)
                            .font(.title2)

                        Text(player.name)
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("Who?")
    }
}

// MARK: - Chore List

struct ChoreListView: View {
    @EnvironmentObject var store: WatchChoreStore
    let player: WatchPlayer
    @State private var showSuccess = false
    @State private var lastChore: WatchChore?

    var body: some View {
        List {
            // Quick back button
            Button {
                store.selectedPlayer = nil
            } label: {
                HStack {
                    Text(player.avatar)
                    Text(player.name)
                        .font(.caption)
                }
            }
            .listItemTint(.cyan)

            // Chores
            ForEach(store.chores) { chore in
                Button {
                    logChore(chore)
                } label: {
                    HStack {
                        Text(chore.icon)
                            .font(.title3)

                        VStack(alignment: .leading) {
                            Text(chore.name)
                                .font(.headline)
                            Text("\(chore.points) pts")
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }
        .navigationTitle("Chores")
        .overlay {
            if showSuccess, let chore = lastChore {
                SuccessOverlay(chore: chore)
            }
        }
    }

    private func logChore(_ chore: WatchChore) {
        store.logChore(chore, for: player)
        lastChore = chore
        showSuccess = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSuccess = false
        }
    }
}

// MARK: - Success Overlay

struct SuccessOverlay: View {
    let chore: WatchChore

    var body: some View {
        VStack(spacing: 8) {
            Text(chore.icon)
                .font(.largeTitle)

            Text("Done!")
                .font(.headline)

            Text("+\(chore.points)")
                .font(.caption)
                .foregroundStyle(.cyan)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    WatchHomeView()
        .environmentObject(WatchChoreStore())
}
