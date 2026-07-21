/// Per-app sync settings. Container and zone names are registry facts —
/// record them in ios-app-ops `apps.yml` under the app's `sync:` block.
public struct SyncConfiguration: Sendable {
    public let containerIdentifier: String
    public let zoneName: String

    public init(containerIdentifier: String, zoneName: String) {
        self.containerIdentifier = containerIdentifier
        self.zoneName = zoneName
    }
}
