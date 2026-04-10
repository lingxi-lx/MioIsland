//
//  PluginManager.swift
//  ClaudeIsland
//
//  Scans, loads, and manages installed plugins from
//  ~/.config/codeisland/plugins/
//

import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class PluginManager: ObservableObject {
    static let shared = PluginManager()
    private static let log = Logger(subsystem: "com.codeisland.app", category: "PluginManager")

    @Published private(set) var installedPlugins: [PluginManifest] = []

    private var pluginsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/codeisland/plugins")
    }

    // MARK: - Loading

    func loadAll() {
        installedPlugins = []
        ensureDirectoryExists()
        loadThemes()
        loadBuddies()
        loadSounds()
        Self.log.info("Loaded \(self.installedPlugins.count) plugin(s)")
    }

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        for sub in ["themes", "buddies", "sounds"] {
            let dir = pluginsDir.appendingPathComponent(sub)
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    private func loadThemes() {
        let dir = pluginsDir.appendingPathComponent("themes")
        for pluginDir in subdirectories(of: dir) {
            guard let manifest = decode(ThemeManifest.self, from: pluginDir) else { continue }
            let def = ThemeDefinition(
                id: manifest.id,
                name: manifest.name,
                palette: parsePalette(manifest.palette),
                isBuiltIn: false
            )
            ThemeRegistry.shared.register(def)
            addToInstalled(from: pluginDir)
        }
    }

    private func loadBuddies() {
        let dir = pluginsDir.appendingPathComponent("buddies")
        for pluginDir in subdirectories(of: dir) {
            guard let manifest = decode(BuddyManifest.self, from: pluginDir) else { continue }
            let frames = manifest.frames.mapValues { frameManifests in
                frameManifests.compactMap { fm -> FrameData? in
                    guard let data = Data(base64Encoded: fm.pixels) else { return nil }
                    return FrameData(duration: fm.duration, pixels: data)
                }
            }
            let def = BuddyDefinition(
                id: manifest.id,
                name: manifest.name,
                grid: manifest.grid,
                palette: manifest.palette,
                frames: frames,
                isBuiltIn: false
            )
            BuddyRegistry.shared.register(def)
            addToInstalled(from: pluginDir)
        }
    }

    private func loadSounds() {
        let dir = pluginsDir.appendingPathComponent("sounds")
        for pluginDir in subdirectories(of: dir) {
            addToInstalled(from: pluginDir)
            // Sound plugins are loaded on-demand by PluginSoundManager
        }
    }

    // MARK: - Install / Uninstall

    func install(pluginDir sourceDir: URL, type: String, id: String) throws {
        let dest = pluginsDir.appendingPathComponent("\(type)/\(id)")
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: sourceDir, to: dest)
        loadAll()
        Self.log.info("Installed plugin \(id) to \(type)")
    }

    func uninstall(type: String, id: String) {
        let dir = pluginsDir.appendingPathComponent("\(type)/\(id)")
        try? FileManager.default.removeItem(at: dir)

        // Revert to default if this was the active plugin
        let store = NotchCustomizationStore.shared
        if type == "themes" && store.customization.theme == id {
            store.update { $0.theme = "classic" }
        }
        if type == "buddies" && store.customization.buddyId == id {
            store.update { $0.buddyId = "pixel-cat" }
        }
        if type == "sounds" && store.customization.notificationSoundPlugin == id {
            store.update { $0.notificationSoundPlugin = nil }
        }
        if type == "sounds" && store.customization.bgmPlugin == id {
            store.update { $0.bgmPlugin = nil }
            PluginSoundManager.shared.stopBGM()
        }

        ThemeRegistry.shared.unregister(id)
        BuddyRegistry.shared.unregister(id)
        installedPlugins.removeAll { $0.id == id }
        Self.log.info("Uninstalled plugin \(id) from \(type)")
    }

    // MARK: - Helpers

    private func subdirectories(of dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ))?.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        } ?? []
    }

    private func decode<T: Decodable>(_ type: T.Type, from dir: URL) -> T? {
        let url = dir.appendingPathComponent("plugin.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func addToInstalled(from dir: URL) {
        if let manifest = decode(PluginManifest.self, from: dir) {
            installedPlugins.removeAll { $0.id == manifest.id }
            installedPlugins.append(manifest)
        }
    }

    private func parsePalette(_ p: PaletteManifest) -> NotchPalette {
        NotchPalette(
            bg: Color(hex: p.bg),
            fg: Color(hex: p.fg),
            secondaryFg: Color(hex: p.secondaryFg)
        )
    }
}
