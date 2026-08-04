import Foundation
import Testing
@testable import WiroKit

@Suite("WiroTaskStatus")
struct WiroTaskStatusTests {
    @Test("every wire value maps correctly")
    func allWireValues() {
        let pairs: [(String, WiroTaskStatus)] = [
            ("task_queue", .queued),
            ("task_accept", .accepted),
            ("task_preprocess_start", .preprocessing),
            ("task_preprocess_end", .preprocessed),
            ("task_assign", .assigned),
            ("task_start", .running),
            ("task_output", .output),
            ("task_output_full", .outputComplete),
            ("task_error", .errorOutput),
            ("task_error_full", .errorOutputComplete),
            ("task_end", .processEnded),
            ("task_postprocess_start", .postProcessing),
            ("task_postprocess_end", .completed),
            ("task_cancel", .cancelled),
            ("task_stream_ready", .streamReady),
            ("task_stream_end", .streamEnded),
        ]
        for (wire, expected) in pairs {
            let parsed = WiroTaskStatus.parse(wire)
            #expect(parsed == expected)
            #expect(parsed.apiValue == wire)
        }
    }

    @Test("unknown values map to unknown without throwing")
    func unknownStatus() {
        let status = WiroTaskStatus.parse("task_future_thing")
        #expect(status == .unknown("task_future_thing"))
        #expect(status.apiValue == "task_future_thing")
        #expect(!status.isTerminal)
    }

    @Test("terminal statuses are completed and cancelled")
    func terminal() {
        #expect(WiroTaskStatus.completed.isTerminal)
        #expect(WiroTaskStatus.cancelled.isTerminal)
        #expect(!WiroTaskStatus.running.isTerminal)
    }
}

@Suite("WiroTask parsing")
struct WiroTaskParsingTests {
    @Test("parses task fields including string pexit and outputs")
    func parseTask() throws {
        let json: WiroJSON = try decodeJSONObject(
            #"""
            {
              "id": "99",
              "socketaccesstoken": "tok-abc",
              "status": "task_postprocess_end",
              "pexit": "0",
              "elapsedseconds": "1.5",
              "totalcost": "0.04",
              "debugoutput": "ok",
              "modelslugowner": "openai",
              "modelslugproject": "gpt-image-2",
              "parameters": {"prompt": "hi"},
              "outputs": [
                {
                  "name": "out.png",
                  "contenttype": "image/png",
                  "size": "12",
                  "url": "https://cdn.wiro.ai/out.png"
                },
                {
                  "contenttype": "raw",
                  "content": {
                    "prompt": "hi",
                    "raw": "hello",
                    "thinking": ["t1"],
                    "answer": ["a1"]
                  }
                }
              ]
            }
            """#
        )

        let task = WiroTask.parse(json)
        #expect(task.id?.rawValue == "99")
        #expect(task.taskToken?.rawValue == "tok-abc")
        #expect(task.status == .completed)
        #expect(task.statusRawValue == "task_postprocess_end")
        #expect(task.exitCode == 0)
        #expect(task.isSuccessful)
        #expect(task.isFinished)
        #expect(task.elapsed == .milliseconds(1500))
        #expect(task.totalCost == 0.04)
        #expect(task.outputs.count == 2)
        #expect(task.outputs[0].isImage)
        #expect(task.outputs[0].url?.absoluteString == "https://cdn.wiro.ai/out.png")
        #expect(task.outputs[1].isText)
        #expect(task.outputs[1].content?.answers == ["a1"])
        #expect(task.parameters["prompt"]?.stringValue == "hi")
    }

    @Test("isSuccessful truth table")
    func isSuccessfulTruthTable() {
        func task(
            status: WiroTaskStatus,
            exit: Int?
        ) -> WiroTask {
            WiroTask(
                status: status,
                statusRawValue: status.apiValue,
                exitCode: exit,
                raw: [:]
            )
        }

        #expect(task(status: .completed, exit: 0).isSuccessful)
        #expect(!task(status: .completed, exit: 1).isSuccessful)
        #expect(!task(status: .completed, exit: nil).isSuccessful)
        #expect(!task(status: .cancelled, exit: 0).isSuccessful)
        #expect(!task(status: .running, exit: 0).isSuccessful)
    }

    @Test("WiroTaskResult derives failure reasons")
    func taskResultReasons() {
        let ok = WiroTask(
            status: .completed,
            statusRawValue: "task_postprocess_end",
            exitCode: 0,
            raw: [:]
        )
        #expect(WiroTaskResult.from(task: ok) == .success(ok))

        let failed = WiroTask(
            status: .completed,
            statusRawValue: "task_postprocess_end",
            exitCode: 2,
            raw: [:]
        )
        #expect(
            WiroTaskResult.from(task: failed)
                == .failure(failed, .nonZeroExit)
        )

        let cancelled = WiroTask(
            status: .cancelled,
            statusRawValue: "task_cancel",
            exitCode: 0,
            raw: [:]
        )
        #expect(
            WiroTaskResult.from(task: cancelled)
                == .failure(cancelled, .cancelled)
        )

        let other = WiroTask(
            status: .running,
            statusRawValue: "task_start",
            exitCode: nil,
            raw: [:]
        )
        #expect(
            WiroTaskResult.from(task: other) == .failure(other, .other)
        )
    }
}

@Suite("Run and task client")
struct RunTaskClientTests {
    @Test("runModel encodes owner/project path and includes callbackUrl")
    func runModelPathAndCallback() async throws {
        let model = try WiroModelID(
            owner: "black-forest-labs",
            project: "flux-2-pro"
        )
        let transport = MockHTTPTransport { request in
            #expect(request.httpMethod == "POST")
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/Run/black-forest-labs/flux-2-pro"
            )
            let body = try decodeRequestJSON(request)
            #expect(body["prompt"] == .string("a lake"))
            #expect(
                body["callbackUrl"]
                    == .string("https://hooks.example.com/done")
            )
            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "result": true,
                  "taskid": 12345,
                  "socketaccesstoken": "sock-1"
                }
                """#
            )
        }

