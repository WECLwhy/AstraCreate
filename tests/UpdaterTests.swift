import Foundation
import CryptoKit

private final class FakeUpdateTransport: UpdateTransport, @unchecked Sendable {
    var metadata: Data
    var bytes: Data
    var checksum: Data
    var fetchStatus = 200
    var downloadStatus = 200
    var finalURL = URL(string: "https://release-assets.githubusercontent.com/test/installer.pkg")!
    var slow = false
    private let lock = NSLock()
    private var requests = 0
    private var transfers = 0
    init(metadata: Data, bytes: Data, checksum: Data) { self.metadata = metadata; self.bytes = bytes; self.checksum = checksum }
    private func note(_ download: Bool) { lock.lock(); defer { lock.unlock() }; if download { transfers += 1 } else { requests += 1 } }
    func counts() -> (Int, Int) { lock.lock(); defer { lock.unlock() }; return (requests, transfers) }
    func fetch(_ url: URL, maximumBytes: Int) async throws -> UpdateHTTPData {
        note(false)
        return UpdateHTTPData(data: url == GitHubUpdater.latestURL ? metadata : checksum, status: fetchStatus, url: url)
    }
    func download(_ url: URL, expectedSize: Int64, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> UpdateHTTPDownload {
        note(true)
        if slow { try await Task.sleep(nanoseconds: 5_000_000_000) }
        try Task.checkCancellation()
        try bytes.write(to: destination)
        progress(1)
        return UpdateHTTPDownload(status: downloadStatus, url: finalURL)
    }
}

@main
enum UpdaterTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let package = Data("xar!isolated updater test package".utf8)
        let hash = SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined()
        let checksum = Data("\(hash)  AstraCreate-2.18.pkg\n".utf8)
        func fixture(tag: String = "v2.18", prerelease: Bool = false, digest: String? = "default", assetURL: String? = nil) throws -> Data {
            let version = String(tag.dropFirst())
            var asset: [String: Any] = ["name": "AstraCreate-\(version).pkg", "size": package.count,
                "browser_download_url": assetURL ?? "https://github.com/WECLwhy/AstraCreate/releases/download/\(tag)/AstraCreate-\(version).pkg"]
            if let digest { asset["digest"] = digest == "default" ? "sha256:\(hash)" : digest }
            return try JSONSerialization.data(withJSONObject: ["id": 42, "tag_name": tag, "name": "Test release", "body": "Fixture only; no real installation.",
                "html_url": "https://github.com/WECLwhy/AstraCreate/releases/tag/\(tag)", "draft": false, "prerelease": prerelease,
                "assets": [asset, ["name": "AstraCreate-\(version)-SHA256SUMS.txt", "size": checksum.count,
                    "browser_download_url": "https://github.com/WECLwhy/AstraCreate/releases/download/\(tag)/AstraCreate-\(version)-SHA256SUMS.txt"]]])
        }
        func available(_ data: Data) throws -> AvailableUpdate {
            guard case .available(let value) = try GitHubUpdater.evaluate(data, currentVersion: "2.17") else { fatalError("Expected update") }
            return value
        }
        func client(_ transport: FakeUpdateTransport, name: String) -> GitHubUpdater {
            GitHubUpdater(currentVersion: "2.17", transport: transport, cacheRoot: root.appendingPathComponent(name), markDownloaded: { _, _, _ in })
        }
        func expect(_ expected: UpdateError, _ operation: () async throws -> Void) async throws {
            do { try await operation(); fatalError("Expected \(expected)") }
            catch let error as UpdateError { precondition(error == expected, "Unexpected \(error), expected \(expected)") }
        }

        precondition(ReleaseVersion("2.9")! < ReleaseVersion("v2.17")!)
        precondition(ReleaseVersion("2.17")! == ReleaseVersion("2.17.0")!)
        precondition(ReleaseVersion("2.17.1")! > ReleaseVersion("2.17")!)
        precondition(ReleaseVersion("2.18-rc1") == nil && ReleaseVersion("2.18;rm") == nil)
        for current in ["2.18", "2.19", "2.18.0"] {
            guard case .current = try GitHubUpdater.evaluate(fixture(), currentVersion: current) else { fatalError("Must not downgrade/reinstall") }
        }
        let metadata = try fixture()
        let update = try available(metadata)
        let fake = FakeUpdateTransport(metadata: metadata, bytes: package, checksum: checksum)
        let updater = client(fake, name: "valid")
        _ = try await updater.check()
        precondition(fake.counts().0 == 1 && fake.counts().1 == 0, "Checking must not download a package")
        let denied = FakeUpdateTransport(metadata: metadata, bytes: package, checksum: checksum)
        denied.fetchStatus = 403
        try await expect(.http(403)) { _ = try await client(denied, name: "rate-limited").check() }
        precondition(denied.counts().1 == 0)
        try await expect(.approvalRequired) { _ = try await updater.prepare(update, approved: false) }
        precondition(fake.counts().0 == 1 && fake.counts().1 == 0, "Decline must do no transfer")
        let verified = try await updater.prepare(update, approved: true)
        let saved = try Data(contentsOf: verified.url)
        precondition(saved == package && verified.version == "2.18")

