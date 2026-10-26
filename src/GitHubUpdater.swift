import Foundation
import CryptoKit
import CoreServices

struct ReleaseVersion: Comparable {
    let text: String
    private let numbers: [UInt64]
    init?(_ raw: String) {
        let value = raw.hasPrefix("v") || raw.hasPrefix("V") ? String(raw.dropFirst()) : raw
        guard value.count <= 64, value.range(of: #"^[0-9]+(?:\.[0-9]+){0,3}$"#, options: .regularExpression) != nil else { return nil }
        let parts = value.split(separator: ".").compactMap { UInt64($0) }
        guard parts.count == value.split(separator: ".").count else { return nil }
        text = value
        var normalized = parts
        while normalized.count > 1 && normalized.last == 0 { normalized.removeLast() }
        numbers = normalized
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.numbers == rhs.numbers }
    static func < (lhs: Self, rhs: Self) -> Bool {
        for index in 0..<max(lhs.numbers.count, rhs.numbers.count) {
            let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
            let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}

enum UpdateError: Error, Equatable {
    case http(Int), invalidMetadata, invalidVersion, untrustedSource, noInstaller
    case missingChecksum, invalidChecksum, sizeMismatch, hashMismatch, notPackage
    case approvalRequired, quarantineFailed, installerFailed
}

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let size: Int64
        let browser_download_url: URL
        let digest: String?
    }
    let id: Int64
    let tag_name: String
    let name: String?
    let body: String?
    let html_url: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
}

struct AvailableUpdate {
    let release: GitHubRelease
    let version: ReleaseVersion
    let installer: GitHubRelease.Asset
    let checksumAsset: GitHubRelease.Asset?
    let sha256: String?
}

enum UpdateCheckResult {
    case current(latestVersion: String)
    case available(AvailableUpdate)
}

struct UpdateHTTPData {
    let data: Data
    let status: Int
    let url: URL
}
struct UpdateHTTPDownload {
    let status: Int
    let url: URL
}

protocol UpdateTransport {
    func fetch(_ url: URL, maximumBytes: Int) async throws -> UpdateHTTPData
    func download(_ url: URL, expectedSize: Int64, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> UpdateHTTPDownload
}

private final class UpdateDownloadHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var cancelled = false
    func start(_ task: URLSessionTask) {
        lock.lock()
        self.task = task
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { task.cancel() }
        task.resume()
    }
    func cancel() {
        lock.lock()
        cancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}

final class UpdateSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    static let assetHosts: Set<String> = ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"]
    let allowedHosts: Set<String>
    let limit: Int64
    let progress: @Sendable (Double) -> Void
    init(hosts: Set<String>, limit: Int64, progress: @escaping @Sendable (Double) -> Void = { _ in }) {
        allowedHosts = hosts
        self.limit = limit
        self.progress = progress
    }
    static func trusted(_ url: URL, hosts: Set<String>) -> Bool {
        url.scheme?.lowercased() == "https" && hosts.contains(url.host?.lowercased() ?? "") && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map { Self.trusted($0, hosts: allowedHosts) } == true ? request : nil)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > limit || totalBytesExpectedToWrite > limit { downloadTask.cancel(); return }
        if limit > 0 { progress(min(1, Double(totalBytesWritten) / Double(limit))) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}

struct GitHubUpdateTransport: UpdateTransport {
    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("AstraCreate-Updater", forHTTPHeaderField: "User-Agent")
        if url.host == "api.github.com" {
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        }
        return request
    }
    func fetch(_ url: URL, maximumBytes: Int) async throws -> UpdateHTTPData {
        let hosts = url.host == "api.github.com" ? Set(["api.github.com"]) : UpdateSessionDelegate.assetHosts
        let delegate = UpdateSessionDelegate(hosts: hosts, limit: Int64(maximumBytes))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request(url))
        guard let response = response as? HTTPURLResponse, let finalURL = response.url,
              UpdateSessionDelegate.trusted(finalURL, hosts: hosts), data.count <= maximumBytes else { throw UpdateError.invalidMetadata }
        return UpdateHTTPData(data: data, status: response.statusCode, url: finalURL)
    }
    func download(_ url: URL, expectedSize: Int64, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> UpdateHTTPDownload {
        let delegate = UpdateSessionDelegate(hosts: UpdateSessionDelegate.assetHosts, limit: expectedSize, progress: progress)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 600
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let handle = UpdateDownloadHandle()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let task = session.downloadTask(with: request(url)) { temporary, response, error in
                    if let error { continuation.resume(throwing: error); return }
                    guard let temporary, let response = response as? HTTPURLResponse, let finalURL = response.url,
                          UpdateSessionDelegate.trusted(finalURL, hosts: UpdateSessionDelegate.assetHosts) else {
                        continuation.resume(throwing: UpdateError.untrustedSource); return
                    }
                    do {
                        // URLSession deletes its temporary file after this callback returns.
                        try FileManager.default.moveItem(at: temporary, to: destination)
                        continuation.resume(returning: UpdateHTTPDownload(status: response.statusCode, url: finalURL))
                    } catch { continuation.resume(throwing: error) }
                }
                handle.start(task)
            }
        }, onCancel: { handle.cancel() })
    }
}

