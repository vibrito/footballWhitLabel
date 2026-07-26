import Testing
import Foundation
import CryptoKit

/// The crest model and disc renderer are shared byte-for-byte with the other app, but the
/// two ship from separate git repos so nothing at build time can compare them. Instead each
/// file carries a hash of its own content, written by scripts/sync-crests.sh.
///
/// If someone edits a shared file without re-running the script, the stamp no longer matches
/// and this fails — in whichever repo the edit happened. And because the stamp covers the
/// content, two copies carrying the same stamp and each hashing to it are necessarily
/// identical, which is the cross-repo guarantee we cannot check directly.
@Suite("Crest sync")
struct CrestSyncTests {
    private static let stampPrefix = "// crest-sync:"

    /// Walks up from this test file to the repo root, so it does not care where the
    /// checkout lives or what the build's working directory is.
    private func repoRoot(from file: StaticString = #filePath) -> URL {
        var url = URL(fileURLWithPath: "\(file)")
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
                return url
            }
        }
        return url
    }

    private func check(_ relativePath: String) throws {
        let url = repoRoot().appendingPathComponent(relativePath)
        let text = try String(contentsOf: url, encoding: .utf8)

        let stampLine = try #require(
            text.split(separator: "\n", omittingEmptySubsequences: false)
                .first { $0.hasPrefix(Self.stampPrefix) },
            "\(relativePath) has no '\(Self.stampPrefix)' line — is it still a shared file?")

        let stamped = stampLine.dropFirst(Self.stampPrefix.count)
            .trimmingCharacters(in: .whitespaces)

        let body = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix(Self.stampPrefix) }
            .joined(separator: "\n")
        let actual = SHA256.hash(data: Data(body.utf8))
            .map { String(format: "%02x", $0) }.joined()

        #expect(actual == stamped,
                "\(relativePath) has changed since it was last synced. Run scripts/sync-crests.sh in the white-label repo and commit both repos.")
    }

    @Test("The crest model matches its sync stamp")
    func modelInSync() throws { try check("BR2026/Models/TeamCrestSymbol.swift") }

    @Test("The disc renderer matches its sync stamp")
    func rendererInSync() throws { try check("BR2026/Components/CrestDisc.swift") }
}
