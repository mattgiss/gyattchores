import SwiftUI
import GyattCore

/// Decides how the app is laid out.
///
/// - Narrow (an iPhone, or an iPad app squeezed into a slim window): one screen at a time. Picking
///   a player pushes their day; the admin area covers the screen.
/// - Wide (an iPad): two panes, like the Android app on a foldable's inner screen. The home list
///   stays on the left and the player's day or the admin area opens on the right.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.horizontalSizeClass) private var sizeClass

    // What's open lives here, above both layouts, so rotating an iPad or resizing its window
    // lands on the same screen.
    @State private var selectedId: String?
    @State private var adminOpen = false

    private var selected: Player? { store.players.first { $0.id == selectedId } }

    var body: some View {
        if !store.isSetUp { SetupView().onAppear(perform: reset) }
        else if sizeClass == .regular { twoPane } else { onePane }
    }

    /// The scoreboard was erased and set up again: don't reopen whatever was open before.
    private func reset() { adminOpen = false; selectedId = nil }

    private func home(highlighting id: String?) -> HomeView {
        HomeView(
            selectedId: id,
            onPick: { adminOpen = false; selectedId = $0.id },
            onAdmin: { adminOpen = true }
        )
    }

    // MARK: One screen at a time

    private var onePane: some View {
        // The path holds the player's id, not the player: a new display name then redraws the
        // screen that's open instead of counting as somewhere new to go.
        NavigationStack(path: Binding(
            get: { selected.map { [$0.id] } ?? [] },
            set: { selectedId = $0.last }
        )) {
            home(highlighting: nil)
                .navigationDestination(for: String.self) { id in
                    if let player = store.players.first(where: { $0.id == id }) { PlayerView(player: player) }
                }
                .toolbar(.hidden, for: .navigationBar)
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
                home(highlighting: adminOpen ? nil : selectedId)
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
        } else if let selected {
            // A fresh screen per player, so one kid's half-picked card doesn't carry over to the next.
            PlayerView(player: selected, showsBack: false).id(selected.id)
        } else {
            Text(store.players.isEmpty ? "> add players in the admin area" : "> pick a player").foregroundStyle(.secondary)
        }
    }
}
