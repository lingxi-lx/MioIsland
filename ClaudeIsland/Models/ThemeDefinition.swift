//
//  ThemeDefinition.swift
//  ClaudeIsland
//
//  Runtime theme definition. Built-in themes use IDs matching
//  the old NotchThemeID.rawValue for UserDefaults backward compat.
//

import SwiftUI

/// A theme definition that can come from built-in code or a plugin JSON.
struct ThemeDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let palette: NotchPalette
    let isBuiltIn: Bool

    /// Built-in themes — IDs match old NotchThemeID.rawValue exactly.
    static let builtIns: [ThemeDefinition] = [
        ThemeDefinition(
            id: "classic", name: "Classic",
            palette: NotchPalette(bg: .black, fg: .white, secondaryFg: Color(white: 1, opacity: 0.4)),
            isBuiltIn: true
        ),
        ThemeDefinition(
            id: "paper", name: "Paper",
            palette: NotchPalette(bg: .white, fg: .black, secondaryFg: Color(white: 0, opacity: 0.55)),
            isBuiltIn: true
        ),
        ThemeDefinition(
            id: "neonLime", name: "Neon Lime",
            palette: NotchPalette(bg: Color(hex: "CAFF00"), fg: .black, secondaryFg: Color(white: 0, opacity: 0.55)),
            isBuiltIn: true
        ),
        ThemeDefinition(
            id: "cyber", name: "Cyber",
            palette: NotchPalette(bg: Color(hex: "7C3AED"), fg: Color(hex: "F0ABFC"), secondaryFg: Color(hex: "C4B5FD")),
            isBuiltIn: true
        ),
        ThemeDefinition(
            id: "mint", name: "Mint",
            palette: NotchPalette(bg: Color(hex: "4ADE80"), fg: .black, secondaryFg: Color(white: 0, opacity: 0.55)),
            isBuiltIn: true
        ),
        ThemeDefinition(
            id: "sunset", name: "Sunset",
            palette: NotchPalette(bg: Color(hex: "FB923C"), fg: .black, secondaryFg: Color(white: 0, opacity: 0.5)),
            isBuiltIn: true
        ),
    ]
}
