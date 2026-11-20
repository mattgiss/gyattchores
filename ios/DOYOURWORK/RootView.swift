import SwiftUI
import DoYourWorkCore

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
    @Environment(\.scenePhase) private var scenePhase

    // What's open lives here, above both layouts, so rotating an iPad or resizing its window
    // lands on the same screen.
    @State private var selectedId: String?
    @State private var adminOpen = false
    @State private var daresOpen = false

    private var selected: Player? { store.players.first { $0.id == selectedId } }

    var body: some View {
        layout
            // Sync on open and every 10 seconds while the app is on screen, as on Android.
            .task { while !Task.isCancelled { store.requestSync(); try? await Task.sleep(for: .seconds(10)) } }
            // The two daily notifications: asked about once the family is set up, and rescheduled
            // whenever the app opens or leaves the screen (a new day, a new player, a new phone owner).
            .onChange(of: scenePhase, initial: true) { _, _ in remind() }
            .onChange(of: store.isSetUp) { _, _ in remind() }
            .onChange(of: store.me) { _, _ in remind() }
    }

    @ViewBuilder private var layout: some View {
        // A phone that just joined a family: until its lists have loaded once, no players doesn't
        // mean a new family.
        if store.isLinked && !store.hasSynced && !store.isSetUp { FamilyLoadingView() }
        else if !store.isSetUp { SetupView().onAppear(perform: reset) }
        else if sizeClass == .regular { twoPane } else { onePane }
    }

    private func remind() {
        if store.isSetUp && scenePhase == .active { ReminderScheduler.shared.askPermission(store) }
        ReminderScheduler.shared.reschedule(store, force: true)
    }

    /// The scoreboard was erased and set up again: don't reopen whatever was open before.
    private func reset() {
        adminOpen = false; selectedId = nil
        daresOpen = false
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
            AdminView().environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent)
        }
        .sheet(isPresented: $daresOpen) { DaresView().appChrome(store, fb) }
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

    private var daresIsOpen: Bool {
        daresOpen && store.me != nil && store.isLinked
    }

    @ViewBuilder private var detail: some View {
        if adminOpen {
            AdminView(onBack: { adminOpen = false })
        } else if daresIsOpen {
            DaresView(onBack: { daresOpen = false })
        } else if let selected {
            // A fresh screen per player, so one kid's half-picked card doesn't carry over to the next.
            PlayerView(player: selected, showsBack: false).id(selected.id)
        } else {
            Text(store.players.isEmpty ? "> add players in the admin area" : "> pick a player").foregroundStyle(.secondary)
        }
    }
}

/// A phone that just joined a family: waiting for the family's players to load.
private struct FamilyLoadingView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 16) {
            Text("DOYOURWORK").font(.app(fixedSize: 34, weight: .black)).lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(Palette.heat.stops[0])
            if store.syncStatus == "offline" {
                Text("Can't reach the family's scoreboard. Check the connection and try again.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Try again") { store.requestSync() }.buttonStyle(.bordered)
            } else {
                ProgressView()
                Text("Loading the family…").foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}
