import Foundation
import Observation

public enum SyncState: Equatable, Sendable {
    case disabled
    case idle
    case syncing
    case upToDate
    case accountUnavailable
    case needsAccountChoice
    case quotaExceeded
    case error(String)
}

/// Observable sync state for the Settings UI. Only `SyncEngine` mutates it.
@MainActor
@Observable
public final class SyncStatus {
    public private(set) var state: SyncState = .disabled
    public private(set) var lastSyncedAt: Date?
    public private(set) var pendingLocalCount = 0
    public private(set) var pendingRemoteCount = 0
    public private(set) var lastError: String?

    public var lastSuccessfulSyncAt: Date? { lastSyncedAt }
    public var hasPendingChanges: Bool { pendingLocalCount + pendingRemoteCount > 0 }

    public init() {}

    /// Mutation is module-internal; `SyncEngine` is the sole writer.
    func set(_ newState: SyncState) {
        state = newState
        if case .error(let message) = newState {
            lastError = message
        }
    }

    func updatePendingCounts(local: Int, remote: Int) {
        pendingLocalCount = local
        pendingRemoteCount = remote

        if state == .upToDate, hasPendingChanges {
            state = .idle
        }
    }

    /// Transition triggered by `SyncEngine` on sync start.
    ///
    /// `.quotaExceeded` is allowed back into `.syncing` so quota errors are
    /// self-healing: a new send cycle re-enters `.syncing`, and if the quota
    /// failure recurs it re-sets `.quotaExceeded` within that same cycle; if
    /// it doesn't recur, the cycle can reach `.upToDate`. Account-level
    /// blockers (`accountUnavailable`, `needsAccountChoice`, `disabled`)
    /// remain blocked since a plain sync cycle can't resolve them.
    func noteSyncStarted() {
        switch state {
        case .idle, .upToDate, .error, .quotaExceeded:
            state = .syncing
        case .disabled, .syncing, .accountUnavailable, .needsAccountChoice:
            break
        }
    }

    /// Transition triggered by `SyncEngine` on sync success.
    ///
    /// Only fires from `.syncing`. CKSyncEngine emits `sentRecordZoneChanges`
    /// (which can set `.error`/`.quotaExceeded` for the records that failed)
    /// followed by `didSendChanges` (which reports overall cycle completion)
    /// in the same cycle. If we unconditionally moved to `.upToDate` here, a
    /// failure recorded moments earlier in the same cycle would be
    /// overwritten, showing "Up to date" while records are actually stuck
    /// unsynced. Restricting this transition to `.syncing` makes failure
    /// states sticky for the rest of the cycle: they only clear on the next
    /// cycle's `noteSyncStarted()` re-entry into `.syncing`.
    func noteSyncSucceeded(at date: Date = .now) {
        guard state == .syncing, !hasPendingChanges else {
            if state == .syncing { state = .idle }
            return
        }
        state = .upToDate
        lastSyncedAt = date
        lastError = nil
    }

    /// Transition triggered by `SyncEngine` on sync failure.
    func noteSyncFailed(_ message: String) {
        state = .error(message)
        lastError = message
    }
}
