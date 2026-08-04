import Foundation

/// Result returned immediately after starting a model.
public struct WiroRunResult: Sendable, Equatable {
    /// Whether Wiro accepted the model run.
    public let isSuccess: Bool
    /// Server-side task identifier, or `nil` when Wiro omitted it.
    public let taskID: WiroTaskID?
    /// Token used to poll or subscribe (`socketaccesstoken`).
    public let taskToken: WiroTaskToken?
    /// API errors returned with the response.
    public let errors: [WiroAPIError]
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates a model-run result.
    public init(
        isSuccess: Bool,
        taskID: WiroTaskID?,
        taskToken: WiroTaskToken?,
        errors: [WiroAPIError],
        raw: WiroJSON
    ) {
        self.isSuccess = isSuccess
        self.taskID = taskID
        self.taskToken = taskToken
        self.errors = errors
        self.raw = raw
    }

    /// Parses a model-run result from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroRunResult {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroRunResult {
        WiroRunResult(
            isSuccess: JSONReader.boolean(json, "result", fallback: false)
                ?? false,
            taskID: JSONReader.string(json, "taskid")
                .flatMap(WiroTaskID.init(rawValue:)),
            taskToken: JSONReader.string(json, "socketaccesstoken")
                .flatMap(WiroTaskToken.init(rawValue:)),
            errors: WiroAPIError.parseList(
                from: json["errors"],
                onMalformedJSON: onMalformedJSON
            ),
            raw: json
        )
    }
}

/// Reason a subscribed Wiro task did not succeed.
public enum WiroTaskFailureReason: String, Sendable, Equatable {
    /// The task was cancelled or killed before completing.
    case cancelled
    /// The model process exited with a non-zero exit code.
    case nonZeroExit
    /// The task ended in an unrecognized non-successful state.
    case other
}

/// Terminal result of a subscribed Wiro task.
public enum WiroTaskResult: Sendable, Equatable {
    /// A subscribed task that completed successfully.
    case success(WiroTask)
    /// A subscribed task that reached a non-successful terminal state.
    case failure(WiroTask, WiroTaskFailureReason)

    /// The terminal task returned by Wiro.
    public var task: WiroTask {
        switch self {
        case .success(let task), .failure(let task, _):
            return task
        }
    }

    /// Builds a typed result from a terminal task.
    public static func from(task: WiroTask) -> WiroTaskResult {
        if task.isSuccessful {
            return .success(task)
        }
        let reason: WiroTaskFailureReason
        switch task.status {
        case .cancelled:
            reason = .cancelled
        case .completed where task.exitCode != 0:
            reason = .nonZeroExit
        default:
            reason = .other
        }
        return .failure(task, reason)
    }
}
