import Foundation
import Testing
@testable import WiroKit

@Suite("Multipart upload")
struct MultipartUploadTests {
    @Test("multipart body framing is correct")
    func multipartFraming() throws {
        let payload = Data("hello-bytes".utf8)
        let boundary = "Boundary-TESTFIXED0001"
        let body = MultipartFormData.buildFilePart(
            data: payload,
            fileName: "photo.png",
            boundary: boundary
        )

        #expect(body.contentType == "multipart/form-data; boundary=\(boundary)")
        let parsed = try parseMultipart(body.data, boundary: boundary)
        #expect(parsed.count == 1)
        #expect(parsed[0].name == "file")
        #expect(parsed[0].fileName == "photo.png")
        #expect(parsed[0].contentType == "application/octet-stream")
        #expect(parsed[0].data == payload)
    }

    @Test("uploadFile rejects empty fileName")
    func emptyFileName() async throws {
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport()
        )
        do {
            _ = try await client.uploadFile(Data("x".utf8), fileName: "  ")
            Issue.record("Expected validation")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("uploadFile posts multipart and parses list URLs")
    func uploadParsesResponse() async throws {
        let payload = Data([0x89, 0x50, 0x4E, 0x47])
        let transport = MockHTTPTransport { request in
            #expect(request.httpMethod == "POST")
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/File/Upload"
            )
            #expect(request.value(forHTTPHeaderField: "x-api-key") != nil)
            let contentType = try #require(
                request.value(forHTTPHeaderField: "Content-Type")
            )
            #expect(contentType.hasPrefix("multipart/form-data; boundary="))
            #expect(!contentType.contains("application/json"))

            let boundary = String(contentType.split(separator: "=").last!)
            let body = try #require(request.httpBody)
            let parts = try parseMultipart(body, boundary: boundary)
            #expect(parts.count == 1)
            #expect(parts[0].fileName == "shot.png")
            #expect(parts[0].data == payload)

            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "result": true,
                  "list": [
                    {
                      "id": "f1",
                      "name": "shot.png",
                      "contenttype": "image/png",
                      "size": "4",
                      "url": "https://cdn.wiro.ai/shot.png"
                    }
                  ]
                }
                """#
            )
        }

        let client = try await ClientFixtures.makeClient(transport: transport)
        let result = try await client.uploadFile(payload, fileName: "shot.png")
        #expect(result.isSuccess)
        #expect(result.files.count == 1)
        #expect(result.files[0].url?.absoluteString == "https://cdn.wiro.ai/shot.png")
        #expect(result.files[0].size == 4)
        #expect(await transport.requestCount == 1)
    }

    @Test("uploadFile never retries on 503")
    func uploadNoRetry() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"busy"}"#) },
            { _ in MockHTTP.response(
                status: 200,
                json: #"{"result":true,"list":[{"url":"https://cdn.wiro.ai/x"}]}"#
            ) },
        ])
        let client = try await ClientFixtures.makeClient(transport: transport)
        do {
            _ = try await client.uploadFile(Data("x".utf8), fileName: "a.bin")
            Issue.record("Expected failure")
        } catch let error as WiroError {
            guard case .unknownAPI(_, 503, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
        #expect(await transport.requestCount == 1)
    }

    @Test("uploadFile(at:) streams multipart from a local file")
    func uploadFromFileURL() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("wiro-src-\(UUID().uuidString).txt")
        let payload = Data("stream-me".utf8)
        try payload.write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let transport = MockHTTPTransport { request in
            let contentType = try #require(
                request.value(forHTTPHeaderField: "Content-Type")
            )
            let boundary = String(contentType.split(separator: "=").last!)
            let body = try #require(request.httpBody)
            let parts = try parseMultipart(body, boundary: boundary)
            #expect(parts[0].fileName == "note.txt")
            #expect(parts[0].data == payload)
            return MockHTTP.response(
                status: 200,
                json: #"""
                {"result":true,"list":[{"url":"https://cdn.wiro.ai/note.txt"}]}
                """#
            )
        }

        let client = try await ClientFixtures.makeClient(transport: transport)
        let result = try await client.uploadFile(at: temp, fileName: "note.txt")
        #expect(
            result.files.first?.url?.absoluteString
                == "https://cdn.wiro.ai/note.txt"
        )
    }
}

@Suite("File input resolution")
struct FileInputResolutionTests {
    @Test("encoding unresolved fileInput throws")
    func encodeThrows() {
        let value: WiroJSONValue = .fileInput(
            .url(URL(string: "https://example.com/a.png")!)
        )
        #expect(throws: EncodingError.self) {
            _ = try JSONEncoder().encode(value)
        }
    }

    @Test("parameters without file inputs perform no upload")
    func noFileInputsNoUpload() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let transport = MockHTTPTransport { request in
            #expect(
                request.url?.path.hasSuffix("/Run/a/b") == true
            )
            return MockHTTP.response(
                status: 200,
                json: #"{"result":true,"taskid":"1","socketaccesstoken":"t"}"#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        _ = try await client.runModel(
            model,
            parameters: ["prompt": "hi"]
        )
        #expect(await transport.requestCount == 1)
    }

    @Test("deep nested file inputs are resolved before /Run")
    func deepResolution() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let bytes = Data("nested".utf8)
        nonisolated(unsafe) var uploadCount = 0

        let transport = MockHTTPTransport(handlers: [
            { request in
                uploadCount += 1
                #expect(request.url?.path.hasSuffix("/File/Upload") == true)
                return MockHTTP.response(
                    status: 200,
                    json: #"""
                    {"result":true,"list":[{"url":"https://cdn.wiro.ai/nested.bin"}]}
                    """#
                )
            },
            { request in
                #expect(request.url?.path.hasSuffix("/Run/a/b") == true)
                let body = try decodeRequestBody(request)
                // nested map -> array -> map -> fileInput
                let outer = try #require(body["payload"]?.objectValue)
                let items = try #require(outer["items"]?.arrayValue)
                let first = try #require(items.first?.objectValue)
                #expect(
                    first["image"]?.stringValue
                        == "https://cdn.wiro.ai/nested.bin"
                )
                #expect(
                    first["ref"]?.stringValue
                        == "https://example.com/already.png"
                )
                #expect(body["prompt"]?.stringValue == "go")
                return MockHTTP.response(
                    status: 200,
                    json: #"{"result":true,"taskid":"9","socketaccesstoken":"tok"}"#
                )
            },
        ])

        let client = try await ClientFixtures.makeClient(transport: transport)
        let parameters: WiroJSON = [
            "prompt": "go",
            "payload": [
                "items": [
                    [
                        "image": .fileInput(.data(bytes, fileName: "nested.bin")),
                        "ref": .fileInput(
                            .url(URL(string: "https://example.com/already.png")!)
                        ),
                    ],
                ],
            ],
        ]

        let result = try await client.runModel(model, parameters: parameters)
        #expect(result.taskToken?.rawValue == "tok")
        #expect(uploadCount == 1)
        #expect(await transport.requestCount == 2)
    }

    @Test("upload without URL throws unknownAPI")
    func uploadWithoutURL() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let transport = MockHTTPTransport { request in
            #expect(request.url?.path.hasSuffix("/File/Upload") == true)
            return MockHTTP.response(
                status: 200,
                json: #"{"result":true,"list":[{"name":"x"}]}"#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        do {
            _ = try await client.runModel(
                model,
                parameters: [
                    "inputImage": .fileInput(
                        .data(Data("x".utf8), fileName: "x.png")
                    ),
                ]
            )
            Issue.record("Expected unknownAPI")
        } catch let error as WiroError {
            guard case .unknownAPI(let message, _, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message.contains("did not return a file URL"))
        }
        #expect(await transport.requestCount == 1)
    }

    @Test("each data file input triggers exactly one upload")
    func oneUploadPerDataInput() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        nonisolated(unsafe) var uploads = 0
        let transport = MockHTTPTransport(handlers: [
            { _ in
                uploads += 1
                return MockHTTP.response(
                    status: 200,
                    json: #"{"result":true,"list":[{"url":"https://cdn.wiro.ai/1.png"}]}"#
                )
            },
            { _ in
                uploads += 1
                return MockHTTP.response(
                    status: 200,
                    json: #"{"result":true,"list":[{"url":"https://cdn.wiro.ai/2.png"}]}"#
                )
            },
            { request in
                let body = try decodeRequestBody(request)
                let images = try #require(body["inputImage"]?.arrayValue)
                #expect(images.count == 2)
                #expect(images[0].stringValue == "https://cdn.wiro.ai/1.png")
                #expect(images[1].stringValue == "https://cdn.wiro.ai/2.png")
                return MockHTTP.response(
                    status: 200,
                    json: #"{"result":true,"taskid":"1","socketaccesstoken":"t"}"#
                )
            },
        ])

        let client = try await ClientFixtures.makeClient(transport: transport)
        _ = try await client.runModel(
            model,
            parameters: [
                "inputImage": [
                    .fileInput(.data(Data("a".utf8), fileName: "1.png")),
                    .fileInput(.data(Data("b".utf8), fileName: "2.png")),
                ],
            ]
        )
        #expect(uploads == 2)
        #expect(await transport.requestCount == 3)
    }
}

// MARK: - Multipart test parser

private struct MultipartPart {
    var name: String?
    var fileName: String?
    var contentType: String?
    var data: Data
}

private func parseMultipart(
    _ data: Data,
    boundary: String
) throws -> [MultipartPart] {
    let separator = Data("--\(boundary)".utf8)
    let endMarker = Data("--\(boundary)--".utf8)
    guard let first = data.range(of: separator) else {
        throw WiroError.unknownAPI(
            message: "Missing boundary",
            statusCode: 0,
            responseBody: nil
        )
    }

    var parts: [MultipartPart] = []
    var cursor = first.upperBound
    while cursor < data.endIndex {
        if data[cursor...].starts(with: Data("--".utf8)) {
            break
        }
        // Skip CRLF after boundary
        if data[cursor...].starts(with: Data("\r\n".utf8)) {
            cursor = data.index(cursor, offsetBy: 2)
        }

        guard let headerEnd = data.range(
            of: Data("\r\n\r\n".utf8),
            in: cursor..<data.endIndex
        ) else {
            break
        }
        let headerData = data[cursor..<headerEnd.lowerBound]
        let headers = String(decoding: headerData, as: UTF8.self)
        var name: String?
        var fileName: String?
        var contentType: String?
        for line in headers.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-disposition:") {
                name = headerParameter(String(line), key: "name")
                fileName = headerParameter(String(line), key: "filename")
            } else if lower.hasPrefix("content-type:") {
                contentType = String(line.split(separator: ":").dropFirst()
                    .joined(separator: ":"))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        let bodyStart = headerEnd.upperBound
        let nextBoundary = data.range(
            of: Data("\r\n--\(boundary)".utf8),
            in: bodyStart..<data.endIndex
        )
        let bodyEnd = nextBoundary?.lowerBound
            ?? data.range(of: endMarker, in: bodyStart..<data.endIndex)?
            .lowerBound
            ?? data.endIndex
        // Body ends before the CRLF preceding the next boundary.
        let partData = Data(data[bodyStart..<bodyEnd])
        parts.append(
            MultipartPart(
                name: name,
                fileName: fileName,
                contentType: contentType,
                data: partData
            )
        )

        if let nextBoundary {
            cursor = nextBoundary.upperBound
            // Continue after the boundary delimiter.
        } else {
            break
        }
    }
    return parts
}

private func headerParameter(_ header: String, key: String) -> String? {
    let pattern = #"\#(key)="([^"]*)""#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return nil
    }
    let range = NSRange(header.startIndex..<header.endIndex, in: header)
    guard let match = regex.firstMatch(in: header, range: range),
          let valueRange = Range(match.range(at: 1), in: header)
    else {
        return nil
    }
    return String(header[valueRange])
}

private func decodeRequestBody(_ request: URLRequest) throws -> WiroJSON {
    guard let data = request.httpBody else { return [:] }
    let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
    guard case .object(let object) = value else { return [:] }
    return object
}
