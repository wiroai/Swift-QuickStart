import Foundation

/// A file passed to a model parameter.
///
/// Wiro models receive files by URL. Wrap an already-hosted file with
/// ``url(_:)``, or wrap device-local bytes with ``data(_:fileName:)``
/// and the client uploads them automatically before the model runs.
///
/// Embed file inputs in ``WiroJSON`` via ``WiroJSONValue/fileInput(_:)``.
/// That case is intentionally **not** JSON-encodable — encoding it
/// throws a programmer error. ``WiroClient/runModel`` deep-walks
/// parameters, uploads `.data` inputs, and replaces every file input
/// with a URL string before the `/Run` request is sent.
///
/// ```swift
/// let parameters: WiroJSON = [
///     "prompt": "a cat",
///     "inputImage": [
///         .fileInput(.url(URL(string: "https://example.com/cat.png")!)),
///         .fileInput(.data(localBytes, fileName: "cat.png")),
///     ],
/// ]
/// ```
public enum WiroFileInput: Sendable, Equatable {
    /// A file that is already reachable at `url`.
    case url(URL)

    /// Device-local bytes the client uploads before the model runs.
    ///
    /// `fileName` must keep its extension (for example `photo.png`) so
    /// Wiro can serve the upload with the right content type. Empty
    /// names are rejected at upload time.
    case data(Data, fileName: String)

    /// Value placed in the request JSON for URL inputs.
    ///
    /// Bytes inputs have no wire value until uploaded.
    public var wireValue: String? {
        switch self {
        case .url(let url):
            return url.absoluteString
        case .data:
            return nil
        }
    }
}