struct VerifiedUpdatePackage {
    let url: URL
    let version: String
}

struct GitHubUpdater {
    static let projectURL = URL(string: "https://github.com/WECLwhy/AstraCreate")!
    static let latestURL = URL(string: "https://api.github.com/repos/WECLwhy/AstraCreate/releases/latest")!
    static let maximumPackageSize: Int64 = 250 * 1024 * 1024
    let currentVersion: String
    var transport: any UpdateTransport = GitHubUpdateTransport()
    var cacheRoot: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AstraCreate/Updates")
    var markDownloaded: (URL, URL, URL) throws -> Void = markQuarantine

    func check() async throws -> UpdateCheckResult {
        let response = try await transport.fetch(Self.latestURL, maximumBytes: 1024 * 1024)
        guard response.status == 200 else { throw UpdateError.http(response.status) }
        guard response.url == Self.latestURL, response.data.count <= 1024 * 1024 else { throw UpdateError.untrustedSource }
        return try Self.evaluate(response.data, currentVersion: currentVersion)
    }

    static func evaluate(_ data: Data, currentVersion: String) throws -> UpdateCheckResult {
        guard let current = ReleaseVersion(currentVersion) else { throw UpdateError.invalidVersion }
        let release: GitHubRelease
        do { release = try JSONDecoder().decode(GitHubRelease.self, from: data) }
        catch { throw UpdateError.invalidMetadata }
        guard !release.draft, !release.prerelease, release.id > 0,
              let version = ReleaseVersion(release.tag_name) else { throw UpdateError.invalidMetadata }
        let expectedPage = projectURL.appendingPathComponent("releases/tag/\(release.tag_name)")
        guard release.html_url == expectedPage else { throw UpdateError.untrustedSource }
        guard version > current else { return .current(latestVersion: version.text) }
        let name = "AstraCreate-\(version.text).pkg"
        let candidates = release.assets.filter { $0.name == name }
        guard candidates.count == 1, let installer = candidates.first,
              installer.size > 0, installer.size <= maximumPackageSize else { throw UpdateError.noInstaller }
        try validate(asset: installer, tag: release.tag_name)
        let checksumName = "AstraCreate-\(version.text)-SHA256SUMS.txt"
        let checksumAssets = release.assets.filter { $0.name == checksumName }
        var sha: String?
        if let digest = installer.digest {
            guard digest.hasPrefix("sha256:"), let parsed = validSHA(String(digest.dropFirst(7))) else { throw UpdateError.invalidChecksum }
            sha = parsed
        }
        var checksum: GitHubRelease.Asset?
        if sha == nil {
            guard checksumAssets.count == 1, let asset = checksumAssets.first, asset.size > 0, asset.size <= 128 * 1024 else { throw UpdateError.missingChecksum }
            try validate(asset: asset, tag: release.tag_name)
            checksum = asset
        }
        return .available(AvailableUpdate(release: release, version: version, installer: installer, checksumAsset: checksum, sha256: sha))
    }

    static func validate(asset: GitHubRelease.Asset, tag: String) throws {
        let expected = projectURL.appendingPathComponent("releases/download/\(tag)/\(asset.name)")
        guard asset.browser_download_url == expected else { throw UpdateError.untrustedSource }
    }