        let client = try await ClientFixtures.makeClient(transport: transport)
        let result = try await client.runModel(
            model,
            parameters: ["prompt": "a lake"],
            callbackURL: URL(string: "https://hooks.example.com/done")
        )

        #expect(result.isSuccess)
        #expect(result.taskID?.rawValue == "12345")
        #expect(result.taskToken?.rawValue == "sock-1")
        #expect(await transport.requestCount == 1)
    }

    @Test("runModel percent-encodes special path segments")
    func runModelEncoding() async throws {
        // Valid slugs won't need encoding; force-check the helper and a
        // path that includes characters the encoder escapes when used.
        #expect(
            WiroClient.percentEncodePathSegment("a b") == "a%20b"
        )
        #expect(
            WiroClient.percentEncodePathSegment("flux-2-pro") == "flux-2-pro"
        )
        #expect(
            WiroClient.percentEncodePathSegment("black.forest")
                == "black.forest"
        )

        let model = try WiroModelID(owner: "owner.name", project: "proj-1")
        let transport = MockHTTPTransport { request in
            #expect(
                request.url?.path
                    == "/v1/Run/owner.name/proj-1"
            )
            return MockHTTP.response(
                status: 200,
                json: #"{"result":true,"taskid":"1","socketaccesstoken":"t"}"#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        _ = try await client.runModel(model)
    }

    @Test("runModel rejects invalid callback URLs")
    func runModelCallbackValidation() async throws {
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport()
        )
        let model = try WiroModelID(owner: "a", project: "b")

        do {
            _ = try await client.runModel(
                model,
                callbackURL: URL(string: "ftp://hooks.example.com/x")
            )
            Issue.record("Expected validation")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }

        do {
            _ = try await client.runModel(
                model,
                callbackURL: URL(string: "https://user:pass@hooks.example.com/x")
            )
            Issue.record("Expected validation for userinfo")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }

        do {
            _ = try await client.runModel(
                model,
                callbackURL: URL(string: "https://hooks.example.com/x#frag")
            )
            Issue.record("Expected validation for fragment")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("runModel never retries on 503")
    func runModelNoRetry() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"busy"}"#) },
            { _ in MockHTTP.response(
                status: 200,
                json: #"{"result":true,"taskid":"1","socketaccesstoken":"t"}"#
            ) },
        ])
        let client = try await ClientFixtures.makeClient(transport: transport)
        let model = try WiroModelID(owner: "a", project: "b")

        do {
            _ = try await client.runModel(model)
            Issue.record("Expected 503 failure")
        } catch let error as WiroError {
            guard case .unknownAPI(_, 503, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
        #expect(await transport.requestCount == 1)
    }

    @Test("getTask and getTaskByID post the correct body keys")
    func getTaskBodies() async throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let id = try #require(WiroTaskID(rawValue: "42"))

        let tokenTransport = MockHTTPTransport { request in
            let body = try decodeRequestJSON(request)
            #expect(body["tasktoken"] == .string("tok"))
            #expect(body["taskid"] == nil)
            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "tasklist": [
                    {
                      "id": "42",
                      "socketaccesstoken": "tok",
                      "status": "task_start"
                    }
                  ]
                }
                """#
            )
        }
        let tokenClient = try await ClientFixtures.makeClient(
            transport: tokenTransport
        )
        let byToken = try await tokenClient.getTask(token)
        #expect(byToken.status == .running)

        let idTransport = MockHTTPTransport { request in
            let body = try decodeRequestJSON(request)
            #expect(body["taskid"] == .string("42"))
            #expect(body["tasktoken"] == nil)
            return MockHTTP.response(
                status: 200,
                json: #"""
                {
                  "tasklist": [
                    {"id":"42","status":"task_cancel"}
                  ]
                }
                """#
            )
        }
        let idClient = try await ClientFixtures.makeClient(
            transport: idTransport
        )
        let byID = try await idClient.getTaskByID(id)
        #expect(byID.status == .cancelled)
        #expect(byID.isFinished)
    }

    @Test("getTask throws when tasklist is empty")
    func getTaskEmpty() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 200, json: #"{"tasklist":[]}"#)
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        do {
            _ = try await client.getTask(token)
            Issue.record("Expected unknownAPI")
        } catch let error as WiroError {
            guard case .unknownAPI = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("cancelTask and killTask parse boolean result")
    func cancelAndKill() async throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))

        let cancelTransport = MockHTTPTransport { request in
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/Task/Cancel"
            )
            let body = try decodeRequestJSON(request)
            #expect(body["tasktoken"] == .string("tok"))
            return MockHTTP.response(
                status: 200,
                json: #"{"result":true}"#
            )
        }
        let cancelClient = try await ClientFixtures.makeClient(
            transport: cancelTransport
        )
        #expect(try await cancelClient.cancelTask(token) == true)

        let killTransport = MockHTTPTransport { request in
            #expect(
                request.url?.absoluteString
                    == "https://api.wiro.ai/v1/Task/Kill"
            )
            // Missing `result` passes the envelope (treated as success) but
            // parses as false via the boolean fallback.
            return MockHTTP.response(
                status: 200,
                json: #"{}"#
            )
        }
        let killClient = try await ClientFixtures.makeClient(
            transport: killTransport
        )
        #expect(try await killClient.killTask(token) == false)
    }
}

// MARK: - Helpers

private func decodeJSONObject(_ json: String) throws -> WiroJSON {
    let value = try JSONDecoder().decode(
        WiroJSONValue.self,
        from: Data(json.utf8)
    )
    guard case .object(let object) = value else {
        throw WiroError.unknownAPI(
            message: "Expected object",
            statusCode: 0,
            responseBody: nil
        )
    }
    return object
}

private func decodeRequestJSON(_ request: URLRequest) throws -> WiroJSON {
    guard let data = request.httpBody else { return [:] }
    let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
    guard case .object(let object) = value else { return [:] }
    return object
}
