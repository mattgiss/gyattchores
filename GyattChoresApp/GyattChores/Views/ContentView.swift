import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ChoreStore
    @State private var showAdmin = false
    @State private var badgeBounce = false

    var body: some View {
        NavigationStack {
            HomeView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticManager.shared.tabSwitch()
                            showAdmin = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))

                                if store.pendingLogs.count > 0 {
                                    Text("\(store.pendingLogs.count)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(hex: "ff6b6b"), Color(hex: "ee5a24")],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        .offset(x: 10, y: -8)
                                        .scaleEffect(badgeBounce ? 1.3 : 1.0)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAdmin) {
                    AdminView()
                }
                .onChange(of: store.pendingLogs.count) { oldValue, newValue in
                    if newValue > oldValue {
                        // New pending log - bounce the badge
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            badgeBounce = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                badgeBounce = false
                            }
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(ChoreStore())
}
