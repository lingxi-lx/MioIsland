//
//  AskUserQuestionView.swift
//  ClaudeIsland
//
//  Interactive UI for answering AskUserQuestion prompts from Claude Code.
//  Sends the selected option index to the terminal via AppleScript / cmux.
//

import SwiftUI

struct AskUserQuestionView: View {
    let session: SessionState
    let context: QuestionContext
    @ObservedObject var sessionMonitor: ClaudeSessionMonitor
    @State private var otherText: String = ""
    @State private var showOther: Bool = false
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            questionsList
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(session.projectName)
                .notchFont(11, weight: .semibold)
                .notchSecondaryForeground()
            Spacer()
            Button {
                Task { await TerminalJumper.shared.jump(to: session) }
            } label: {
                Image(systemName: "terminal")
                    .notchFont(9)
                    .foregroundColor(TerminalColors.amber.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TerminalColors.amber.opacity(0.08))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Questions

    private var questionsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(context.questions.enumerated()), id: \.offset) { _, question in
                    questionBlock(question: question)
                }
            }
        }
    }

    @ViewBuilder
    private func questionBlock(question: QuestionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Question text
            Text(question.question)
                .notchFont(12, weight: .semibold)
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 2)

            // Options — vertical list
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                optionRow(index: index + 1, option: option)
            }

            // "Other" row
            otherRow(optionCount: question.options.count)
        }
    }

    private func optionRow(index: Int, option: QuestionOption) -> some View {
        Button {
            DebugLogger.log("AskUser", "Option \(index) tapped: \(option.label)")
            Task { await sendOptionToTerminal(index: index) }
        } label: {
            HStack(spacing: 8) {
                Text("\(index)")
                    .notchFont(10, weight: .bold)
                    .foregroundColor(TerminalColors.amber)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TerminalColors.amber.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label)
                        .notchFont(11, weight: .medium)
                        .foregroundColor(.white.opacity(0.85))

                    if let desc = option.description, !desc.isEmpty {
                        Text(desc)
                            .notchFont(9, weight: .regular)
                            .foregroundColor(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .notchFont(8)
                    .foregroundColor(.white.opacity(hoveredIndex == index ? 0.5 : 0.15))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hoveredIndex == index ? TerminalColors.amber.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                hoveredIndex == index ? TerminalColors.amber.opacity(0.2) : Color.white.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hoveredIndex = isHovered ? index : nil
        }
    }

    private func otherRow(optionCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showOther.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showOther ? "chevron.down" : "chevron.right")
                        .notchFont(8)
                        .foregroundColor(TerminalColors.amber.opacity(0.5))
                        .frame(width: 18, height: 18)

                    Text("Other...")
                        .notchFont(10, weight: .regular)
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showOther {
                HStack(spacing: 6) {
                    TextField("Type your answer", text: $otherText)
                        .textFieldStyle(.plain)
                        .notchFont(11)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                        .onSubmit { submitOther(optionCount: optionCount) }

                    Button {
                        submitOther(optionCount: optionCount)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(
                                otherText.isEmpty
                                    ? Color.white.opacity(0.15)
                                    : TerminalColors.amber
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(otherText.isEmpty)
                }
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Terminal Sending

    private func submitOther(optionCount: Int) {
        guard !otherText.isEmpty else { return }
        // "Other" is the last option in the list (optionCount + 1)
        // Then type the custom text
        DebugLogger.log("AskUser", "Other tapped, sending index \(optionCount + 1) + text")
        Task {
            await sendOptionToTerminal(index: optionCount + 1)
            // Small delay for the "Other" prompt to appear, then type the text
            try? await Task.sleep(nanoseconds: 300_000_000)
            await sendTextToTerminal(otherText)
        }
    }

    private func sendOptionToTerminal(index: Int) async {
        let termApp = session.terminalApp?.lowercased() ?? ""

        if termApp.contains("iterm") {
            let script = """
            tell application "iTerm2"
                tell current session of current tab of current window
                    write text "\(index)"
                end tell
            end tell
            """
            if runAppleScript(script) {
                DebugLogger.log("AskUser", "Sent \(index) via iTerm2")
                return
            }
        }

        if termApp.contains("terminal") && !termApp.contains("wez") {
            let script = """
            tell application "Terminal"
                do script "\(index)" in selected tab of front window
            end tell
            """
            if runAppleScript(script) {
                DebugLogger.log("AskUser", "Sent \(index) via Terminal.app")
                return
            }
        }

        guard CmuxTreeParser.isAvailable else {
            DebugLogger.log("AskUser", "No supported terminal, jumping")
            await TerminalJumper.shared.jump(to: session)
            return
        }

        let sent = CmuxTreeParser.sendText("\(index)\r", toCwd: session.cwd)
        DebugLogger.log("AskUser", "Sent \(index) to cmux: \(sent)")
    }

    private func sendTextToTerminal(_ text: String) async {
        let termApp = session.terminalApp?.lowercased() ?? ""
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")

        if termApp.contains("iterm") {
            let script = """
            tell application "iTerm2"
                tell current session of current tab of current window
                    write text "\(escaped)"
                end tell
            end tell
            """
            if runAppleScript(script) { return }
        }

        if termApp.contains("terminal") && !termApp.contains("wez") {
            let script = """
            tell application "Terminal"
                do script "\(escaped)" in selected tab of front window
            end tell
            """
            if runAppleScript(script) { return }
        }

        if CmuxTreeParser.isAvailable {
            _ = CmuxTreeParser.sendText("\(text)\r", toCwd: session.cwd)
        }
    }

    private func runAppleScript(_ script: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
