//
//  NotchCustomization.swift
//  ClaudeIsland
//
//  Single value type holding every user-adjustable notch setting.
//  Persisted atomically by NotchCustomizationStore under the
//  UserDefaults key `notchCustomization.v1`. See
//  docs/superpowers/specs/2026-04-08-notch-customization-design.md
//  for the full architectural rationale.
//

import CoreGraphics
import Foundation

struct NotchCustomization: Codable, Equatable {
    // Appearance
    var theme: String               // was NotchThemeID; string IDs match old rawValues
    var fontScale: FontScale

    // Visibility toggles
    var showBuddy: Bool
    var showUsageBar: Bool

    // Geometry — all user-controlled via live edit mode.
    /// Upper bound for auto-expand. Idle content shrinks below this;
    /// long content expands up to this and truncates beyond.
    var maxWidth: CGFloat
    /// Signed horizontal offset from the screen's center (pinned to top).
    /// Render-time clamped; stored value preserved for later screen changes.
    var horizontalOffset: CGFloat

    // Hardware notch override
    var hardwareNotchMode: HardwareNotchMode

    // Plugin selections
    var buddyId: String
    var notificationSoundPlugin: String?
    var bgmPlugin: String?

    init(
        theme: String = "classic",
        fontScale: FontScale = .default,
        showBuddy: Bool = true,
        showUsageBar: Bool = true,
        maxWidth: CGFloat = 440,
        horizontalOffset: CGFloat = 0,
        hardwareNotchMode: HardwareNotchMode = .auto,
        buddyId: String = "pixel-cat",
        notificationSoundPlugin: String? = nil,
        bgmPlugin: String? = nil
    ) {
        self.theme = theme
        self.fontScale = fontScale
        self.showBuddy = showBuddy
        self.showUsageBar = showUsageBar
        self.maxWidth = maxWidth
        self.horizontalOffset = horizontalOffset
        self.hardwareNotchMode = hardwareNotchMode
        self.buddyId = buddyId
        self.notificationSoundPlugin = notificationSoundPlugin
        self.bgmPlugin = bgmPlugin
    }

    static let `default` = NotchCustomization()

    // MARK: - Forward-compat Codable
    //
    // Decoding with defaults for missing keys so that future schema
    // additions remain backward-compatible without bumping the v1
    // key. (The plan's "strict decoding" variant was a documentation
    // preference; forward-compat decoding is the pragmatic choice
    // for a Mac app shipping value types to user defaults.)

    private enum CodingKeys: String, CodingKey {
        case theme, fontScale, showBuddy, showUsageBar,
             maxWidth, horizontalOffset, hardwareNotchMode,
             buddyId, notificationSoundPlugin, bgmPlugin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // theme: decode as String; old NotchThemeID rawValues are already valid strings
        self.theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "classic"
        self.fontScale = try c.decodeIfPresent(FontScale.self, forKey: .fontScale) ?? .default
        self.showBuddy = try c.decodeIfPresent(Bool.self, forKey: .showBuddy) ?? true
        self.showUsageBar = try c.decodeIfPresent(Bool.self, forKey: .showUsageBar) ?? true
        self.maxWidth = try c.decodeIfPresent(CGFloat.self, forKey: .maxWidth) ?? 440
        self.horizontalOffset = try c.decodeIfPresent(CGFloat.self, forKey: .horizontalOffset) ?? 0
        self.hardwareNotchMode = try c.decodeIfPresent(HardwareNotchMode.self, forKey: .hardwareNotchMode) ?? .auto
        self.buddyId = try c.decodeIfPresent(String.self, forKey: .buddyId) ?? "pixel-cat"
        self.notificationSoundPlugin = try? c.decodeIfPresent(String.self, forKey: .notificationSoundPlugin)
        self.bgmPlugin = try? c.decodeIfPresent(String.self, forKey: .bgmPlugin)
    }
}

// NotchThemeID enum removed — replaced by ThemeRegistry + ThemeDefinition.
// Built-in theme IDs ("classic", "paper", "neonLime", "cyber", "mint", "sunset")
// are preserved as String values for UserDefaults backward compatibility.

/// Four-step relative font scale. String raw values for stable
/// persistence; `CGFloat` multiplier exposed via computed property
/// so we avoid the historical fragility of `Codable` on `CGFloat`
/// raw values.
enum FontScale: String, Codable, CaseIterable {
    case small    = "small"
    case `default` = "default"
    case large    = "large"
    case xLarge   = "xLarge"

    var multiplier: CGFloat {
        switch self {
        case .small:    return 0.85
        case .default:  return 1.0
        case .large:    return 1.15
        case .xLarge:   return 1.3
        }
    }
}

/// How CodeIsland treats the MacBook's physical notch when
/// computing the panel geometry.
///
/// `auto` — detect via `NSScreen.main?.safeAreaInsets.top > 0`.
/// `forceVirtual` — ignore any hardware notch and draw a
///   virtual, user-positionable overlay (useful on external
///   displays or when the user prefers a freely-resized notch
///   even on a notched Mac).
enum HardwareNotchMode: String, Codable {
    case auto
    case forceVirtual
}
