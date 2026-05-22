import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ChoreStore
    @State private var showAdmin = false

    var body: some View {
        NavigationStack {
            HomeView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAdmin = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)

                                if store.pendingLogs.count > 0 {
                                    Text("\(store.pendingLogs.count)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Circle().fill(.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAdmin) {
                    AdminView()
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ChoreStore())
}
