import SwiftUI
import GyattCore

/// Write or say what needs doing around the house; get back a list to tick, rename and re-time
/// before any of it is added. The sorting happens on the device (`ChoreIntake`).
///
/// Speaking uses the microphone key on the keyboard: the phone's own dictation, which needs no
/// permission from this app and no code here that listens.
struct ChoreIntakeView: View {
    /// Chores already on the list, so they aren't offered again.
    let existing: [Chore]
    let onDone: ([Chore]) -> Void

    @EnvironmentObject var fb: Feedback
    @State private var text = ""
    @State private var found: [Found]?
    @FocusState private var writing: Bool

    struct Found: Identifiable {
        let id: String
        var name: String
        var minutes: Int
        var on = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let found { review(found) } else { write }
        }
    }

    // MARK: Writing

    @ViewBuilder private var write: some View {
        Text("list the chores in your home, in your own words. type them, or tap the mic on the keyboard and say them.")
            .font(.callout).foregroundStyle(.secondary)
        TextEditor(text: $text)
            .focused($writing)
            .frame(height: 140)
            .padding(6)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(.separator)))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("dishes, take out the trash, feed the dog 5 minutes…")
                        .foregroundStyle(.tertiary).padding(.horizontal, 11).padding(.vertical, 14).allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier("chore-text")
        TermButton(label: "SORT INTO CHORES", enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            fb.fill()
            writing = false
            found = ChoreIntake.parse(text, existing: existing).map { Found(id: $0.id, name: $0.name, minutes: $0.tiers[0]) }
        }
        Text("sorted on this device. nothing you write or say here is sent anywhere by this app.")
            .font(.caption2).foregroundStyle(.secondary)
    }

    // MARK: Reviewing

    @ViewBuilder private func review(_ items: [Found]) -> some View {
        let chosen = items.filter { $0.on && ChoreIntake.tidyName($0.name) != nil }
        if items.isEmpty {
            Text("couldn't find any new chores in that. try one per line, or separate them with commas.")
                .foregroundStyle(Theme.warn)
        } else {
            Text("found \(items.count). untick any you don't want; fix names and minutes as you like.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Button { fb.tick(!items[i].on); found?[i].on.toggle() } label: {
                        Text(items[i].on ? "[+]" : "[ ]").foregroundStyle(items[i].on ? Theme.accent : .secondary)
                            .frame(minWidth: 36, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(items[i].on ? "leave out \(items[i].name)" : "include \(items[i].name)")
                    TextField("chore", text: Binding(get: { found?[i].name ?? "" }, set: { found?[i].name = $0 }))
                        .textInputAutocapitalization(.never)
                        .opacity(items[i].on ? 1 : 0.4)
                    Stepper("\(items[i].minutes)m", value: Binding(get: { found?[i].minutes ?? 5 }, set: { found?[i].minutes = $0 }),
                            in: ChoreIntake.minuteRange)
                        .fixedSize()
                        .opacity(items[i].on ? 1 : 0.4)
                }
                Divider()
            }
        }
        TermButton(label: chosen.isEmpty ? "NOTHING TO ADD" : "ADD \(chosen.count) CHORE\(chosen.count == 1 ? "" : "S")", enabled: !chosen.isEmpty) {
            var ids = Set(existing.map(\.id))
            let chores = chosen.map { item -> Chore in
                let chore = ChoreIntake.make(name: item.name, minutes: item.minutes, takenIds: ids)
                ids.insert(chore.id)
                return chore
            }
            onDone(chores)
        }
        OutlineButton(label: "← write some more") { fb.tap(); found = nil }
    }
}
