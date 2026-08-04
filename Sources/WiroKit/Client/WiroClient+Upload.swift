import Foundation

extension WiroClient {
    /// Uploads `data` to Wiro as a multipart file part named `"file"`.
    ///
    /// This billable operation is not retried automatically.
    ///
    /// ```swift
    /// let upload = try await client.uploadFile(
    ///     imageData,
    ///     fileName: "photo.png"
    /// )
    /// let url = upload.files.first?.url
    /// ```
    ///
    /// - Parameters:
    ///   - data: File contents.
    ///   - fileName: Non-empty file name including extension.
    /// - Returns: Parsed upload result containing hosted file URLs.
    public func uploadFile(
        _ data: Data,
        fileName: String
    ) async throws -> WiroUploadResult {
        let trimmedName = try Self.validatedUploadFileName(fileName)
        let multipart = MultipartFormData.buildFilePart(
            data: data,
            fileName: trimmedName
        )
        return try await sendUpload(
            bodyData: multipart.data,
            contentType: multipart.contentType,
            fileURL: nil
        )
    }

    /// Uploads a local file without loading it fully into memory.
    ///
    /// Builds a multipart body on disk, streaming `url`'s contents into
    /// the part payload, then sends it with a URLSession upload task.
    ///
    /// ```swift
    /// let upload = try await client.uploadFile(
    ///     at: URL(fileURLWithPath: "/tmp/photo.png")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - url: Local file URL.
    ///   - fileName: Defaults to the URL's last path component.
    /// - Returns: Parsed upload result containing hosted file URLs.
    public func uploadFile(
        at url: URL,
        fileName: String? = nil
    ) async throws -> WiroUploadResult {
        let name = try Self.validatedUploadFileName(
            fileName ?? url.lastPathComponent
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "wiro-upload-\(UUID().uuidString).multipart"
            )
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let boundary = try MultipartFormData.writeFilePart(
            from: url,
            fileName: name,
            to: tempURL
        )
        let contentType = "multipart/form-data; boundary=\(boundary)"
        return try await sendUpload(
            bodyData: nil,
            contentType: contentType,
            fileURL: tempURL
        )
    }

    /// Deep-walks `parameters`, uploading every ``WiroFileInput/data`` and
    /// replacing file inputs with URL strings.
    func resolveFileInputs(_ parameters: WiroJSON) async throws -> WiroJSON {
        var resolved: WiroJSON = [:]
        resolved.reserveCapacity(parameters.count)
        for (key, value) in parameters {
            resolved[key] = try await resolveFileValue(value)
        }
        return resolved
    }

    // MARK: - Private

    private func sendUpload(
        bodyData: Data?,
        contentType: String,
        fileURL: URL?
    ) async throws -> WiroUploadResult {
        let url = try makeURL(path: "/File/Upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = durationToTimeInterval(requestTimeout)
        request.httpBody = bodyData
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        for (key, value) in authHeaders(includeContentType: false) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let handler = malformedJSONHandler()
        let transport = self.transport

        return try await execute(
            request,
            url: url,
            retryable: false,
            transportCall: { request in
                if let fileURL {
                    return try await transport.upload(
                        request,
                        fromFile: fileURL
                    )
                }
                return try await transport.perform(request)
            },
            parse: { json in
                WiroUploadResult.parse(json, onMalformedJSON: handler)
            }
        )
    }

    private func resolveFileValue(
        _ value: WiroJSONValue
    ) async throws -> WiroJSONValue {
        switch value {
        case .fileInput(let input):
            switch input {
            case .url(let url):
                return .string(url.absoluteString)
            case .data(let data, let fileName):
                let upload = try await uploadFile(data, fileName: fileName)
                guard let hosted = upload.files.first?.url else {
                    throw WiroError.unknownAPI(
                        message:
                            "The upload for \"\(fileName)\" did not return a file URL.",
                        statusCode: 200,
                        responseBody: nil
                    )
                }
                return .string(hosted.absoluteString)
            }

        case .object(let object):
            var nested: WiroJSON = [:]
            nested.reserveCapacity(object.count)
            for (key, child) in object {
                nested[key] = try await resolveFileValue(child)
            }
            return .object(nested)

        case .array(let array):
            var items: [WiroJSONValue] = []
            items.reserveCapacity(array.count)
            for child in array {
                items.append(try await resolveFileValue(child))
            }
            return .array(items)

        case .string, .number, .bool, .null:
            return value
        }
    }

    static func validatedUploadFileName(_ fileName: String) throws -> String {
        let trimmed = fileName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            throw WiroError.validation(
                message: "fileName must be a non-empty string.",
                statusCode: 0,
                responseBody: nil
            )
        }
        return trimmed
    }

    static func containsFileInput(_ value: WiroJSONValue) -> Bool {
        switch value {
        case .fileInput:
            return true
        case .object(let object):
            return object.values.contains(where: containsFileInput)
        case .array(let array):
            return array.contains(where: containsFileInput)
        case .string, .number, .bool, .null:
            return false
        }
    }

    static func containsFileInput(_ parameters: WiroJSON) -> Bool {
        parameters.values.contains(where: containsFileInput)
    }
}
