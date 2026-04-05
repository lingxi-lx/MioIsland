//
//  TerminalWriter.swift
//  ClaudeIsland
//
//  Sends text to a Claude Code terminal session.
//  Used by the sync module to relay messages from the phone.
//

import Foundation
import os.log

/// Sends text input to a Claude Code terminal session.
@MainActor
final class TerminalWriter {

    static let logger = Logger(subsystem: "com.codeisland", category: "TerminalWriter")
    static let shared = TerminalWriter()

    private let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    private init() {}

    /// Send a text message to the terminal running the given session.
    func sendText(_ text: String, to session: SessionState) async -> Bool {
        let termApp = session.terminalApp?.lowercased() ?? ""

        // Try cmux first (most precise)
        if FileManager.default.isExecutableFile(atPath: cmuxPath) {
            if await sendViaCmux(text, session: session) {
                return true
            }
        }

        // Try AppleScript for known terminals
        if termApp.contains("iterm") {
            return sendViaAppleScript(text, script: """
                tell application "iTerm2"
                    tell current session of current tab of current window
                        write text "\(text.replacingOccurrences(of: "\"", with: "\\\""))"
                    end tell
                end tell
                """)
        }

        if termApp.contains("ghostty") {
            // Ghostty: use keystroke via System Events
            return sendViaAppleScript(text, script: """
                tell application "Ghostty" to activate
                delay 0.3
                tell application "System Events"
                    keystroke "\(text.replacingOccurrences(of: "\"", with: "\\\""))"
                    key code 36
                end tell
                """)
        }

        if termApp.contains("terminal") && !termApp.contains("wez") {
            return sendViaAppleScript(text, script: """
                tell application "Terminal"
                    do script "\(text.replacingOccurrences(of: "\"", with: "\\\""))" in selected tab of front window
                end tell
                """)
        }

        Self.logger.warning("No supported terminal for session \(session.sessionId.prefix(8))")
        return false
    }

    // MARK: - cmux

    private func sendViaCmux(_ text: String, session: SessionState) async -> Bool {
        let dirName = URL(fileURLWithPath: session.cwd).lastPathComponent
        let sid = String(session.sessionId.prefix(8))

        // Find workspace
        guard let wsOutput = cmuxRun(["list-workspaces"]) else { return false }

        var targetWsRef: String?
        for wsLine in wsOutput.components(separatedBy: "\n") where !wsLine.isEmpty {
            guard let wsRef = wsLine.components(separatedBy: " ").first(where: { $0.hasPrefix("workspace:") }) else { continue }
            guard let surfOutput = cmuxRun(["list-pane-surfaces", "--workspace", wsRef]) else { continue }
            if surfOutput.contains(sid) || surfOutput.contains(dirName) {
                targetWsRef = wsRef
                break
            }
        }

        guard let wsRef = targetWsRef else {
            Self.logger.debug("No matching cmux workspace for \(sid)")
            return false
        }

        // Send text + Enter
        let escaped = text.replacingOccurrences(of: "\n", with: "\r")
        _ = cmuxRun(["send", "--workspace", wsRef, "--", "\(escaped)\r"])
        Self.logger.info("Sent message to cmux workspace \(wsRef)")
        return true
    }

    private func cmuxRun(_ args: [String]) -> String? {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: cmuxPath)
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch { return nil }
    }

    // MARK: - AppleScript

    private func sendViaAppleScript(_ text: String, script: String) -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let success = process.terminationStatus == 0
            if success {
                Self.logger.info("Sent message via AppleScript")
            }
            return success
        } catch {
            return false
        }
    }
}
