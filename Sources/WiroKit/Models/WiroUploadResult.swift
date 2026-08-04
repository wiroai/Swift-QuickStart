import Foundation

/// Result of a file upload to `/File/Upload`.
public struct WiroUploadResult: Sendable, Equatable {
    /// Whether Wiro accepted the upload.
    public let isSuccess: Bool
    /// Files created by the upload.
    public let files: [WiroUploadedFile]
    /// API errors returned with the response.
    public let errors: [WiroAPIError]
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates an upload result.
    public init(
        isSuccess: Bool,
        files: [WiroUploadedFile],
        errors: [WiroAPIError],
        raw: WiroJSON
    ) {
        self.isSuccess = isSuccess
        self.files = files
        self.errors = errors
        self.raw = raw
    }

    /// Parses an upload result from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroUploadResult {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroUploadResult {
        let files = JSONReader.objects(
            json,
            "list",
            onMalformedJSON: onMalformedJSON
        ).map {
            WiroUploadedFile.parse($0, onMalformedJSON: onMalformedJSON)
        }
        return WiroUploadResult(
            isSuccess: JSONReader.boolean(json, "result", fallback: false)
                ?? false,
            files: files,
            errors: WiroAPIError.parseList(
                from: json["errors"],
                onMalformedJSON: onMalformedJSON
            ),
            raw: json
        )
    }
}

/// A file stored by Wiro after an upload.
public struct WiroUploadedFile: Sendable, Equatable {
    /// Wiro file identifier.
    public let id: String
    /// Original file name.
    public let name: String?
    /// MIME content type.
    public let contentType: String?
    /// File size in bytes.
    public let size: Int?
    /// Public or authenticated file URL.
    public let url: URL?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates an uploaded file descriptor.
    public init(
        id: String = "",
        name: String? = nil,
        contentType: String? = nil,
        size: Int? = nil,
        url: URL? = nil,
        raw: WiroJSON
    ) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.size = size
        self.url = url
        self.raw = raw
    }

    /// Parses a file descriptor from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroUploadedFile {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroUploadedFile {
        WiroUploadedFile(
            id: JSONReader.string(json, "id") ?? "",
            name: JSONReader.string(json, "name"),
            contentType: JSONReader.string(json, "contenttype"),
            size: JSONReader.integer(json, "size"),
            url: JSONReader.url(json, "url"),
            raw: json
        )
    }
}
