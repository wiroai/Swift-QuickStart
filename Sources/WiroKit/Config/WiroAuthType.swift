import Foundation

/// How `WiroClient` authenticates REST requests.
public enum WiroAuthType: String, Sendable, Equatable {
    /// `x-api-key` only.
    case apiKey
    /// `x-api-key` plus HMAC-SHA256 `x-nonce` / `x-signature`.
    case signature
    /// Caller-supplied static headers; no Wiro credentials on device.
    case proxy
}
