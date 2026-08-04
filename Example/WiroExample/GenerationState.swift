import Foundation

/// Sealed UI state for the generate-image demo.
enum GenerationState: Equatable {
    case idle
    case running(status: String)
    case succeeded(outputs: [URL])
    case failed(message: String)
}
