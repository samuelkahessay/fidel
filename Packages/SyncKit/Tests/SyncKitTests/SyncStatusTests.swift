import Testing
import Foundation
@testable import SyncKit

@MainActor
struct SyncStatusTests {
    @Test func syncStartOnlyLeavesReadyStates() {
        let status = SyncStatus()
        status.noteSyncStarted()                 // disabled -> no change
        #expect(status.state == .disabled)
        status.set(.idle)
        status.noteSyncStarted()
        #expect(status.state == .syncing)
        status.set(.accountUnavailable)
        status.noteSyncStarted()                 // blocked states don't enter syncing
        #expect(status.state == .accountUnavailable)
        status.set(.needsAccountChoice)
        status.noteSyncStarted()                 // blocked states don't enter syncing
        #expect(status.state == .needsAccountChoice)
    }

    @Test func syncStartAllowsQuotaExceededToReenterSyncing() {
        // Quota errors are self-healing: a fresh send cycle re-enters
        // .syncing so it can either clear (-> .upToDate) or re-set
        // .quotaExceeded if the failure recurs within the same cycle.
        let status = SyncStatus()
        status.set(.quotaExceeded)
        status.noteSyncStarted()
        #expect(status.state == .syncing)
    }

    @Test func successRecordsTimestampAndUpToDateFromSyncing() {
        let status = SyncStatus()
        status.set(.idle)
        status.noteSyncStarted()
        #expect(status.state == .syncing)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        status.noteSyncSucceeded(at: date)
        #expect(status.state == .upToDate)
        #expect(status.lastSyncedAt == date)
    }

    @Test func successFromErrorStaysError() {
        // Regression guard: didSendChanges firing after a failure was
        // recorded earlier in the same cycle must NOT stomp the failure.
        let status = SyncStatus()
        status.set(.idle)
        status.noteSyncStarted()
        status.noteSyncFailed("network down")
        #expect(status.state == .error("network down"))
        status.noteSyncSucceeded()
        #expect(status.state == .error("network down"))
        #expect(status.lastSyncedAt == nil)
    }

    @Test func successFromQuotaExceededStaysQuotaExceeded() {
        // Same stickiness guard for the quota-specific failure state.
        let status = SyncStatus()
        status.set(.idle)
        status.noteSyncStarted()
        status.set(.quotaExceeded)
        status.noteSyncSucceeded()
        #expect(status.state == .quotaExceeded)
        #expect(status.lastSyncedAt == nil)
    }

    @Test func successIsNoOpFromIdleAndDisabled() {
        // noteSyncSucceeded only ever fires from .syncing; other resting
        // states are left alone too.
        let idleStatus = SyncStatus()
        idleStatus.set(.idle)
        idleStatus.noteSyncSucceeded()
        #expect(idleStatus.state == .idle)
        #expect(idleStatus.lastSyncedAt == nil)

        let disabledStatus = SyncStatus()
        disabledStatus.noteSyncSucceeded()
        #expect(disabledStatus.state == .disabled)
        #expect(disabledStatus.lastSyncedAt == nil)
    }

    @Test func failureCarriesMessage() {
        let status = SyncStatus()
        status.set(.idle)
        status.noteSyncFailed("network down")
        #expect(status.state == .error("network down"))
        #expect(status.lastError == "network down")
    }

    @Test func pendingJournalsPreventFalseUpToDateState() {
        let status = SyncStatus()
        status.set(.idle)
        status.updatePendingCounts(local: 1, remote: 2)
        status.noteSyncStarted()
        status.noteSyncSucceeded()

        #expect(status.state == .idle)
        #expect(status.lastSyncedAt == nil)
        #expect(status.pendingLocalCount == 1)
        #expect(status.pendingRemoteCount == 2)
    }

    @Test func clearingJournalsAllowsSuccessfulStateAndClearsError() {
        let status = SyncStatus()
        status.set(.idle)
        status.noteSyncFailed("asset unavailable")
        status.noteSyncStarted()
        status.updatePendingCounts(local: 0, remote: 0)
        status.noteSyncSucceeded(at: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(status.state == .upToDate)
        #expect(status.lastError == nil)
    }
}
