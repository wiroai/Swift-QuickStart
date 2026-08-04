import Foundation

/// Lifecycle state of a Wiro task.
public enum WiroTaskStatus: Sendable, Equatable, Hashable {
    /// Waiting for an available worker (`task_queue`).
    case queued
    /// Accepted by a worker (`task_accept`).
    case accepted
    /// Preparing inputs (`task_preprocess_start`).
    case preprocessing
    /// Input preparation finished (`task_preprocess_end`).
    case preprocessed
    /// Assigned to a worker (`task_assign`).
    case assigned
    /// Model process is running (`task_start`).
    case running
    /// Model produced an incremental output (`task_output`).
    case output
    /// Complete standard output is available (`task_output_full`).
    case outputComplete
    /// Model produced an incremental error log (`task_error`).
    case errorOutput
    /// Complete error log is available (`task_error_full`).
    case errorOutputComplete
    /// Model process exited (`task_end`).
    case processEnded
    /// Output files are being prepared (`task_postprocess_start`).
    case postProcessing
    /// Post-processing finished (`task_postprocess_end`) — terminal.
    case completed
    /// Task was cancelled or killed (`task_cancel`) — terminal.
    case cancelled
    /// A realtime stream is ready (`task_stream_ready`).
    case streamReady
    /// A realtime stream ended (`task_stream_end`).
    case streamEnded
    /// Status introduced after this SDK version.
    case unknown(String)

    /// Resolves a Wiro status string without throwing on future values.
    public static func parse(_ rawValue: String) -> WiroTaskStatus {
        switch rawValue {
        case "task_queue": return .queued
        case "task_accept": return .accepted
        case "task_preprocess_start": return .preprocessing
        case "task_preprocess_end": return .preprocessed
        case "task_assign": return .assigned
        case "task_start": return .running
        case "task_output": return .output
        case "task_output_full": return .outputComplete
        case "task_error": return .errorOutput
        case "task_error_full": return .errorOutputComplete
        case "task_end": return .processEnded
        case "task_postprocess_start": return .postProcessing
        case "task_postprocess_end": return .completed
        case "task_cancel": return .cancelled
        case "task_stream_ready": return .streamReady
        case "task_stream_end": return .streamEnded
        default: return .unknown(rawValue)
        }
    }

    /// Status value returned by the Wiro API.
    public var apiValue: String {
        switch self {
        case .queued: return "task_queue"
        case .accepted: return "task_accept"
        case .preprocessing: return "task_preprocess_start"
        case .preprocessed: return "task_preprocess_end"
        case .assigned: return "task_assign"
        case .running: return "task_start"
        case .output: return "task_output"
        case .outputComplete: return "task_output_full"
        case .errorOutput: return "task_error"
        case .errorOutputComplete: return "task_error_full"
        case .processEnded: return "task_end"
        case .postProcessing: return "task_postprocess_start"
        case .completed: return "task_postprocess_end"
        case .cancelled: return "task_cancel"
        case .streamReady: return "task_stream_ready"
        case .streamEnded: return "task_stream_end"
        case .unknown(let raw): return raw
        }
    }

    /// Whether no more polling is required.
    public var isTerminal: Bool {
        self == .completed || self == .cancelled
    }
}
