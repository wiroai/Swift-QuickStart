import Foundation

/// Structured output returned by text and language models.
public struct WiroTaskOutputContent: Sendable, Equatable {
    /// Original input prompt.
    public let prompt: String?
    /// Unstructured model response.
    public let rawText: String?
    /// Model reasoning chunks, when provided.
    public let thinking: [String]
    /// Final answer chunks.
    public let answers: [String]

    /// Creates structured task output.
    public init(
        prompt: String? = nil,
        rawText: String? = nil,
        thinking: [String] = [],
        answers: [String] = []
    ) {
        self.prompt = prompt
        self.rawText = rawText
        self.thinking = thinking
        self.answers = answers
    }

    /// Parses structured output from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroTaskOutputContent {
        WiroTaskOutputContent(
            prompt: JSONReader.string(json, "prompt"),
            rawText: JSONReader.string(json, "raw"),
            thinking: JSONReader.stringList(json, "thinking"),
            answers: JSONReader.stringList(json, "answer")
        )
    }
}

/// A file or structured value produced by a Wiro task.
public struct WiroTaskOutput: Sendable, Equatable {
    /// Output file name.
    public let name: String?
    /// MIME type or Wiro output type.
    public let contentType: String
    /// Server-provided output size.
    public let size: Int?
    /// URL of a generated file.
    public let url: URL?
    /// Structured text output.
    public let content: WiroTaskOutputContent?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates a task output.
    public init(
        name: String? = nil,
        contentType: String,
        size: Int? = nil,
        url: URL? = nil,
        content: WiroTaskOutputContent? = nil,
        raw: WiroJSON
    ) {
        self.name = name
        self.contentType = contentType
        self.size = size
        self.url = url
        self.content = content
        self.raw = raw
    }

    /// Whether this output contains image media.
    public var isImage: Bool {
        contentType.lowercased().hasPrefix("image/")
    }

    /// Whether this output contains video media.
    public var isVideo: Bool {
        contentType.lowercased().hasPrefix("video/")
    }

    /// Whether this output contains audio media.
    public var isAudio: Bool {
        contentType.lowercased().hasPrefix("audio/")
    }

    /// Whether this output contains text or structured raw text.
    public var isText: Bool {
        let normalized = contentType.lowercased()
        return normalized.hasPrefix("text/")
            || normalized == "raw"
            || normalized == "application/json"
    }

    /// Parses a task output from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroTaskOutput {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroTaskOutput {
        let contentJSON = JSONReader.map(
            json,
            "content",
            onMalformedJSON: onMalformedJSON
        )
        return WiroTaskOutput(
            name: JSONReader.string(json, "name"),
            contentType: JSONReader.string(json, "contenttype") ?? "",
            size: JSONReader.integer(json, "size"),
            url: JSONReader.url(json, "url"),
            content: contentJSON.flatMap { object in
                object.isEmpty ? nil : WiroTaskOutputContent.parse(object)
            },
            raw: json
        )
    }
}
