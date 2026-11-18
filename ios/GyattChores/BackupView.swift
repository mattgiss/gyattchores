import SwiftUI
import UniformTypeIdentifiers
import GyattCore

/// "save a backup…" and "restore from a backup…": a backup is a file the family keeps (Files,
/// iCloud Drive, AirDrop…) and can restore on a new phone, or bring into the family build later.
struct BackupControls: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    /// Setup's first screen offers restoring only: there's nothing to save yet.
    var canSave = true

    @State private var exporting = false
    @State private var document: BackupDocument?
    @State private var importing = false
    /// A backup read from the picked file, shown once the file picker has closed.
    @State private var loaded: Backup?
    @State private var prompt: Prompt?

    /// One alert at a time: asking before a restore, or saying how something went.
    private enum Prompt: Identifiable {
        case confirm(Backup), message(String)
        var id: String { switch self { case .confirm(let b): "c" + b.id; case .message(let m): "m" + m } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if canSave {
                OutlineButton(label: "Save a backup…") {
                    fb.tap()
                    do { document = BackupDocument(data: try store.makeBackup().data()); exporting = true }
                    catch { prompt = .message("Couldn't make the backup: \(error.localizedDescription)") }
                }
                .accessibilityIdentifier("save-backup")
            }
            OutlineButton(label: "Restore from a backup…") { fb.tap(); importing = true }
                .accessibilityIdentifier("restore-backup")
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: Backup.fileName(calendar: store.calendar)) { result in
            switch result {
            case .success: fb.approve(); prompt = .message("Backup saved. Keep it somewhere safe, like Files or iCloud Drive.")
            case .failure(let e): if (e as NSError).code != NSUserCancelledError { prompt = .message("The backup wasn't saved: \(e.localizedDescription)") }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do { loaded = try Backup.read(Data(contentsOf: url)) }
            catch let e as Backup.ReadError { fb.error(); prompt = .message(e.message) }
            catch { fb.error(); prompt = .message("Couldn't open that file: \(error.localizedDescription)") }
        }
        // Asking while the file picker is still closing can lose the question, so wait for it to go.
        .onChange(of: importing) { _, open in
            guard !open, let b = loaded else { return }
            loaded = nil
            Task { try? await Task.sleep(for: .milliseconds(400)); prompt = .confirm(b) }
        }
        .alert(item: $prompt) { p in
            switch p {
            case .confirm(let b):
                Alert(title: Text("Restore this backup?"), message: Text(store.restorePreview(b)),
                      primaryButton: store.isLinked ? .default(Text("Add it to the family")) { restore(b) } : .destructive(Text("Replace everything here")) { restore(b) },
                      secondaryButton: .cancel())
            case .message(let m):
                Alert(title: Text("Backup"), message: Text(m), dismissButton: .cancel(Text("OK")))
            }
        }
    }

    private func restore(_ b: Backup) {
        // From setup, the restore replaces the screen this view is on, so the app shows the
        // result; from the admin area this view stays and shows it.
        let fromSetup = !store.isSetUp
        let result = store.restore(b)
        fb.approve()
        if fromSetup { store.notice = result }
        else { Task { try? await Task.sleep(for: .milliseconds(400)); prompt = .message(result) } }
    }
}

/// The backup as a file for the system's save panel.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
