import SwiftUI
import GyattCore

/// Decides how the app is laid out.
///
/// - Narrow (an iPhone, or an iPad app squeezed into a slim window): one screen at a time. Picking
///   a player pushes their day; dares and the parent area cover the screen.
/// - Wide (an iPad): two panes, like the Android app on a foldable's inner screen. The home list
///   stays on the left and the player's day, the dares or the parent area opens on the right.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.horizontalSizeClass) private var sizeClass

    // What's open lives here, above both layouts, so rotating an iPad or resizing its window
    // lands on the same screen.
    @State private var selectedId: String?
    @State private var adminOpen = false
    @State private var daresOpen = false

    private var selected: Player? { store.players.first { $0.id == selectedId } }

    var body: some View {
        if sizeClass == .regular { twoPane } else { onePane }
    }

    private func home(highlighting id: String?) -> HomeView {
        HomeView(
            selectedId: id,
            onPick: { adminOpen = false; daresOpen = false; selectedId = $0.id },
            onAdmin: { daresOpen = false; adminOpen = true },
            onDares: { adminOpen = false; daresOpen = true }
        )
    }

    // MARK: One screen at a time

    private var onePane: some View {
        NavigationStack(path: Binding(
            get: { selected.map { [$0] } ?? [] },
            set: { selectedId = $0.last?.id }
        )) {
            home(highlighting: nil)
                .navigationDestination(for: Player.self) { PlayerView(player: $0) }
                .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $daresOpen) {
            DaresView().environmentObject(store).environmentObject(fb).fontDesign(.monospaced).tint(Theme.accent)
        }
        .fullScreenCover(isPresented: $adminOpen) {
            AdminView().environmentObject(store).environmentObject(fb).fontDesign(.monospaced).tint(Theme.accent)
        }
    }

    // MARK: Two panes

    private var twoPane: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Roughly a third of the width, as on Android, kept between limits so the list is
                // neither cramped on an upright iPad nor sprawling on a big one turned sideways.
                home(highlighting: adminOpen || daresOpen ? nil : selectedId)
                    .frame(width: min(max(geo.size.width * 0.36, 320), 420))
                Divider()
                detail
                    // Rows stretched across a 13-inch screen are hard to read; keep them column-width.
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if adminOpen {
            AdminView(onBack: { adminOpen = false })
        } else if daresOpen {
            DaresView(onBack: { daresOpen = false })
        } else if let selected {
            // A fresh screen per player, so one kid's half-picked card doesn't carry over to the next.
            PlayerView(player: selected, showsBack: false).id(selected.id)
        } else {
            Text("> pick a player").foregroundStyle(.secondary)
        }
    }
}
