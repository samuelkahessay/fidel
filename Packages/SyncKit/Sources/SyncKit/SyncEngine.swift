import CloudKit
import Foundation
import Observation

/// Portfolio sync engine: wraps CKSyncEngine so apps only provide a `SyncStore`
/// and call `markPending` on mutation. Apple owns change tokens, scheduling,
/// batching, retries, and push subscriptions.
@MainActor
@Observable
public final class SyncEngine {
    public let status = SyncStatus()
    public private(set) var isEnabled: Bool

    private let config: SyncConfiguration
    private let store: any SyncStore
    private let journal: PendingChangeJournal
    private let remoteJournal: FailedRemoteChangeJournal
    private let stateFileURL: URL
    private var engine: CKSyncEngine?
    private var database: CKDatabase?

    nonisolated static let enabledDefaultsKey = "SyncKit.enabled"
    private static let hasEverEnabledKey = "SyncKit.hasEverEnabled"

    public var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: config.zoneName)
    }

    /// Default-on semantics: sync is invisible infrastructure per the design
    /// spec, so an unset default (`object(forKey:) == nil`, meaning the user
    /// never chose) is treated as enabled. Once the user makes an explicit
    /// choice via `setEnabled(_:)`, that stored bool is respected verbatim.
    nonisolated static func initialEnabledState(defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: enabledDefaultsKey) != nil else { return true }
        return defaults.bool(forKey: enabledDefaultsKey)
    }

    public init(configuration: SyncConfiguration, store: any SyncStore) {
        self.config = configuration
        self.store = store
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("SyncKit", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.journal = PendingChangeJournal(fileURL: dir.appendingPathComponent("journal.json"))
        self.remoteJournal = FailedRemoteChangeJournal(fileURL: dir.appendingPathComponent("remote-journal.json"))
        self.stateFileURL = dir.appendingPathComponent("engine-state.json")
        self.isEnabled = Self.initialEnabledState(defaults: .standard)
        refreshPendingStatus()
        if isEnabled { start() }
    }

    // MARK: - Enable / disable

    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled {
            start()
            syncNow()
        } else {
            engine = nil
            database = nil
            status.set(.disabled)
        }
    }

    /// Single-sourced first-ever-enable bookkeeping: whether sync turned on
    /// explicitly via `setEnabled(true)` or implicitly via default-on at
    /// init, the first launch that ever runs sync must mark every existing
    /// local record pending so it gets uploaded. Runs from `start()` so both
    /// paths go through the same check.
    private func markAllPendingIfFirstEverEnable() {
        guard !UserDefaults.standard.bool(forKey: Self.hasEverEnabledKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.hasEverEnabledKey)
        markAllPending()
    }

    private func start() {
        let container = CKContainer(identifier: config.containerIdentifier)
        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: loadStateSerialization(),
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        self.database = container.privateCloudDatabase
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        replayJournal(into: engine)
        status.set(.idle)
        markAllPendingIfFirstEverEnable()
        refreshPendingStatus()

        Task {
            // Default-on exposes no-account users to raw CloudKit errors, so
            // gate on account status right after starting the engine. An
            // error checking status is treated the same as "not available":
            // it's a signal we can't confirm sync can proceed, so err toward
            // not silently leaving `.idle` set.
            let accountStatus = try? await container.accountStatus()
            // Torn down or replaced while we awaited (toggle-off, account
            // switch, or restart all nil/replace `self.engine`): the newer
            // state already reflects reality, so this stale Task must not
            // stomp it.
            guard self.engine === engine else { return }
            if accountStatus != .available {
                self.status.set(.accountUnavailable)
            }
        }
    }

    private func replayJournal(into engine: CKSyncEngine) {
        let saves = journal.pendingSaves.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord($0.recordID(in: zoneID))
        }
        let deletes = journal.pendingDeletes.map {
            CKSyncEngine.PendingRecordZoneChange.deleteRecord($0.recordID(in: zoneID))
        }
        engine.state.add(pendingRecordZoneChanges: saves + deletes)
    }

    // MARK: - Marking changes

    public func markPending(_ id: SyncID) {
        journal.recordSave(id)
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id.recordID(in: zoneID))])
        refreshPendingStatus()
    }

    /// Batch variant: one journal write and one engine-state update for the
    /// whole collection. Use for bulk local mutations (e.g. importing
    /// thousands of records from HealthKit).
    public func markPending(_ ids: [SyncID]) {
        guard !ids.isEmpty else { return }
        journal.recordSaves(ids)
        engine?.state.add(pendingRecordZoneChanges: ids.map { .saveRecord($0.recordID(in: zoneID)) })
        refreshPendingStatus()
    }

    public func markPendingDeletion(_ id: SyncID) {
        journal.recordDelete(id)
        engine?.state.add(pendingRecordZoneChanges: [.deleteRecord(id.recordID(in: zoneID))])
        refreshPendingStatus()
    }

    /// Batch variant: one journal write and one engine-state update for the
    /// whole collection. Use for bulk local deletions (e.g. erasing thousands
    /// of records at once).
    public func markPendingDeletion(_ ids: [SyncID]) {
        guard !ids.isEmpty else { return }
        journal.recordDeletes(ids)
        engine?.state.add(pendingRecordZoneChanges: ids.map { .deleteRecord($0.recordID(in: zoneID)) })
        refreshPendingStatus()
    }

    public func markAllPending() {
        do {
            markPending(try store.allSyncIDs())
        } catch {
            status.noteSyncFailed("Could not enumerate local sync data: \(error.localizedDescription)")
        }
    }

    public func syncNow() {
        guard let engine, let database else { return }
        status.noteSyncStarted()
        // Sync Now is the universal in-session recovery path: records
        // can be dropped from CKSyncEngine's pending set without ever
        // reaching the server (quota failures, `.serverRecordChanged`
        // with a nil `serverRecord`, failed deletes), but the journal
        // still has them. Replay it before every manual sync so those
        // records get re-enqueued; `state.add` is idempotent since the
        // pending set is a set, so replaying already-pending changes is
        // a no-op. (`state.add` is one of the few calls CloudKit permits
        // from inside delegate callbacks, so doing it synchronously here
        // is safe from any calling context.)
        replayJournal(into: engine)
        // MUST be detached, not a plain Task: syncNow is reachable from
        // CKSyncEngine delegate callbacks (accountChange .signIn →
        // handleAccountChange → syncNow). An inheriting Task carries the
        // delegate's task-locals, and awaiting fetch/send "from within a
        // delegate callback" is a CloudKit fatalError (verified on device:
        // launch crash on first run with a signed-in iCloud account).
        // Task.detached drops the task-locals — exactly the remedy
        // CloudKit's error message prescribes.
        Task.detached { [weak self] in
            do {
                await self?.retryFailedRemoteChanges(using: database)
                try await engine.fetchChanges()
                try await engine.sendChanges()
                await self?.finishSync(error: nil)
            } catch {
                await self?.finishSync(error: error)
            }
        }
    }

    /// Call from the app's active-scene transition. This gives failed local
    /// and remote journal entries a deterministic retry even when no push was
    /// delivered while the app was suspended.
    public func appDidBecomeActive() {
        guard isEnabled else { return }
        syncNow()
    }

    private func finishSync(error: Error?) {
        refreshPendingStatus()
        if let error {
            status.noteSyncFailed(error.localizedDescription)
        } else {
            status.noteSyncSucceeded()
        }
    }

    // MARK: - Account change resolutions

    /// Keep local data and upload it into the newly signed-in account.
    public func mergeLocalDataIntoCurrentAccount() {
        do {
            try store.resetAllSystemFields()
        } catch {
            status.noteSyncFailed("Could not reset local sync metadata: \(error.localizedDescription)")
            return
        }
        deleteStateSerialization()
        journal.clearAll()
        remoteJournal.clearAll()
        start()
        markAllPending()
        syncNow()
    }

    /// Adopt the new account's data. The app MUST wipe (and archive) its local
    /// store before calling this; a fresh fetch then rebuilds it.
    public func adoptCurrentAccountData() {
        deleteStateSerialization()
        journal.clearAll()
        remoteJournal.clearAll()
        start()
        syncNow()
    }

    // MARK: - Engine state persistence

    private func loadStateSerialization() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateFileURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) {
        guard let data = try? JSONEncoder().encode(serialization) else { return }
        try? data.write(to: stateFileURL, options: .atomic)
    }

    private func deleteStateSerialization() {
        try? FileManager.default.removeItem(at: stateFileURL)
    }

    private func refreshPendingStatus() {
        status.updatePendingCounts(
            local: journal.pendingSaves.count + journal.pendingDeletes.count,
            remote: remoteJournal.pendingUpserts.count + remoteJournal.pendingDeletions.count
        )
    }

    private func retryFailedRemoteChanges(using database: CKDatabase) async {
        let retrier = FailedRemoteChangeRetrier(
            journal: remoteJournal,
            store: store,
            zoneID: zoneID
        )
        let outcome = await retrier.retry(using: database)

        for id in outcome.appliedUpserts {
            journal.clearSave(id)
        }
        for id in outcome.appliedDeletions {
            journal.clearSave(id)
            journal.clearDelete(id)
        }
        markPending(outcome.localNewer)
        refreshPendingStatus()

        if !outcome.errors.isEmpty {
            status.noteSyncFailed(outcome.errors.joined(separator: "; "))
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension SyncEngine: CKSyncEngineDelegate {
    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            saveStateSerialization(stateUpdate.stateSerialization)

        case .accountChange(let accountChange):
            handleAccountChange(accountChange)

        case .fetchedDatabaseChanges(let changes):
            for deletion in changes.deletions where deletion.zoneID == zoneID {
                // Server zone deleted: local is truth — recreate and re-upload.
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                markAllPending()
            }

        case .fetchedRecordZoneChanges(let changes):
            for modification in changes.modifications {
                // Shared container can carry foreign zones (e.g. an old
                // app's private zone from a prior schema). Only this
                // zone's records are ours to apply; skip others silently.
                guard modification.record.recordID.zoneID == zoneID else { continue }
                applyRemote(modification.record)
            }
            for deletion in changes.deletions {
                guard deletion.recordID.zoneID == zoneID else { continue }
                if let id = SyncID(recordName: deletion.recordID.recordName) {
                    remoteJournal.recordDeletion(id)
                    do {
                        try store.applyRemoteDeletion(of: id)
                        remoteJournal.clearDeletion(id)
                        journal.clearSave(id)
                        journal.clearDelete(id)
                    } catch {
                        status.noteSyncFailed("delete apply failed: \(error.localizedDescription)")
                    }
                    refreshPendingStatus()
                }
            }

        case .sentRecordZoneChanges(let sent):
            for record in sent.savedRecords {
                store.didSaveRecord(record)
                if let id = SyncID(recordName: record.recordID.recordName) {
                    journal.clearSave(id)
                }
            }
            for failed in sent.failedRecordSaves {
                handleFailedSave(failed, syncEngine: syncEngine)
            }
            for recordID in sent.deletedRecordIDs {
                if let id = SyncID(recordName: recordID.recordName) {
                    journal.clearDelete(id)
                }
            }
            refreshPendingStatus()

        case .willFetchChanges, .willSendChanges:
            status.noteSyncStarted()

        case .didFetchChanges, .didSendChanges:
            refreshPendingStatus()
            status.noteSyncSucceeded()

        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await MainActor.run {
                guard let id = SyncID(recordName: recordID.recordName) else {
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    return nil
                }
                do {
                    guard let record = try self.store.recordToSave(for: id, in: self.zoneID) else {
                        // Gone locally: drop from batch and journal.
                        syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                        self.journal.clearSave(id)
                        self.refreshPendingStatus()
                        return nil
                    }
                    return record
                } catch {
                    // Transient (asset unreadable, fetch error): drop from this
                    // batch but keep the journal entry — syncNow() replays it.
                    syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    self.status.noteSyncFailed("record read failed: \(error.localizedDescription)")
                    return nil
                }
            }
        }
    }

    // MARK: - Event helpers

    private func applyRemote(_ record: CKRecord) {
        guard let id = SyncID(recordName: record.recordID.recordName) else { return }
        remoteJournal.recordUpsert(id)
        do {
            switch try store.applyRemoteRecord(record) {
            case .applied:
                remoteJournal.clearUpsert(id)
                journal.clearSave(id)
            case .localNewer:
                // Local wins LWW: keep server change tag, re-upload local values.
                store.didSaveRecord(record)
                remoteJournal.clearUpsert(id)
                markPending(id)
            }
        } catch {
            status.noteSyncFailed("apply failed: \(error.localizedDescription)")
        }
        refreshPendingStatus()
    }

    private func handleFailedSave(
        _ failed: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        syncEngine: CKSyncEngine
    ) {
        guard let id = SyncID(recordName: failed.record.recordID.recordName) else { return }
        let error = failed.error
        switch error.code {
        case .serverRecordChanged:
            guard let server = error.serverRecord else { return }
            switch ConflictResolution.winner(localRecord: failed.record, serverRecord: server) {
            case .local:
                store.didSaveRecord(server)   // adopt server change tag
                markPending(id)               // re-encode local values next batch
            case .server:
                remoteJournal.recordUpsert(id)
                do {
                    _ = try store.applyRemoteRecord(server)
                    store.didSaveRecord(server)
                    remoteJournal.clearUpsert(id)
                    journal.clearSave(id)
                } catch {
                    status.noteSyncFailed("conflict apply failed: \(error.localizedDescription)")
                    // journal entry stays pending so the record retries
                }
                refreshPendingStatus()
            }
        case .zoneNotFound:
            syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            markPending(id)
        case .unknownItem:
            // Deleted server-side while we held a change tag: re-upload as new.
            store.didSaveRecord(CKRecord(recordType: id.recordType,
                                         recordID: id.recordID(in: zoneID)))
            markPending(id)
        case .quotaExceeded:
            status.set(.quotaExceeded)
        default:
            status.noteSyncFailed(error.localizedDescription)
        }
    }

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        switch event.changeType {
        case .signIn:
            status.set(.idle)
            syncNow()
        case .signOut:
            status.set(.accountUnavailable)
        case .switchAccounts:
            engine = nil
            database = nil
            deleteStateSerialization()
            status.set(.needsAccountChoice)
        @unknown default:
            break
        }
    }
}
