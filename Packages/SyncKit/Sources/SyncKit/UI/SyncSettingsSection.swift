import SwiftUI

/// Drop-in Settings section: iCloud toggle, live status, last-synced, Sync Now.
/// Embed inside a Form or List.
public struct SyncSettingsSection: View {
    private let engine: SyncEngine

    public init(engine: SyncEngine) {
        self.engine = engine
    }

    public var body: some View {
        Section {
            Toggle("Sync with iCloud", isOn: Binding(
                get: { engine.isEnabled },
                set: { engine.setEnabled($0) }
            ))
            if engine.isEnabled {
                LabeledContent("Status", value: statusText)
                if engine.status.pendingLocalCount > 0 {
                    LabeledContent("Waiting to upload", value: engine.status.pendingLocalCount.formatted())
                }
                if engine.status.pendingRemoteCount > 0 {
                    LabeledContent("Waiting to restore", value: engine.status.pendingRemoteCount.formatted())
                }
                if let error = engine.status.lastError, !isShowingCurrentError {
                    LabeledContent("Last sync issue", value: error)
                }
                if let date = engine.status.lastSyncedAt {
                    LabeledContent("Last synced") {
                        Text(date, format: .relative(presentation: .named))
                    }
                }
                Button("Sync Now") { engine.syncNow() }
                    .disabled(engine.status.state == .syncing)
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text(footerText)
        }
    }

    private var statusText: String {
        switch engine.status.state {
        case .disabled: "Off"
        case .idle:
            if engine.status.hasPendingChanges {
                "Waiting to retry"
            } else {
                "Waiting"
            }
        case .syncing: "Syncing…"
        case .upToDate: "Up to date"
        case .accountUnavailable: "iCloud unavailable — sign in to iCloud in Settings"
        case .needsAccountChoice: "Action needed — iCloud account changed"
        case .quotaExceeded: "iCloud storage full"
        case .error(let message): "Problem syncing: \(message)"
        }
    }

    private var footerText: String {
        switch engine.status.state {
        case .quotaExceeded:
            "Your iCloud storage is full. Free up space or upgrade your iCloud plan, then sync will resume automatically."
        default:
            "Your data is stored privately in your iCloud account and restored automatically when you reinstall the app. Nothing is shared with anyone."
        }
    }

    private var isShowingCurrentError: Bool {
        if case .error = engine.status.state {
            true
        } else {
            false
        }
    }
}
