//
//  PluginManifest.swift
//  ClaudeIsland
//
//  Data types for plugin.json manifests (theme, buddy, sound).
//

import Foundation

/// The type field in plugin.json
enum PluginType: String, Codable {
    case theme, buddy, sound
}

/// Shared fields across all plugin.json files
struct PluginManifest: Codable, Identifiable {
    let type: PluginType
    let id: String
    let name: String
    let version: String
    let minAppVersion: String?
    let author: PluginAuthor
    let price: Int              // cents USD, 0 = free
    let description: String?
    let tags: [String]?
    let preview: String?        // filename relative to plugin dir
}

struct PluginAuthor: Codable {
    let name: String
    let url: String?
    let github: String?
}

// MARK: - Theme Manifest

struct ThemeManifest: Codable {
    let type: PluginType
    let id: String
    let name: String
    let version: String
    let author: PluginAuthor
    let price: Int
    let palette: PaletteManifest
    let preview: String?
}

struct PaletteManifest: Codable {
    let bg: String              // hex e.g. "#0A1628"
    let fg: String
    let secondaryFg: String
}

// MARK: - Buddy Manifest

struct BuddyManifest: Codable {
    let type: PluginType
    let id: String
    let name: String
    let version: String
    let author: PluginAuthor
    let price: Int
    let grid: GridSpec
    let palette: [String]       // indexed color palette, max 8 hex colors
    let frames: [String: [FrameManifest]]  // animationState -> frames
    let preview: String?
}

struct GridSpec: Codable, Equatable {
    let width: Int
    let height: Int
    let cellSize: Int
}

struct FrameManifest: Codable {
    let duration: Int           // ms
    let pixels: String          // base64 encoded 4-bit indexed bitmap
}

// MARK: - Sound Manifest

struct SoundManifest: Codable {
    let type: PluginType
    let id: String
    let name: String
    let version: String
    let author: PluginAuthor
    let price: Int
    let category: SoundCategory
    let sounds: [String: SoundFileEntry]  // event key -> file info
    let preview: String?
}

enum SoundCategory: String, Codable {
    case music, notification, ambient
}

struct SoundFileEntry: Codable {
    let file: String
    let loop: Bool?
    let volume: Float?
}
