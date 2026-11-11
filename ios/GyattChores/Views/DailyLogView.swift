import GyattCore
import SwiftUI

/// Who cleared 25 minutes of approved chores each day, over the last 30 days.
struct DailyLogView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("25-MINUTE DAILY LOG")
                    .font(.mono(.caption2))
                    .tracking(4)
                    .foregroundStyle(.secondary)
                Text("last \(Engine.logDays) days · a filled square = \(Engine.dailyMinutes)+ min approved")
                    .font(.mono(.caption2))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            if store.hasApprovedLogs {
                ForEach(store.players) { player in
                    DailyLogRowView(name: player.name, row: store.dailyLog(for: player))
                }
            } else {
                Text("no approved chores yet —\nclear a \(Engine.dailyMinutes)-minute card to start the grid")
                    .font(.mono(.caption))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DailyLogRowView: View {
    let name: String
    let row: DailyLogRow

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.mono(.footnote, weight: .bold))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Text("\(row.hits)/\(row.days.count) · \(row.pct)%")
                    .font(.mono(.caption, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 2) {
                ForEach(Array(row.days.enumerated()), id: \.element.id) { index, day in
                    DayCell(day: day, isToday: index == row.days.count - 1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(row.hits) of the last \(row.days.count) days at \(Engine.dailyMinutes) minutes or more")
    }
}

/// Solid for a day that hit the goal, faded for a partial day, grey for a day off.
private struct DayCell: View {
    let day: DayMinutes
    let isToday: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(day.isHit ? Theme.accent : Color.secondary, lineWidth: 1)
                }
            }
    }

    private var fill: Color {
        day.minutes == 0 ? Theme.emptyCell : Theme.accent.opacity(0.30 + day.fraction * 0.70)
    }
}
