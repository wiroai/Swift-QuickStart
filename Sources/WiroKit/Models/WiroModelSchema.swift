import Foundation

/// Full input schema for a Wiro model.
public struct WiroModelSchema: Sendable, Equatable {
    /// Model described by this schema.
    public let model: WiroModel
    /// Parameter groups in display order.
    public let parameterGroups: [WiroModelParameterGroup]
    /// Optional model documentation.
    public let readme: String?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates a model schema.
    public init(
        model: WiroModel,
        parameterGroups: [WiroModelParameterGroup],
        readme: String? = nil,
        raw: WiroJSON
    ) {
        self.model = model
        self.parameterGroups = parameterGroups
        self.readme = readme
        self.raw = raw
    }

    /// All model parameters in display order.
    public var parameters: [WiroModelParameter] {
        parameterGroups.flatMap(\.parameters)
    }

    /// Parses a schema from a model-detail payload.
    public static func parse(_ json: WiroJSON) -> WiroModelSchema {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroModelSchema {
        let groups = JSONReader.objects(
            json,
            "parameters",
            onMalformedJSON: onMalformedJSON
        ).map {
            WiroModelParameterGroup.parse(
                $0,
                onMalformedJSON: onMalformedJSON
            )
        }
        return WiroModelSchema(
            model: WiroModel.parse(json, onMalformedJSON: onMalformedJSON),
            parameterGroups: groups,
            readme: JSONReader.string(json, "readme"),
            raw: json
        )
    }

    /// Validates dynamic `parameters` against this model schema.
    ///
    /// Unknown key names are allowed. Returns human-readable problems for
    /// missing required fields and select/number constraint mismatches.
    /// Text, file, and unknown parameter kinds are not type-checked here.
    public func validate(_ parameters: WiroJSON) -> [String] {
        var errors: [String] = []

        for parameter in self.parameters {
            let isPresent =
                parameters[parameter.name] != nil
                && parameters[parameter.name] != .null

            if parameter.isRequired && !isPresent {
                errors.append("\(parameter.name) is required")
                continue
            }
            guard isPresent else { continue }

            let value = parameters[parameter.name]
            switch parameter {
            case .select(let info, let options, _):
                let optionValues = Set(options.map(\.value))
                let selected = JSONReader.string(value)
                if let selected, optionValues.contains(selected) {
                    break
                }
                let joined = options.map(\.value).joined(separator: ", ")
                errors.append(
                    "\(info.name) must be one of: \(joined)"
                )

            case .number(let info, _, let minimum, let maximum, _):
                guard let number = JSONReader.double(value) else {
                    errors.append("\(info.name) must be numeric")
                    continue
                }
                if let minimum, number < minimum {
                    errors.append(
                        "\(info.name) must be at least \(formatNumber(minimum))"
                    )
                }
                if let maximum, number > maximum {
                    errors.append(
                        "\(info.name) must be at most \(formatNumber(maximum))"
                    )
                }

            case .text, .file, .unknown:
                break
            }
        }

        return errors
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value, value.isFinite {
            return String(Int(value))
        }
        return String(value)
    }
}
