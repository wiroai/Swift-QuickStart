import Foundation

/// Decodes Wiro REST response envelopes into success JSON or `WiroError`.
enum WiroResponseEnvelope {
    static func decodeSuccessObject(
        data: Data,
        statusCode: Int,
        retryAfter: TimeInterval? = nil
    ) throws -> WiroJSON {
        let bodyString = String(data: data, encoding: .utf8)

        if data.isEmpty {
            if (200...299).contains(statusCode) {
                return [:]
            }
            throw mapHTTPError(
                statusCode: statusCode,
                message: "Wiro API request failed.",
                retryAfter: retryAfter,
                responseBody: bodyString
            )
        }

        let decoded: WiroJSONValue
        do {
            decoded = try JSONDecoder().decode(
                WiroJSONValue.self,
                from: data
            )
        } catch {
            if (200...299).contains(statusCode) {
                throw WiroError.unknownAPI(
                    message: bodyString ?? "Wiro API request failed.",
                    statusCode: statusCode,
                    responseBody: bodyString
                )
            }
            throw mapHTTPError(
                statusCode: statusCode,
                message: bodyString ?? "Wiro API request failed.",
                retryAfter: retryAfter,
                responseBody: bodyString
            )
        }

        guard case .object(let object) = decoded else {
            throw WiroError.unknownAPI(
                message: "Wiro API returned a non-object JSON body.",
                statusCode: statusCode,
                responseBody: bodyString
            )
        }

        if (200...299).contains(statusCode) {
            if JSONReader.boolean(object, "result") == false {
                let message = extractMessage(from: object)
                    ?? "Wiro API request failed."
                throw WiroError.apiResult(
                    message: message,
                    code: extractCode(from: object),
                    statusCode: statusCode,
                    responseBody: bodyString
                )
            }
            return object
        }

        let message = extractMessage(from: object)
            ?? "Wiro API request failed."
        throw mapHTTPError(
            statusCode: statusCode,
            message: message,
            retryAfter: retryAfter,
            responseBody: bodyString
        )
    }

    static func mapHTTPError(
        statusCode: Int,
        message: String,
        retryAfter: TimeInterval?,
        responseBody: String?
    ) -> WiroError {
        switch statusCode {
        case 401, 403:
            return .authentication(
                message: message,
                statusCode: statusCode,
                responseBody: responseBody
            )
        case 400, 422:
            return .validation(
                message: message,
                statusCode: statusCode,
                responseBody: responseBody
            )
        case 429:
            return .rateLimited(
                message: message,
                statusCode: statusCode,
                retryAfter: retryAfter,
                responseBody: responseBody
            )
        default:
            return .unknownAPI(
                message: message,
                statusCode: statusCode,
                responseBody: responseBody
            )
        }
    }

    static func extractMessage(from object: WiroJSON) -> String? {
        if let errors = JSONReader.list(object, "errors"),
           let first = errors.first,
           case .object(let errorObject) = first,
           let message = JSONReader.string(errorObject, "message"),
           !message.isEmpty
        {
            return message
        }
        if let message = JSONReader.string(object, "message"),
           !message.isEmpty
        {
            return message
        }
        return nil
    }

    static func extractCode(from object: WiroJSON) -> String? {
        guard let errors = JSONReader.list(object, "errors"),
              let first = errors.first,
              case .object(let errorObject) = first
        else {
            return nil
        }
        if let code = JSONReader.string(errorObject, "code") {
            return code
        }
        if let code = JSONReader.integer(errorObject, "code") {
            return String(code)
        }
        return nil
    }

    static func retryAfterInterval(
        from response: HTTPURLResponse
    ) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let seconds = TimeInterval(raw),
            seconds >= 0
        else {
            return nil
        }
        return seconds
    }
}
