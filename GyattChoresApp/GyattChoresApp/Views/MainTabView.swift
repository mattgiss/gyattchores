import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            ChoresListView()
                .tabItem {
                    Label("Chores", systemImage: "checklist")
                }
                .tag(1)

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)

            if authManager.isAdmin {
                AdminView()
                    .tabItem {
                        Label("Admin", systemImage: "gear")
                    }
                    .tag(4)
            }
        }
        .tint(.cyan)
        .task {
            await dataManager.loadAll()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(DataManager())
}
