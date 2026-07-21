import Testing
import Foundation
@testable import SyncKit

@Test func copiesIntoNestedDestinationCreatingDirectories() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("assets-\(UUID().uuidString)")
    let source = base.appendingPathComponent("src.bin")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    try Data("hello".utf8).write(to: source)

    let dest = base.appendingPathComponent("nested/deep/dest.bin")
    try AssetStaging.copyAsset(at: source, to: dest)
    #expect(try Data(contentsOf: dest) == Data("hello".utf8))
}

@Test func replacesExistingDestination() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("assets-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let source = base.appendingPathComponent("src.bin")
    let dest = base.appendingPathComponent("dest.bin")
    try Data("new".utf8).write(to: source)
    try Data("old".utf8).write(to: dest)

    try AssetStaging.copyAsset(at: source, to: dest)
    #expect(try Data(contentsOf: dest) == Data("new".utf8))
}

@Test func sameSourceAndDestinationIsANoOp() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("assets-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let file = base.appendingPathComponent("same.bin")
    try Data("keep".utf8).write(to: file)
    let result = try AssetStaging.copyAsset(at: file, to: file)
    #expect(result == file)
    #expect(try Data(contentsOf: file) == Data("keep".utf8))
}

@Test func replacementIsAtomicViaTempFile() throws {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("assets-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let source = base.appendingPathComponent("src.bin")
    let dest = base.appendingPathComponent("dest.bin")
    try Data("new".utf8).write(to: source)
    try Data("old".utf8).write(to: dest)
    try AssetStaging.copyAsset(at: source, to: dest)
    #expect(try Data(contentsOf: dest) == Data("new".utf8))
    // No stray temp files left behind
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: base.path)
        .filter { $0.hasPrefix("synckit-staging-") }
    #expect(leftovers.isEmpty)
}

@Test func cleansUpTempFileWhenReplaceFails() throws {
    let fm = FileManager.default
    let base = fm.temporaryDirectory
        .appendingPathComponent("assets-\(UUID().uuidString)")
    let lockedDir = base.appendingPathComponent("locked")
    try fm.createDirectory(at: lockedDir, withIntermediateDirectories: true)
    let source = base.appendingPathComponent("src.bin")
    let dest = lockedDir.appendingPathComponent("dest.bin")
    try Data("new".utf8).write(to: source)
    try Data("old".utf8).write(to: dest)
    // Read-only parent: copyItem to the temp path inside it fails (or the
    // replace does) — either way the API must throw, leave the old dest
    // intact, and leave no synckit-staging-* temp behind.
    try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: lockedDir.path)
    defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedDir.path) }
    #expect(throws: (any Error).self) {
        try AssetStaging.copyAsset(at: source, to: dest)
    }
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedDir.path)
    #expect(try Data(contentsOf: dest) == Data("old".utf8))
    let leftovers = try fm.contentsOfDirectory(atPath: lockedDir.path)
        .filter { $0.hasPrefix("synckit-staging-") }
    #expect(leftovers.isEmpty)
}
