import Foundation
import Testing
@testable import WiroKit

@Suite("Public API behavior")
struct PublicAPIBehaviorTests {
    @Test("typed subscribe and subscribeStream overloads")
    func typedSubscribeOverloads() async throws {
        let transport = MockHTTPTransport(handlers: [
            { request in
                #expect(
                    request.url?.path
                        == "/v1/Run/black-forest-labs/flux-2-pro"
                )
                return MockHTTP.response(
                    status: 200,
                    json:
                        #"{"result":true,"taskid":"1","socketaccesstoken":"tok"}"#
                )
            },
            { _ in
                MockHTTP.response(
                    status: 200,
                    json: #"""
                    {
                      "result": true,
                      "tasklist": [{
                        "taskid": "1",
                        "socketaccesstoken": "tok",
                        "status": "task_postprocess_end",
                        "pexit": "0",
                        "parameters": {},
                        "outputs": [{
                          "name": "out.png",
                          "contenttype": "image/png",
                          "url": "https://cdn.example.com/out.png"
                        }]
                      }]
                    }
                    """#
                )
            },
            { _ in
                MockHTTP.response(
                    status: 200,
                    json:
                        #"{"result":true,"taskid":"2","socketaccesstoken":"tok2"}"#
                )
            },
            { _ in
                MockHTTP.response(
                    status: 200,
                    json: #"""
                    {
                      "result": true,
                      "tasklist": [{
                        "taskid": "2",
                        "socketaccesstoken": "tok2",
                        "status": "task_postprocess_end",
                        "pexit": "0",
                        "parameters": {},
                        "outputs": []
                      }]
                    }
                    """#
                )
            },
        ])

        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .milliseconds(1)
        )

        let result = try await client.subscribe(
            Wiro.flux2Pro(prompt: "lake", width: 1024)
        )
        if case .success(let task) = result {
            #expect(task.outputs.count == 1)
        } else {
            Issue.record("Expected success")
        }

        var updates = 0
        for try await update in try await client.subscribeStream(
            Wiro.flux2Pro(prompt: "lake")
        ) {
            updates += 1
            if update.isTerminal { break }
        }
        #expect(updates >= 1)
    }

    @Test("WiroFileInput.wireValue for url and data")
    func fileInputWireValue() {
        let url = URL(string: "https://example.com/a.png")!
        #expect(WiroFileInput.url(url).wireValue == url.absoluteString)
        #expect(
            WiroFileInput.data(Data([1, 2, 3]), fileName: "a.png").wireValue
                == nil
        )
    }

    @Test("WiroAPIError and paginated result parsing")
    func paginatedAndAPIErrorParse() {
        let page = WiroPaginatedResult<WiroModel>.parse(
            [
                "result": .bool(false),
                "total": .string("0"),
                "tool": .array([]),
                "errors": .array([
                    .object([
                        "code": .string("E1"),
                        "message": .string("Nope"),
                    ]),
                ]),
            ],
            itemsKey: "tool",
            itemFromJSON: { WiroModel.parse($0) }
        )
        #expect(page.isSuccess == false)
        #expect(page.errors.count == 1)
        #expect(page.errors[0].code == "E1")
        #expect(page.errors[0].message == "Nope")
    }

    @Test("request enum apiValue matrix covers Kling and Sora cases")
    func requestEnumAPIValues() {
        #expect(WiroKlingV3ShotType.customize.apiValue == "customize")
        #expect(WiroKlingV3ShotType.intelligence.apiValue == "intelligence")
        #expect(WiroSora2ProResolution.r720p.apiValue == "720p")
        #expect(WiroSora2ProResolution.r1024p.apiValue == "1024p")
        #expect(WiroSora2ProResolution.r1080p.apiValue == "1080p")
        #expect(WiroSora2ProRatio.landscape16x9.apiValue == "16:9")
        #expect(WiroSora2ProRatio.portrait9x16.apiValue == "9:16")
        #expect(WiroSora2ProRatio.auto.apiValue == "auto")
        #expect(WiroHailuo23FastResolution.r768p.apiValue == "768P")
        #expect(WiroHailuo23FastResolution.r1080p.apiValue == "1080P")
        #expect(WiroGrokImagineVideoResolution.r480p.apiValue == "480p")
        #expect(WiroGrokImagineVideoResolution.r720p.apiValue == "720p")
    }

    @Test("task output media helpers and content parse")
    func taskOutputHelpers() {
        let image = WiroTaskOutput(
            contentType: "image/png",
            url: URL(string: "https://cdn.example.com/a.png"),
            raw: [:]
        )
        #expect(image.isImage)
        #expect(!image.isVideo)
        #expect(!image.isAudio)

        let video = WiroTaskOutput(contentType: "video/mp4", raw: [:])
        #expect(video.isVideo)

        let audio = WiroTaskOutput(contentType: "audio/mpeg", raw: [:])
        #expect(audio.isAudio)

        let content = WiroTaskOutputContent.parse([
            "prompt": .string("hi"),
            "raw": .string("answer text"),
            "thinking": .array([.string("t1")]),
            "answer": .array([.string("a1")]),
        ])
        #expect(content.prompt == "hi")
        #expect(content.rawText == "answer text")
        #expect(content.thinking == ["t1"])
        #expect(content.answers == ["a1"])
    }
}
