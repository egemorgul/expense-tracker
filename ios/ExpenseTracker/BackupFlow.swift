import SwiftData
import SwiftUI

/// Backing up to Files and restoring from a backup, shared by Home's toolbar menu and its reminder.
/// A view shows it with `backupFlow`, because a menu item's own view is gone before a panel opens.
@Observable
final class BackupFlow {
    var isExporting = false
    private(set) var document: BackupDocument?
    var isImporting = false
    /// Read and waiting for the user to confirm replacing everything with it.
    var pendingRestore: Backup?
    var alertTitle = ""
    var alertMessage: String?

    func backUp(from context: ModelContext) {
        do {
            document = try BackupDocument(Backup(context: context))
            isExporting = true
        } catch {
            show("Couldn't save the backup", error)
        }
    }

    func exportFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            BackupReminder.recordBackup()
        case .failure(let error):
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            show("Couldn't save the backup", error)
        }
    }

    func importFinished(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // Files outside the app's own folders can only be read while access is granted.
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
            pendingRestore = try Backup(json: Data(contentsOf: url))
        } catch {
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            show("Couldn't read that backup", error is DecodingError ? Backup.NotABackup() : error)
        }
    }

    /// Saves what's there now to the app's folder in Files first, so a restore can always be undone.
    func restore(_ backup: Backup, into context: ModelContext) {
        do {
            let current = try Backup(context: context)
            let folder = URL.documentsDirectory
            let time = current.exportedAt.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
                .replacingOccurrences(of: ":", with: ".")
            try current.json().write(to: folder.appending(path: "Before restore \(time).json"), options: .atomic)

            try backup.restore(into: context)
            alertTitle = "Backup restored"
            alertMessage = "What you had before is saved in Files › On My iPhone › Expenses."
        } catch {
            show("Couldn't restore the backup", error)
        }
    }

    private func show(_ title: String, _ error: Error) {
        alertTitle = title
        alertMessage = error.localizedDescription
    }
}

extension Backup {
    struct NotABackup: LocalizedError {
        var errorDescription: String? { "That file isn't a backup from this app." }
    }
}

extension View {
    func backupFlow(_ flow: BackupFlow) -> some View {
        modifier(BackupFlowPresenter(flow: flow))
    }
}

private struct BackupFlowPresenter: ViewModifier {
    @Bindable var flow: BackupFlow
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $flow.isExporting,
                document: flow.document,
                contentType: .json,
                defaultFilename: flow.document?.fileName,
                onCompletion: flow.exportFinished
            )
            // A second file panel on the same view doesn't open, so the importer sits on its own view.
            .background {
                Color.clear
                    .fileImporter(isPresented: $flow.isImporting, allowedContentTypes: [.json], onCompletion: flow.importFinished)
            }
            .confirmationDialog(
                "Replace all your data with this backup?",
                isPresented: Binding(
                    get: { flow.pendingRestore != nil },
                    set: { if !$0 { flow.pendingRestore = nil } }
                ),
                titleVisibility: .visible,
                presenting: flow.pendingRestore
            ) { backup in
                Button("Replace everything", role: .destructive) {
                    flow.restore(backup, into: modelContext)
                }
            } message: { backup in
                Text("\(backup.summary) What you have now is saved to Files first.")
            }
            .errorAlert(flow.alertTitle, message: $flow.alertMessage)
    }
}

/// Home's nudge once a week has gone by without a backup, since the phone holds the only copy.
struct BackupReminderCard: View {
    let lastBackup: Date?
    let backUp: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(systemName: "externaldrive.badge.exclamationmark", color: .ink)
            VStack(alignment: .leading, spacing: 2) {
                Text("Back up your data")
                    .font(.subheadline.weight(.semibold))
                Text(lastBackup.map { "Last backup \($0.formatted(.relative(presentation: .named)))" } ?? "Not backed up yet")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Button("Back up now", action: backUp)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brand)
                .buttonStyle(PressableButtonStyle())
                .frame(minHeight: 44)
        }
        .padding(.vertical, 4)
    }
}
