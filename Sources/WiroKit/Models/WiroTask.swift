import Foundation

/// A task running on Wiro.
public struct WiroTask: Sendable, Equatable {
    /// Server-side task identifier, or `nil` when Wiro omitted it.
    public let id: WiroTaskID?
    /// Token used for polling and subscriptions, or `nil` when omitted.
    public let taskToken: WiroTaskToken?
    /// Dynamic parameters supplied to the model.
    public let parameters: WiroJSON
    /// Parsed lifecycle status.
    public let status: WiroTaskStatus
    /// Original status value, including values unknown to this SDK.
    public let statusRawValue: String
    /// Model process exit code from `pexit`. `0` means success.
    public let exitCode: Int?
    /// Combined model diagnostic output.
    public let debugOutput: String?
    /// Server-provided start timestamp.
    public let startTime: Date?
    /// Server-provided end timestamp.
    public let endTime: Date?
    /// Total task duration.
    public let elapsed: Duration?
    /// Final billed cost.
    public let totalCost: Double?
    /// Files or structured values produced by the task.
    public let outputs: [WiroTaskOutput]
    /// Model description captured with the task.
    public let modelDescription: String?
    /// Model owner captured with the task.
    public let modelOwner: String?
    /// Model slug captured with the task.
    public let modelSlug: String?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates a Wiro task.
    public init(
        id: WiroTaskID? = nil,
        taskToken: WiroTaskToken? = nil,
        parameters: WiroJSON = [:],
        status: WiroTaskStatus,
        statusRawValue: String,
        exitCode: Int? = nil,
        debugOutput: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        elapsed: Duration? = nil,
        totalCost: Double? = nil,
        outputs: [WiroTaskOutput] = [],
        modelDescription: String? = nil,
        modelOwner: String? = nil,
        modelSlug: String? = nil,
        raw: WiroJSON
    ) {
        self.id = id
        self.taskToken = taskToken
        self.parameters = parameters
        self.status = status
        self.statusRawValue = statusRawValue
        self.exitCode = exitCode
        self.debugOutput = debugOutput
        self.startTime = startTime
        self.endTime = endTime
        self.elapsed = elapsed
        self.totalCost = totalCost
        self.outputs = outputs
        self.modelDescription = modelDescription
        self.modelOwner = modelOwner
        self.modelSlug = modelSlug
        self.raw = raw
    }

    /// Whether the task no longer needs polling.
    public var isFinished: Bool { status.isTerminal }

    /// A completed task succeeds only when its process exit code is `0`.
    public var isSuccessful: Bool {
        status == .completed && exitCode == 0
    }

    /// Parses a task from a Wiro API payload.
    public static func parse(_ json: WiroJSON) -> WiroTask {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroTask {
        let statusRawValue = JSONReader.string(json, "status") ?? ""
        let outputValue = json["outputs"] ?? json["output"]
        let outputs = JSONReader.objects(
            outputValue,
            onMalformedJSON: onMalformedJSON
        ).map {
            WiroTaskOutput.parse($0, onMalformedJSON: onMalformedJSON)
        }

        let idString = JSONReader.string(json, "id")
            ?? JSONReader.string(json, "taskid")

        return WiroTask(
            id: idString.flatMap(WiroTaskID.init(rawValue:)),
            taskToken: JSONReader.string(json, "socketaccesstoken")
                .flatMap(WiroTaskToken.init(rawValue:)),
            parameters: JSONReader.map(
                json,
                "parameters",
                onMalformedJSON: onMalformedJSON
            ) ?? [:],
            status: WiroTaskStatus.parse(statusRawValue),
            statusRawValue: statusRawValue,
            exitCode: JSONReader.integer(json, "pexit"),
            debugOutput: JSONReader.string(json, "debugoutput"),
            startTime: JSONReader.date(json, "starttime"),
            endTime: JSONReader.date(json, "endtime"),
            elapsed: durationFromSeconds(json["elapsedseconds"]),
            totalCost: JSONReader.double(json, "totalcost"),
            outputs: outputs,
            modelDescription: JSONReader.string(json, "modeldescription"),
            modelOwner: JSONReader.string(json, "modelslugowner"),
            modelSlug: JSONReader.string(json, "modelslugproject"),
            raw: json
        )
    }

    private static func durationFromSeconds(
        _ value: WiroJSONValue?
    ) -> Duration? {
        guard let seconds = JSONReader.double(value), seconds.isFinite else {
            return nil
        }
        let milliseconds = (seconds * 1000).rounded()
        return .milliseconds(Int64(milliseconds))
    }
}
