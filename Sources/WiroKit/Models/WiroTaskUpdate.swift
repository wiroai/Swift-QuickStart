import Foundation

/// Transport used by `WiroClient.subscribe` to track a submitted task.
public enum WiroTaskTrackingMode: String, Sendable, Equatable {
    /// Periodically requests the task detail endpoint.
    case polling
    /// Receives realtime task events over WebSocket.
    case webSocket
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
