//
//  ThemeRegistry.swift
//  ClaudeIsland
//
//  Runtime registry for themes. Replaces the compile-time
//  NotchThemeID enum with a dynamic collection that plugins
//  can register into.
//

import Combine
import SwiftUI

@MainActor
final class ThemeRegistry: ObservableObject {
    static let shared = ThemeRegistry()

    @Published private(set) var themes: [ThemeDefinition] = []

    init() {
        themes = ThemeDefinition.builtIns
    }

    func register(_ theme: ThemeDefinition) {
        themes.removeAll { $0.id == theme.id }
        themes.append(theme)
    }

    func unregister(_ id: String) {
        themes.removeAll { $0.id == id && !$0.isBuiltIn }
    }

    func palette(for id: String) -> NotchPalette {
        themes.first(where: { $0.id == id })?.palette
            ?? ThemeDefinition.builtIns[0].palette
    }

    func theme(for id: String) -> ThemeDefinition? {
        themes.first(where: { $0.id == id })
    }
}
