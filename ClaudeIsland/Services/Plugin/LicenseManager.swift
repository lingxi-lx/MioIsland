//
//  LicenseManager.swift
//  ClaudeIsland
//
//  Manages license keys for paid plugins.
//  Keys are stored in ~/.config/codeisland/licenses.json.
//  Supports codeisland:// URL scheme for zero-friction activation.
//

import Combine
import Foundation
import OSLog

@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    private static let log = Logger(subsystem: "com.codeisland.app", category: "LicenseManager")

    @Published private(set) var licenses: [String: LicenseEntry] = [:]

    struct LicenseEntry: Codable {
        let key: String
        let pluginId: String
        let activatedAt: Date
        let expiresAt: Date?        // nil = perpetual
        let deviceId: String?       // Hardware UUID for device binding
    }

    private var licensesFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/codeisland/licenses.json")
    }

    init() {
        load()
    }

    // MARK: - Query

    func isLicensed(_ pluginId: String) -> Bool {
        guard let entry = licenses[pluginId] else { return false }
        if let exp = entry.expiresAt, exp < Date() { return false }
        return true
    }

    // MARK: - Activation

    func activate(key: String, pluginId: String) {
        let entry = LicenseEntry(
            key: key,
            pluginId: pluginId,
            activatedAt: Date(),
            expiresAt: nil,
            deviceId: hardwareUUID()
        )
        licenses[pluginId] = entry
        save()
        Self.log.info("Activated license for \(pluginId)")
    }

    /// Handle codeisland://license?key=xxx&plugin=yyy URL
    func handleURL(_ url: URL) {
        guard url.scheme == "codeisland",
              url.host == "license",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let key = components.queryItems?.first(where: { $0.name == "key" })?.value,
              let pluginId = components.queryItems?.first(where: { $0.name == "plugin" })?.value
        else { return }
        activate(key: key, pluginId: pluginId)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: licensesFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([String: LicenseEntry].self, from: data) else { return }
        licenses = decoded
    }

    private func save() {
        let dir = licensesFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(licenses) else { return }
        try? data.write(to: licensesFile, options: .atomic)
    }

    // MARK: - Device ID

    private func hardwareUUID() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        guard let uuid = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String else {
            return UUID().uuidString
        }
        return uuid
    }
}
