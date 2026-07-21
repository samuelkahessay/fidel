# SyncKit

Shared CloudKit sync layer (CKSyncEngine) for Sonora, Throughline, Fidel, RallyIQ.
Design: ios-app-ops `docs/superpowers/specs/2026-07-04-icloud-sync-layer-design.md`.
Apps own model mapping (`SyncStore`); SyncKit owns journaling, conflicts, status, and the Settings sync UI.

## 0.5.0 reliability contract

- Local uploads/deletions and failed remote applies are journaled across relaunches.
- Remote upserts are refetched by record ID before retrying so CKAsset URLs are fresh.
- Remote deletions replay locally until they succeed.
- A sync cycle cannot report `Up to date` while either journal is non-empty.
- Apps should call `SyncEngine.appDidBecomeActive()` from their active scene transition and enable the `remote-notification` background mode.
- The package privacy manifest declares SyncKit's app-specific UserDefaults access.