        for (name, mutation, expected) in [
            ("corrupt", 0, UpdateError.hashMismatch), ("short", 1, .sizeMismatch), ("html", 2, .notPackage),
            ("http", 3, .http(503)), ("redirect", 4, .untrustedSource)
        ] {
            let broken = FakeUpdateTransport(metadata: metadata, bytes: package, checksum: checksum)
            if mutation == 0 { var bytes = [UInt8](package); bytes[8] ^= 1; broken.bytes = Data(bytes) }
            if mutation == 1 { broken.bytes = package.dropLast() }
            if mutation == 2 { var bytes = [UInt8](package); bytes[0] = 60; broken.bytes = Data(bytes) }
            if mutation == 3 { broken.downloadStatus = 503 }
            if mutation == 4 { broken.finalURL = URL(string: "https://example.com/not-github.pkg")! }
            let invalidClient = client(broken, name: name)
            try await expect(expected) { _ = try await invalidClient.prepare(update, approved: true) }
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: invalidClient.cacheRoot.path)) ?? []
            precondition(contents.isEmpty, "Failed downloads must not leave a usable package")
        }

        let fallbackMetadata = try fixture(digest: nil)
        let fallback = FakeUpdateTransport(metadata: fallbackMetadata, bytes: package, checksum: checksum)
        _ = try await client(fallback, name: "checksum-fallback").prepare(available(fallbackMetadata), approved: true)
        precondition(fallback.counts().0 == 1, "Missing API digest must fetch the checksum after approval")
        do {
            _ = try GitHubUpdater.checksum(in: Data("\(hash)  AstraCreate-2.18.pkg\n\(hash)  AstraCreate-2.18.pkg\n".utf8), filename: "AstraCreate-2.18.pkg")
            fatalError("Ambiguous checksum must fail")
        } catch let error as UpdateError { precondition(error == .invalidChecksum) }
        for data in [try fixture(prerelease: true), try fixture(assetURL: "https://example.com/AstraCreate-2.18.pkg"), try fixture(digest: "sha256:bad")] {
            do { _ = try available(data); fatalError("Untrusted/ineligible release accepted") } catch is UpdateError {}
        }
        var noChecksum = try JSONSerialization.jsonObject(with: fixture(digest: nil)) as! [String: Any]
        noChecksum["assets"] = [(noChecksum["assets"] as! [[String: Any]])[0]]
        do { _ = try available(JSONSerialization.data(withJSONObject: noChecksum)); fatalError("Unverifiable release accepted") }
        catch let error as UpdateError { precondition(error == .missingChecksum) }
        precondition(!UpdateSessionDelegate.trusted(URL(string: "http://github.com/file")!, hosts: UpdateSessionDelegate.assetHosts))
        precondition(!UpdateSessionDelegate.trusted(URL(string: "https://github.com.evil.example/file")!, hosts: UpdateSessionDelegate.assetHosts))
        precondition(!UpdateSessionDelegate.trusted(URL(string: "https://github.com:8443/file")!, hosts: UpdateSessionDelegate.assetHosts))
        precondition(UpdateSessionDelegate.trusted(URL(string: "https://release-assets.githubusercontent.com/asset?signature=test")!, hosts: UpdateSessionDelegate.assetHosts))

        let failingMark = FakeUpdateTransport(metadata: metadata, bytes: package, checksum: checksum)
        var markingClient = client(failingMark, name: "quarantine-failed")
        markingClient.markDownloaded = { _, _, _ in throw CocoaError(.fileWriteNoPermission) }
        try await expect(.quarantineFailed) { _ = try await markingClient.prepare(update, approved: true) }

        let slow = FakeUpdateTransport(metadata: metadata, bytes: package, checksum: checksum)
        slow.slow = true
        let cancelledClient = client(slow, name: "cancelled")
        let pending = Task { try await cancelledClient.prepare(update, approved: true) }
        for _ in 0..<100 {
            if slow.counts().1 > 0 { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        pending.cancel()
        do { _ = try await pending.value; fatalError("Cancellation ignored") } catch is CancellationError {}
        precondition((try? FileManager.default.contentsOfDirectory(atPath: cancelledClient.cacheRoot.path))?.isEmpty == true)

        let realMark = root.appendingPathComponent("quarantine-test.pkg")
        try package.write(to: realMark)
        try GitHubUpdater.markQuarantine(realMark, update.installer.browser_download_url, update.release.html_url)
        let properties = try (realMark as NSURL).resourceValues(forKeys: [.quarantinePropertiesKey])
        precondition(properties[.quarantinePropertiesKey] != nil)
        print("Passed version/source validation, no downgrade, consent gate, digest/checksum verification, cancellation, failed-stage cleanup and quarantine marking (fixture downloads; Installer never opened).")

        if let path = ProcessInfo.processInfo.environment["ASTRACREATE_LIVE_RELEASE_FIXTURE"] {
            let live = try Data(contentsOf: URL(fileURLWithPath: path))
            guard case .available(let release) = try GitHubUpdater.evaluate(live, currentVersion: "0.0") else { fatalError("Live release format invalid") }
            precondition(release.sha256 != nil)
            print("Actual GitHub release metadata parsed successfully; no installer downloaded.")
        }
    }
}
