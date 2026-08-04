import Foundation

/// Builds `multipart/form-data` bodies for `/File/Upload`.
enum MultipartFormData {
    /// A built multipart body ready to send.
    struct Body: Sendable {
        var boundary: String
        var data: Data
        var contentType: String {
            "multipart/form-data; boundary=\(boundary)"
        }
    }

    /// Builds a single-file multipart body with part name `"file"`.
    static func buildFilePart(
        data: Data,
        fileName: String,
        boundary: String = makeBoundary()
    ) -> Body {
        var body = Data()
        append(
            &body,
            "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"file\"; "
                + "filename=\"\(escapeFileName(fileName))\"\r\n"
                + "Content-Type: application/octet-stream\r\n"
                + "\r\n"
        )
        body.append(data)
        append(&body, "\r\n--\(boundary)--\r\n")
        return Body(boundary: boundary, data: body)
    }

    /// Writes a single-file multipart body to `destination`, streaming
    /// `sourceFile` contents without loading them fully into memory.
    static func writeFilePart(
        from sourceFile: URL,
        fileName: String,
        to destination: URL,
        boundary: String = makeBoundary()
    ) throws -> String {
        FileManager.default.createFile(
            atPath: destination.path,
            contents: nil
        )
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        let preamble =
            "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"file\"; "
            + "filename=\"\(escapeFileName(fileName))\"\r\n"
            + "Content-Type: application/octet-stream\r\n"
            + "\r\n"
        try handle.write(contentsOf: Data(preamble.utf8))

        let input = try FileHandle(forReadingFrom: sourceFile)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: 1024 * 1024),
              !chunk.isEmpty
        {
            try handle.write(contentsOf: chunk)
        }

        try handle.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
        return boundary
    }

    static func makeBoundary() -> String {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "Boundary-\(token)"
    }

    private static func escapeFileName(_ fileName: String) -> String {
        fileName
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func append(_ data: inout Data, _ string: String) {
        data.append(Data(string.utf8))
    }
}
