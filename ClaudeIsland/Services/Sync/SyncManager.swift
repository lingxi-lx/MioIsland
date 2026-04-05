//
//  SyncManager.swift
//  ClaudeIsland
//
//  Top-level coordinator for CodeLight Server sync.
//  Manages connection lifecycle, message relay, and RPC execution.
//

import Combine
import Foundation
import os.log

/// Coordinates all CodeLight Server sync functionality.
/// Initialize once at app startup, connects/disconnects based on configuration.
@MainActor
final class SyncManager: ObservableObject {

    static let shared = SyncManager()
    static let logger = Logger(subsystem: "com.codeisland", category: "SyncManager")

    @Published private(set) var isEnabled = false
    @Published private(set) var connectionState: ServerConnectionState = .disconnected

    private var connection: ServerConnection?
    private var relay: MessageRelay?
    private var rpcExecutor: RPCExecutor?

    /// The server URL to connect to. Stored in UserDefaults.
    var serverUrl: String? {
        get { UserDefaults.standard.string(forKey: "codelight-server-url") }
        set {
            UserDefaults.standard.set(newValue, forKey: "codelight-server-url")
            if let url = newValue, !url.isEmpty {
                Task { await connectToServer(url: url) }
            } else {
                disconnectFromServer()
            }
        }
    }

    private init() {
        // Default server URL if not configured
        if serverUrl == nil {
            UserDefaults.standard.set("https://island.wdao.chat", forKey: "codelight-server-url")
        }
        // Auto-connect on startup if configured
        if let url = serverUrl, !url.isEmpty {
            Task { await connectToServer(url: url) }
        }
    }

    // MARK: - Connection Lifecycle

    func connectToServer(url: String) async {
        disconnectFromServer()

        let conn = ServerConnection(serverUrl: url)
        self.connection = conn

        do {
            try await conn.authenticate()
            conn.connect()

            // Handle messages from phone → type into terminal
            conn.onUserMessage = { [weak self] serverSessionId, messageText in
                Task { @MainActor in
                    await self?.handlePhoneMessage(serverSessionId: serverSessionId, text: messageText)
                }
            }

            // Wait for socket to actually connect before starting relay
            let relay = MessageRelay(connection: conn)
            self.relay = relay
            let rpc = RPCExecutor()
            self.rpcExecutor = rpc

            // Delay relay start to give socket time to connect
            Task { @MainActor in
                // Wait up to 5 seconds for socket connection
                for _ in 0..<50 {
                    if conn.isConnected { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }

                if conn.isConnected {
                    relay.startRelaying()
                    Self.logger.info("Relay started after socket connected")
                } else {
                    Self.logger.warning("Socket did not connect in time, starting relay anyway")
                    relay.startRelaying()
                }
            }

            isEnabled = true
            connectionState = .connected
            Self.logger.info("Sync enabled with \(url)")
        } catch {
            connectionState = .error(error.localizedDescription)
            Self.logger.error("Sync connection failed: \(error)")
        }
    }

    /// Handle a user message received from the phone — type it into the matching terminal
    private func handlePhoneMessage(serverSessionId: String, text: String) async {
        // Find the matching local session by checking relay's serverSessionIds
        // For now, find any active session and send to it
        let sessions = await SessionStore.shared.currentSessions()

        // Try to find session matching the server ID via relay's mapping
        if let relay = self.relay, let localId = relay.localSessionId(forServerId: serverSessionId) {
            if let session = sessions.first(where: { $0.sessionId == localId }) {
                let sent = await TerminalWriter.shared.sendText(text, to: session)
                Self.logger.info("Phone message → terminal: \(sent ? "success" : "failed")")
                return
            }
        }

        // Fallback: send to first active session
        if let session = sessions.first(where: { $0.phase != .ended }) {
            let sent = await TerminalWriter.shared.sendText(text, to: session)
            Self.logger.info("Phone message → terminal (fallback): \(sent ? "success" : "failed")")
        } else {
            Self.logger.warning("No active session to send phone message to")
        }
    }

    func disconnectFromServer() {
        relay?.stopRelaying()
        connection?.disconnect()
        connection = nil
        relay = nil
        rpcExecutor = nil
        isEnabled = false
        connectionState = .disconnected
    }

    /// Called when a QR code is scanned with server details
    func handlePairingQR(serverUrl: String, tempPublicKey: String, deviceName: String) async {
        UserDefaults.standard.set(serverUrl, forKey: "codelight-server-url")
        await connectToServer(url: serverUrl)
        Self.logger.info("Paired with \(deviceName) via QR")
    }
}
