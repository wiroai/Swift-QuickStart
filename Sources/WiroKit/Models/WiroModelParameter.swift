import Foundation

/// An option accepted by a select-like parameter.
public struct WiroModelParameterOption: Sendable, Equatable {
    /// Display label.
    public let label: String
    /// Value sent to the Wiro API.
    public let value: String

    /// Creates a model parameter option.
    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    /// Parses an option from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroModelParameterOption {
        WiroModelParameterOption(
            label: JSONReader.string(json, "label") ?? "",
            value: JSONReader.string(json, "value") ?? ""
        )
    }
}

/// Shared metadata carried by every model parameter kind.
public struct WiroModelParameterInfo: Sendable, Equatable {
    /// Parameter identifier sent to the API.
    public let name: String
    /// Display label.
    public let label: String
    /// Human-readable guidance.
    public let description: String?
    /// Whether callers must provide this parameter.
    public let isRequired: Bool
    /// Suggested input placeholder.
    public let placeholder: String?
    /// Additional usage note.
    public let note: String?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates parameter metadata.
    public init(
        name: String,
        label: String,
        description: String? = nil,
        isRequired: Bool,
        placeholder: String? = nil,
        note: String? = nil,
        raw: WiroJSON
    ) {
        self.name = name
        self.label = label
        self.description = description
        self.isRequired = isRequired
        self.placeholder = placeholder
        self.note = note
        self.raw = raw
    }
}

/// A model input parameter, discriminated by wire type.
public enum WiroModelParameter: Sendable, Equatable {
    /// A parameter constrained to one of a declared set of options.
    case select(
        info: WiroModelParameterInfo,
        options: [WiroModelParameterOption],
        defaultValue: String?
    )
    /// A numeric parameter with optional bounds and increment.
    case number(
        info: WiroModelParameterInfo,
        defaultValue: Double?,
        minimum: Double?,
        maximum: Double?,
        step: Double?
    )
    /// A single-line or multiline text parameter.
    case text(
        info: WiroModelParameterInfo,
        defaultValue: String?
    )
    /// A single, multiple, or combined file input parameter.
    case file(info: WiroModelParameterInfo)
    /// A parameter type introduced after this SDK version.
    case unknown(
        info: WiroModelParameterInfo,
        type: String,
        defaultValue: WiroJSONValue?
    )

    /// Shared metadata for this parameter.
    public var info: WiroModelParameterInfo {
        switch self {
        case .select(let info, _, _),
             .number(let info, _, _, _, _),
             .text(let info, _),
             .file(let info),
             .unknown(let info, _, _):
            return info
        }
    }

    /// Parameter identifier sent to the API.
    public var name: String { info.name }

    /// Whether callers must provide this parameter.
    public var isRequired: Bool { info.isRequired }

    /// Parses a parameter from a Wiro API payload.
    public static func parse(_ json: WiroJSON) -> WiroModelParameter {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroModelParameter {
        let type = JSONReader.string(json, "type") ?? ""
        let info = WiroModelParameterInfo(
            name: JSONReader.string(json, "id") ?? "",
            label: JSONReader.string(json, "label") ?? "",
            description: JSONReader.string(json, "description"),
            isRequired: JSONReader.boolean(
                json,
                "required",
                fallback: false
            ) ?? false,
            placeholder: JSONReader.string(json, "placeholder"),
            note: JSONReader.string(json, "note"),
            raw: json
        )
        let options = JSONReader.objects(
            json,
            "options",
            onMalformedJSON: onMalformedJSON
        ).map(WiroModelParameterOption.parse)

        switch type.lowercased() {
        case "select":
            return .select(
                info: info,
                options: options,
                defaultValue: JSONReader.string(json, "default")
            )
        case "range", "number", "numeric", "integer", "float":
            return .number(
                info: info,
                defaultValue: JSONReader.double(json, "default"),
                minimum: JSONReader.double(json, "min"),
                maximum: JSONReader.double(json, "max"),
                step: JSONReader.double(json, "step")
            )
        case "text", "textarea":
            return .text(
                info: info,
                defaultValue: JSONReader.string(json, "default")
            )
        case "fileinput", "multifileinput", "combinefileinput":
            return .file(info: info)
        default:
            return .unknown(
                info: info,
                type: type,
                defaultValue: json["default"]
            )
        }
    }
}

/// A visual group of model parameters.
public struct WiroModelParameterGroup: Sendable, Equatable {
    /// Group heading.
    public let title: String
    /// Parameters contained by this group.
    public let parameters: [WiroModelParameter]
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates a parameter group.
    public init(
        title: String,
        parameters: [WiroModelParameter],
        raw: WiroJSON
    ) {
        self.title = title
        self.parameters = parameters
        self.raw = raw
    }

    /// Parses a parameter group from a Wiro API payload.
    public static func parse(_ json: WiroJSON) -> WiroModelParameterGroup {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroModelParameterGroup {
        let parameters = JSONReader.objects(
            json,
            "items",
            onMalformedJSON: onMalformedJSON
        ).map {
            WiroModelParameter.parse($0, onMalformedJSON: onMalformedJSON)
        }
        return WiroModelParameterGroup(
            title: JSONReader.string(json, "title") ?? "",
            parameters: parameters,
            raw: json
        )
    }
}
