//
//  NotchTheme.swift
//  ClaudeIsland
//
//  Palette definitions for the six built-in notch themes. Palette
//  colors drive the notch background, primary foreground (text,
//  icons), and the dimmer secondary foreground (timestamps,
//  percentage indicators). Status colors (success / warning / error)
//  are intentionally NOT part of the palette — they preserve
//  semantic meaning across themes and live in Assets.xcassets
//  under NotchStatus/.
//
//  Spec: docs/superpowers/specs/2026-04-08-notch-customization-design.md
//  section 5.3.
//

import SwiftUI

struct NotchPalette: Equatable {
    let bg: Color
    let fg: Color
    let secondaryFg: Color
}

extension NotchPalette {
    /// Lookup the palette for a given theme ID string.
    /// Delegates to ThemeRegistry for both built-in and plugin themes.
    static func `for`(_ id: String) -> NotchPalette {
        ThemeRegistry.shared.palette(for: id)
    }
}
