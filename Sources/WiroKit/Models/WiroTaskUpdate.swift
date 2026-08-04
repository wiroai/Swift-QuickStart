import Foundation

/// Transport used by `WiroClient.subscribe` to track a submitted task.
public enum WiroTaskTrackingMode: String, Sendable, Equatable {
    /// Periodically requests the task detail endpoint.
    case polling
    /// Receives realtime task events over WebSocket.
    case webSocket
}

/// A typed JSON event produced by WebSocket tracking.
///
/// Fully wired in Step 8. Declared now so ``WiroTaskUpdate`` can reference
/// it; construction stays internal until the socket client lands.
public struct WiroSocketMessage: Sendable, Equatable {
    /// Parsed lifecycle status from the frame `type` field.
    public let status: WiroTaskStatus
    /// Original status / frame type string.
    public let statusRawValue: String
    /// Full raw payload for forward compatibility.
    public let raw: WiroJSON

    /// Whether this message represents a terminal task status.
    public var isTerminal: Bool { status.isTerminal }

    /// Internal constructor used by WebSocket parsing (Step 8).
    init(status: WiroTaskStatus, statusRawValue: String, raw: WiroJSON) {
        self.status = status
        self.statusRawValue = statusRawValue
        self.raw = raw
    }
}

/// A normalized task update produced by polling or WebSocket tracking.
public enum WiroTaskUpdate: Sendable, Equatable {
    /// A complete task snapshot produced by polling.
    case snapshot(WiroTask)
    /// A typed JSON event produced by WebSocket tracking.
    case event(WiroSocketMessage)
    /// A binary frame produced by WebSocket tracking.
    case binary(Data)

    /// Whether this update represents the end of a standard task.
    public var isTerminal: Bool {
        switch self {
        case .snapshot(let task):
            return task.status.isTerminal
        case .event(let message):
            return message.isTerminal
        case .binary:
            return false
        }
    }

    /// Parsed lifecycle status when available.
    public var status: WiroTaskStatus? {
        switch self {
        case .snapshot(let task):
            return task.status
        case .event(let message):
            return message.status
        case .binary:
            return nil
        }
    }
}
