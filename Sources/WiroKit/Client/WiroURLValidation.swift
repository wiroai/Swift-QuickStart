import Foundation

enum WiroURLValidation {
    enum Kind {
        case http
        case webSocket
    }

    static func validate(
        _ url: URL,
        kind: Kind,
        label: String
    ) throws {
        guard let scheme = url.scheme?.lowercased() else {
            throw WiroError.validation(
                message: "\(label) is missing a URL scheme.",
                statusCode: 0,
                responseBody: nil
            )
        }

        let allowed: Set<String>
        switch kind {
        case .http:
            allowed = ["http", "https"]
        case .webSocket:
            allowed = ["ws", "wss"]
        }

        guard allowed.contains(scheme) else {
            throw WiroError.validation(
                message:
                    "\(label) must use \(allowed.sorted().joined(separator: " or ")) scheme.",
                statusCode: 0,
                responseBody: nil
            )
        }

        guard let host = url.host, !host.isEmpty else {
            throw WiroError.validation(
                message: "\(label) must include a host.",
                statusCode: 0,
                responseBody: nil
            )
        }

        if url.user != nil || url.password != nil {
            throw WiroError.validation(
                message: "\(label) must not contain userinfo.",
                statusCode: 0,
                responseBody: nil
            )
        }

        if url.query != nil {
            throw WiroError.validation(
                message: "\(label) must not contain a query string.",
                statusCode: 0,
                responseBody: nil
            )
        }

        if url.fragment != nil {
            throw WiroError.validation(
                message: "\(label) must not contain a fragment.",
                statusCode: 0,
                responseBody: nil
            )
        }
    }

    static func trimmingTrailingSlashes(_ url: URL) -> URL {
        var string = url.absoluteString
        while string.count > 1, string.hasSuffix("/") {
            string.removeLast()
        }
        return URL(string: string) ?? url
    }
}
