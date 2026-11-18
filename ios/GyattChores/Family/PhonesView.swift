#if FAMILY_SYNC
import SwiftUI
import CoreImage.CIFilterBuiltins
import VisionKit
import GyattCore

/// Admin → Device → phones: adding a phone with a QR code, joining with one, and the family's
/// phones once sync goes through the encrypted relay (docs/design/encrypted-relay-join.md).
struct PhonesSection: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var adding = false
    @State private var confirmingJoin = false
    @State private var joining = false
    @State private var phones: (mine: String, all: [RelayDevice])?
    @State private var removing: RelayDevice?
    @State private var problem: String?
    @State private var confirmingDelete = false

    var body: some View {
        SectionLabel("phones")
        if store.isLinked {
            Text("Encrypted sync. Only this family's phones can read what's sent.")
                .font(.app(.callout)).foregroundStyle(.secondary)
            if let phones {
                ForEach(phones.all, id: \.userId) { p in
                    HStack {
                        Text((p.userId == phones.mine ? "This phone" : "Phone") + " · joined " + p.joinedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.app(.callout))
                        Spacer()
                        if p.userId != phones.mine { Button("Remove") { removing = p }.buttonStyle(.bordered) }
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
            }
        } else if store.syncOff {
            Text("Sync is off. The family is only on this phone.").font(.app(.callout)).foregroundStyle(.secondary)
        } else {
            Text("This phone syncs through the family's old tables. Add a phone moves the family to encrypted sync: everything is encrypted on this phone before it's sent, and only phones that scan the code can read it.")
                .font(.app(.callout)).foregroundStyle(.secondary)
        }
        if let problem { Text(problem).font(.app(.footnote)).foregroundStyle(Theme.bad) }
        OutlineButton(label: "Add a phone") { fb.tap(); problem = nil; adding = true }.padding(.horizontal, -20)
        if !store.isLinked {
            OutlineButton(label: "Join with a code") { fb.tap(); confirmingJoin = true }.padding(.horizontal, -20)
        } else {
            Button("Delete this family from the server…", role: .destructive) { confirmingDelete = true }
                .buttonStyle(.bordered).padding(.vertical, 12)
        }
        Color.clear.frame(height: 0)
            .task(id: store.isLinked) { await loadPhones() }
            .sheet(isPresented: $adding, onDismiss: { Task { await loadPhones() } }) { AddPhoneSheet().appChrome(store, fb) }
            .sheet(isPresented: $joining) { JoinSheet().appChrome(store, fb) }
            .confirmationDialog("Join this family?", isPresented: $confirmingJoin, titleVisibility: .visible) {
                Button("Scan the code") { joining = true }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This phone will load the family from the phone that showed the code. Changes here that haven't synced yet are lost.") }
            .confirmationDialog("Delete the family from the server?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete from the server", role: .destructive) {
                    Task {
                        problem = nil
                        do { try await store.deleteFromServer(); fb.reject() } catch { problem = JoinOutcome.offline.message; fb.error() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Every phone stops syncing, and everything sent is deleted from the server. The family stays on this phone. This can't be undone.") }
            .confirmationDialog("Remove this phone?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    guard let p = removing else { return }
                    Task {
                        do { try await store.removePhone(p.userId); fb.reject() } catch { problem = JoinOutcome.offline.message }
                        await loadPhones()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("It stops getting updates. What it already has stays on it.") }
    }

    private func loadPhones() async {
        guard store.isLinked else { phones = nil; return }
        phones = try? await store.phones()
    }
}

/// The first phone's side: a QR code for the other phone to scan, good for 10 minutes.
private struct AddPhoneSheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    @State private var code: (code: JoinCode, expires: Date)?
    @State private var failed = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add a phone").font(.app(fixedSize: 24, weight: .black))
            Text("Scan this with the other phone's camera, inside DOYOURWORK.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            if let code {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let left = Int(code.expires.timeIntervalSince(ctx.date).rounded(.up))
                    VStack(spacing: 12) {
                        if left > 0 {
                            QRCode(text: code.code.text)
                            Text(String(format: "Expires in %d:%02d", left / 60, left % 60)).monospacedDigit().foregroundStyle(.secondary)
                        } else {
                            Text("This code expired.").foregroundStyle(Theme.warn).frame(height: 240)
                            Button("New code") { Task { await make() } }.buttonStyle(.bordered)
                        }
                    }
                }
            } else if failed {
                Text(JoinOutcome.offline.message ?? "").foregroundStyle(Theme.bad).multilineTextAlignment(.center)
                Button("Try again") { Task { await make() } }.buttonStyle(.bordered)
            } else {
                ProgressView().frame(height: 240)
                Text(store.isLinked ? "Making a code…" : "Encrypting the family and sending it…").foregroundStyle(.secondary)
            }
            Spacer()
            TermButton(label: "Done") { fb.tap(); dismiss() }
        }
        .padding(24)
        .task { await make() }
    }

    private func make() async {
        failed = false; code = nil
        do { code = try await store.addPhone() } catch { failed = true }
    }
}

/// The joining phone's side: the camera, then the family loads.
struct JoinSheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    @State private var problem: String?
    @State private var working = false
    /// A fresh scanner after a code that didn't work, so the next one can be read.
    @State private var attempt = 0
    private var canScan: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        VStack(spacing: 16) {
            Text("Join a family").font(.app(fixedSize: 24, weight: .black))
            Text("Point the camera at the QR code on the other phone.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            if working { ProgressView().frame(maxHeight: .infinity) }
            else if let preset = Self.presetScan, attempt == 0 {
                // UI tests: no camera in the simulator; the code arrives as if it had been read.
                Color.clear.task { await handle(await Self.resolve(preset, store)) }
            } else if canScan {
                CodeScanner { text in Task { await handle(text) } }
                    .id(attempt)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("This phone's camera can't scan codes here. Check that DOYOURWORK may use the camera in Settings.")
                    .foregroundStyle(Theme.warn).multilineTextAlignment(.center).frame(maxHeight: .infinity)
            }
            if let problem { Text(problem).foregroundStyle(Theme.bad).multilineTextAlignment(.center) }
            OutlineButton(label: "Cancel") { fb.tap(); dismiss() }
        }
        .padding(24)
    }

    private func handle(_ text: String) async {
        guard !working else { return }
        working = true
        let outcome = await store.joinFamily(scanned: text)
        working = false
        if let message = outcome.message { problem = message; attempt += 1; fb.error() } else { fb.approve(); dismiss() }
    }

    private static func resolve(_ preset: String, _ store: AppStore) async -> String {
        #if DEBUG
        if preset == "seeded" { return await store.seededJoinCode() }
        #endif
        return preset
    }

    /// Debug builds under -uiTesting only: `-scanResult <text>`, or `seeded` for a code from a
    /// family made in the in-memory relay.
    private static var presetScan: String? {
        #if DEBUG
        let args = AppStore.launchArguments
        guard AppStore.uiTesting, let i = args.firstIndex(of: "-scanResult"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }
}

/// A join code drawn as a QR code: black on white with a quiet border, so any camera reads it.
private struct QRCode: View {
    let text: String

    var body: some View {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        let image = filter.outputImage.flatMap { CIContext().createCGImage($0, from: $0.extent) }
        return Group {
            if let image { Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFit() }
        }
        .padding(16).background(Color.white)
        .frame(width: 240, height: 240)
        .accessibilityElement().accessibilityIdentifier("joinQR").accessibilityLabel("Join code")
    }
}

/// VisionKit's live scanner, looking only for QR codes. The first one read is handed back.
private struct CodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let b) in items {
                guard !done, let text = b.payloadStringValue else { continue }
                done = true
                scanner.stopScanning()
                onCode(text)
            }
        }
    }
}
#endif
