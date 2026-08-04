import Foundation

/// A frame received from a Wiro task WebSocket.
public enum WiroSocketEvent: Sendable, Equatable {
    /// A JSON lifecycle, progress, or output event.
    case message(WiroSocketMessage)
    /// A binary frame from a realtime model.
    case binary(Data)

    /// Whether this event ends a standard task stream.
    public var isTerminal: Bool {
        switch self {
        case .message(let message):
            return message.isTerminal
        case .binary:
            return false
        }
    }
}

/// A typed JSON event produced by WebSocket tracking.
public struct WiroSocketMessage: Sendable, Equatable {
    /// Server-side task identifier, when present.
    public let id: WiroTaskID?
    /// Task token associated with this stream, when present.
    public let taskToken: WiroTaskToken?
    /// Parsed lifecycle status from the frame `type` field.
    public let status: WiroTaskStatus
    /// Original status / frame type string.
    public let statusRawValue: String
    /// Whether Wiro marked this event as successful.
    public let result: Bool
    /// Typed `message` payload.
    public let payload: WiroSocketPayload
    /// Full raw payload for forward compatibility.
    public let raw: WiroJSON

    /// Whether this message represents a terminal task status.
    public var isTerminal: Bool { status.isTerminal }

    /// Plain log text when ``payload`` is ``WiroSocketPayload/log(_:)``.
    public var messageText: String? {
        if case .log(let text) = payload { return text }
        return nil
    }

    /// Parsed progress when ``payload`` is ``WiroSocketPayload/progress(_:)``.
    public var progress: WiroTaskProgress? {
        if case .progress(let progress) = payload { return progress }
        return nil
    }

    /// Final outputs when ``payload`` is ``WiroSocketPayload/outputs(_:)``.
    public var outputs: [WiroTaskOutput] {
        if case .outputs(let outputs) = payload { return outputs }
        return []
    }

    /// Creates a socket message.
    public init(
        id: WiroTaskID? = nil,
        taskToken: WiroTaskToken? = nil,
        status: WiroTaskStatus,
        statusRawValue: String,
        result: Bool = true,
        payload: WiroSocketPayload = .unknown(nil),
        raw: WiroJSON
    ) {
        self.id = id
        self.taskToken = taskToken
        self.status = status
        self.statusRawValue = statusRawValue
        self.result = result
        self.payload = payload
        self.raw = raw
    }

    /// Parses a socket message from a Wiro JSON object.
    public static func parse(_ json: WiroJSON) -> WiroSocketMessage {
        let statusRaw = JSONReader.string(json, "type") ?? ""
        let messageValue = json["message"]
        return WiroSocketMessage(
            id: JSONReader.string(json, "id").flatMap(WiroTaskID.init(rawValue:)),
            taskToken: JSONReader.string(json, "tasktoken")
                .flatMap(WiroTaskToken.init(rawValue:)),
            status: WiroTaskStatus.parse(statusRaw),
            statusRawValue: statusRaw,
            result: JSONReader.boolean(json, "result", fallback: false) ?? false,
            payload: WiroSocketPayload.parse(
                statusRawValue: statusRaw,
                message: messageValue
            ),
            raw: json
        )
    }
}

/// Typed content carried by a ``WiroSocketMessage``.
public enum WiroSocketPayload: Sendable, Equatable {
    /// Plain text log line.
    case log(String)
    /// Structured progress or streaming language-model chunks.
    case progress(WiroTaskProgress)
    /// Final task outputs (typically on completion).
    case outputs([WiroTaskOutput])
    /// Unrecognized payload preserved for forward compatibility.
    case unknown(WiroJSONValue?)

    static func parse(
        statusRawValue: String,
        message: WiroJSONValue?
    ) -> WiroSocketPayload {
        if statusRawValue == WiroTaskStatus.completed.apiValue {
            let outputs = JSONReader.objects(message).map {
                WiroTaskOutput.parse($0)
            }
            return .outputs(outputs)
        }

        if case .string(let text)? = message {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") {
                let object = JSONReader.map(message) ?? [:]
                if !object.isEmpty, object.keys.contains(where: progressKeys.contains) {
                    return .progress(WiroTaskProgress.parse(object))
                }
            }
            return .log(text)
        }

        if let object = JSONReader.map(message),
            object.keys.contains(where: progressKeys.contains)
        {
            return .progress(WiroTaskProgress.parse(object))
        }

        return .unknown(message)
    }

    private static let progressKeys: Set<String> = [
        "type",
        "task",
        "percentage",
        "stepCurrent",
        "stepTotal",
        "speed",
        "speedType",
        "elapsedTime",
        "remainingTime",
        "raw",
        "thinking",
        "answer",
        "isThinking",
    ]
}

/// Structured progress or language-model output carried by a socket event.
public struct WiroTaskProgress: Sendable, Equatable {
    /// Progress payload type.
    public let type: String?
    /// Human-readable task phase.
    public let task: String?
    /// Completion percentage.
    public let percentage: Double?
    /// Current generation step.
    public let currentStep: Int?
    /// Total generation steps.
    public let totalSteps: Int?
    /// Current generation speed.
    public let speed: String?
    /// Unit associated with ``speed``.
    public let speedType: String?
    /// Server-formatted elapsed duration.
    public let elapsedTime: String?
    /// Server-formatted estimated remaining duration.
    public let remainingTime: String?
    /// Complete accumulated raw output.
    public let rawText: String?
    /// Accumulated language-model reasoning chunks.
    public let thinking: [String]
    /// Accumulated language-model answer chunks.
    public let answers: [String]
    /// Whether a language model is currently producing reasoning.
    public let isThinking: Bool?
    /// Original progress payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates progress data.
    public init(
        type: String? = nil,
        task: String? = nil,
        percentage: Double? = nil,
        currentStep: Int? = nil,
        totalSteps: Int? = nil,
        speed: String? = nil,
        speedType: String? = nil,
        elapsedTime: String? = nil,
        remainingTime: String? = nil,
        rawText: String? = nil,
        thinking: [String] = [],
        answers: [String] = [],
        isThinking: Bool? = nil,
        raw: WiroJSON
    ) {
        self.type = type
        self.task = task
        self.percentage = percentage
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.speed = speed
        self.speedType = speedType
        self.elapsedTime = elapsedTime
        self.remainingTime = remainingTime
        self.rawText = rawText
        self.thinking = thinking
        self.answers = answers
        self.isThinking = isThinking
        self.raw = raw
    }

    /// Parses progress data from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroTaskProgress {
        WiroTaskProgress(
            type: JSONReader.string(json, "type"),
            task: JSONReader.string(json, "task"),
            percentage: JSONReader.double(json, "percentage"),
            currentStep: JSONReader.integer(json, "stepCurrent"),
            totalSteps: JSONReader.integer(json, "stepTotal"),
            speed: JSONReader.string(json, "speed"),
            speedType: JSONReader.string(json, "speedType"),
            elapsedTime: JSONReader.string(json, "elapsedTime"),
            remainingTime: JSONReader.string(json, "remainingTime"),
            rawText: JSONReader.string(json, "raw"),
            thinking: JSONReader.stringList(json, "thinking"),
            answers: JSONReader.stringList(json, "answer"),
            isThinking: JSONReader.boolean(json, "isThinking"),
            raw: json
        )
    }
}

extension WiroTaskUpdate {
    /// Creates a normalized update from a socket event.
    public static func from(socketEvent event: WiroSocketEvent) -> WiroTaskUpdate {
        switch event {
        case .message(let message):
            return .event(message)
        case .binary(let data):
            return .binary(data)
        }
    }
}
