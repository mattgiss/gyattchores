import SwiftUI

struct ChoresListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedChore: Chore?

    var filteredChores: [Chore] {
        if searchText.isEmpty {
            return dataManager.chores
        }
        return dataManager.chores.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredChores) { chore in
                    ChoreRow(chore: chore)
                        .onTapGesture {
                            selectedChore = chore
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("All Chores")
            .searchable(text: $searchText, prompt: "Search chores")
            .sheet(item: $selectedChore) { chore in
                ChoreDetailSheet(chore: chore)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct ChoreRow: View {
    let chore: Chore

    var body: some View {
        HStack(spacing: 16) {
            Text(chore.icon)
                .font(.system(size: 32))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(chore.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Label("\(chore.baseValue)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.cyan)

                    if chore.cooldownHours != 24 {
                        Label("\(chore.cooldownHours)h", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if chore.singleClaim {
                        Label("Single", systemImage: "person")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            Text(String(format: "$%.2f", chore.dollarValue))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ChoreDetailSheet: View {
    let chore: Chore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and name
                    VStack(spacing: 12) {
                        Text(chore.icon)
                            .font(.system(size: 80))

                        Text(chore.name)
                            .font(.title2.bold())
                    }
                    .padding(.top)

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Points", value: "\(chore.baseValue)", icon: "star.fill", color: .cyan)
                        StatCard(title: "Value", value: String(format: "$%.2f", chore.dollarValue), icon: "dollarsign.circle.fill", color: .green)
                        StatCard(title: "Cooldown", value: "\(chore.cooldownHours)h", icon: "clock.fill", color: .orange)
                        StatCard(title: "Type", value: chore.singleClaim ? "Single" : "Multi", icon: "person.fill", color: .purple)
                    }
                    .padding(.horizontal)

                    // Description
                    if let description = chore.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Definition of Done")
                                .font(.headline)

                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    ChoresListView()
        .environmentObject(DataManager())
}