    static func validSHA(_ value: String) -> String? {
        value.range(of: #"^[0-9a-fA-F]{64}$"#, options: .regularExpression) != nil ? value.lowercased() : nil
    }

    static func checksum(in data: Data, filename: String) throws -> String {
        guard data.count <= 128 * 1024, let text = String(data: data, encoding: .utf8) else { throw UpdateError.invalidChecksum }
        let expression = try NSRegularExpression(pattern: #"^([0-9a-fA-F]{64})[ \t]+\*?([^\r\n]+)$"#)
        var matches: [String] = []
        for line in text.split(separator: "\n") {
            let string = String(line)
            let full = NSRange(string.startIndex..., in: string)
            if let match = expression.firstMatch(in: string, range: full),
               let hashRange = Range(match.range(at: 1), in: string), let nameRange = Range(match.range(at: 2), in: string),
               String(string[nameRange]) == filename { matches.append(String(string[hashRange]).lowercased()) }
        }
        guard matches.count == 1, let result = matches.first else { throw UpdateError.invalidChecksum }
        return result
    }

    func prepare(_ update: AvailableUpdate, approved: Bool, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> VerifiedUpdatePackage {
        guard approved else { throw UpdateError.approvalRequired }
        guard let current = ReleaseVersion(currentVersion), update.version > current else { throw UpdateError.invalidVersion }
        guard update.installer.name == "AstraCreate-\(update.version.text).pkg", update.installer.size > 0,
              update.installer.size <= Self.maximumPackageSize, !update.release.draft, !update.release.prerelease,
              ReleaseVersion(update.release.tag_name) == update.version,
              update.release.html_url == Self.projectURL.appendingPathComponent("releases/tag/\(update.release.tag_name)") else { throw UpdateError.invalidMetadata }
        try Self.validate(asset: update.installer, tag: update.release.tag_name)
        try Task.checkCancellation()
        var expected = update.sha256
        if let checksum = update.checksumAsset, expected == nil {
            try Self.validate(asset: checksum, tag: update.release.tag_name)
            let response = try await transport.fetch(checksum.browser_download_url, maximumBytes: 128 * 1024)
            guard response.status == 200 else { throw UpdateError.http(response.status) }
            guard UpdateSessionDelegate.trusted(response.url, hosts: UpdateSessionDelegate.assetHosts),
                  response.data.count == checksum.size else { throw UpdateError.invalidChecksum }
            if let digest = checksum.digest {
                guard digest.hasPrefix("sha256:"), let sha = Self.validSHA(String(digest.dropFirst(7))),
                      SHA256.hash(data: response.data).map({ String(format: "%02x", $0) }).joined() == sha else { throw UpdateError.invalidChecksum }
            }
            expected = try Self.checksum(in: response.data, filename: update.installer.name)
        }
        guard let expected, Self.validSHA(expected) != nil else { throw UpdateError.missingChecksum }
        let directory = cacheRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = directory.appendingPathComponent(update.installer.name)
        var keep = false
        defer { if !keep { try? FileManager.default.removeItem(at: directory) } }
        let response = try await transport.download(update.installer.browser_download_url, expectedSize: update.installer.size, to: destination, progress: progress)
        try Task.checkCancellation()
        guard response.status == 200 else { throw UpdateError.http(response.status) }
        guard UpdateSessionDelegate.trusted(response.url, hosts: UpdateSessionDelegate.assetHosts) else { throw UpdateError.untrustedSource }
        let size = try FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber
        guard size?.int64Value == update.installer.size else { throw UpdateError.sizeMismatch }
        let handle = try FileHandle(forReadingFrom: destination)
        defer { try? handle.close() }
        let magic = try handle.read(upToCount: 4)
        guard magic == Data("xar!".utf8) else { throw UpdateError.notPackage }
        try handle.seek(toOffset: 0)
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw UpdateError.hashMismatch }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        do { try markDownloaded(destination, update.installer.browser_download_url, update.release.html_url) }
        catch { throw UpdateError.quarantineFailed }
        try Task.checkCancellation()
        keep = true // Installer reads asynchronously; retain this verified package.
        return VerifiedUpdatePackage(url: destination, version: update.version.text)
    }

    static func markQuarantine(_ local: URL, _ download: URL, _ origin: URL) throws {
        let properties: [String: Any] = [
            kLSQuarantineAgentNameKey as String: "AstraCreate",
            kLSQuarantineTimeStampKey as String: Date(),
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload as String,
            kLSQuarantineDataURLKey as String: download,
            kLSQuarantineOriginURLKey as String: origin
        ]
        try (local as NSURL).setResourceValue(properties, forKey: .quarantinePropertiesKey)
    }
}
