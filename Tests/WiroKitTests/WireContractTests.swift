import Foundation
import Testing
@testable import WiroKit

private let sampleURL = URL(string: "https://example.com/in.png")!
private let sampleFile = WiroFileInput.url(sampleURL)
private let maskURL = URL(string: "https://example.com/mask.png")!
private let maskFile = WiroFileInput.url(maskURL)

@Suite("Wire contract fixtures")
struct WireContractTests {
    // MARK: - Typed request bodies

    @Test("typed request parameters match wire fixtures")
    func typedRequestContracts() throws {
        let cases: [(String, WiroJSON)] = [
            (
                "flux2_pro",
                try Wiro.flux2Pro(
                    prompt: "A mountain",
                    inputImages: [sampleFile],
                    width: 1024,
                    height: 768,
                    safetyTolerance: 2,
                    seed: 42,
                    outputFormat: .png
                ).parameters()
            ),
            (
                "gpt_image_2",
                try Wiro.gptImage2(
                    prompt: "A mug",
                    resolution: .r1k,
                    ratio: .square,
                    quality: .low,
                    samples: 2,
                    inputImages: [sampleFile],
                    inputImageMasks: [maskFile],
                    background: .opaque,
                    outputFormat: .webp,
                    outputCompression: 80,
                    moderation: .low
                ).parameters()
            ),
            (
                "nano_banana_pro",
                try Wiro.nanoBananaPro(
                    prompt: "A fox",
                    inputImages: [sampleFile],
                    aspectRatio: .ultrawide21x9,
                    resolution: .r2k,
                    safetySetting: .blockOnlyHigh
                ).parameters()
            ),
            (
                "seedream_v4",
                try Wiro.seedreamV4(
                    prompt: "One poster",
                    size: .panorama3024x1296,
                    maxImages: 1,
                    watermark: false
                ).parameters()
            ),
            (
                "grok_imagine_image",
                try Wiro.grokImagineImage(
                    prompt: "A neon alley",
                    samples: 3,
                    resolution: .r2k,
                    aspectRatio: .landscape19_5x9
                ).parameters()
            ),
            (
                "upscaler",
                try Wiro.upscaler(
                    inputImage: sampleFile,
                    upscaleFactor: 2,
                    outputType: .png,
                    compressionQuality: 90
                ).parameters()
            ),
            (
                "runway_gen45",
                try Wiro.runwayGen45(
                    prompt: "A drone shot",
                    ratio: .landscape16x9,
                    duration: 5,
                    inputImages: [sampleFile],
                    contentModeration: .low,
                    seed: 7
                ).parameters()
            ),
            (
                "seedance_20",
                try Wiro.seedance20(
                    resolution: .r480p,
                    ratio: .adaptive,
                    duration: 4,
                    generateAudio: false,
                    prompt: "A time-lapse",
                    promptEnhancement: true,
                    watermark: false,
                    seed: 1
                ).parameters()
            ),
            (
                "kling_v3",
                try Wiro.klingV3(
                    mode: .pro,
                    duration: 5,
                    ratio: .square,
                    sound: true,
                    prompt: "walk"
                ).parameters()
            ),
            (
                "veo31",
                try Wiro.veo31(
                    durationSeconds: 4,
                    prompt: "ocean",
                    inputImage: [sampleFile],
                    lastFrameImage: [sampleFile],
                    referenceImages: [sampleFile],
                    aspectRatio: .landscape16x9,
                    resolution: .r720p,
                    negativePrompt: "blur",
                    seed: 3
                ).parameters()
            ),
            (
                "sora2_pro",
                try Wiro.sora2Pro(
                    prompt: "city",
                    seconds: 8,
                    inputImages: [sampleFile],
                    resolution: .r1080p,
                    ratio: .landscape16x9
                ).parameters()
            ),
            (
                "hailuo_23_fast",
                try Wiro.hailuo23Fast(
                    inputImage: sampleFile,
                    duration: 6,
                    prompt: "zoom",
                    promptOptimizer: true,
                    resolution: .r768p
                ).parameters()
            ),
            (
                "grok_imagine_video",
                try Wiro.grokImagineVideo(
                    prompt: "rain",
                    duration: 5,
                    aspectRatio: .auto,
                    resolution: .r720p
                ).parameters()
            ),
            (
                "lyria_3",
                try Wiro.lyria3(
                    prompt: "lofi",
                    inputImages: [sampleFile]
                ).parameters()
            ),
            (
                "dynamic",
                try Wiro.model(
                    "owner/model",
                    parameters: ["prompt": "hi", "seed": 1]
                ).parameters()
            ),
        ]

        for (name, actual) in cases {
            let expected = try WireFixture.loadJSON(
                "Wire/requests/\(name).json"
            )
            WireFixture.assertJSONEqual(actual, expected, label: name)
        }
    }

    // MARK: - Endpoint request bodies

    @Test("endpoint request bodies match wire fixtures")
    func endpointContracts() async throws {
        try await assertEndpointBody(
            fixture: "Wire/endpoints/tool_list.json",
            pathSuffix: "/Tool/List"
        ) { client in
            _ = try await client.searchModels(
                search: "flux",
                categories: ["image"],
                start: 0,
                limit: 20,
                sort: .relevance,
                owner: "openai",
                order: .descending
            )
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/tool_explore.json",
            pathSuffix: "/Tool/Explore"
        ) { client in
            _ = try await client.explore()
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/tool_detail.json",
            pathSuffix: "/Tool/Detail"
        ) { client in
            _ = try await client.getModelSchema(
                WiroModelID(parsing: "black-forest-labs/flux-2-pro")!
            )
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/task_detail_token.json",
            pathSuffix: "/Task/Detail"
        ) { client in
            _ = try await client.getTask(WiroTaskToken(rawValue: "tok-abc")!)
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/task_detail_id.json",
            pathSuffix: "/Task/Detail"
        ) { client in
            _ = try await client.getTaskByID(WiroTaskID(rawValue: "task-123")!)
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/task_cancel.json",
            pathSuffix: "/Task/Cancel"
        ) { client in
            _ = try await client.cancelTask(WiroTaskToken(rawValue: "tok-abc")!)
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/task_kill.json",
            pathSuffix: "/Task/Kill"
        ) { client in
            _ = try await client.killTask(WiroTaskToken(rawValue: "tok-abc")!)
        }

        try await assertEndpointBody(
            fixture: "Wire/endpoints/run_flux2pro_callback.json",
            pathSuffix: "/Run/black-forest-labs/flux-2-pro"
        ) { client in
            _ = try await client.run(
                Wiro.flux2Pro(prompt: "lake", width: 1024),
                callbackURL: URL(string: "https://example.com/hook")!
            )
        }
    }

    // MARK: - Helpers

    private func assertEndpointBody(
        fixture: String,
        pathSuffix: String,
        call: (WiroClient) async throws -> Void
    ) async throws {
        let expected = try WireFixture.loadJSON(fixture)
        let transport = MockHTTPTransport { request in
            #expect(request.url?.path.hasSuffix(pathSuffix) == true)
            let body = try WireFixture.decodeBody(request)
            WireFixture.assertJSONEqual(body, expected, label: fixture)
            return MockHTTP.response(
                status: 200,
                json: Self.okJSON(for: pathSuffix)
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        try await call(client)
    }

    private static func okJSON(for pathSuffix: String) -> String {
        switch pathSuffix {
        case "/Tool/List":
            return #"{"result":true,"total":0,"tool":[]}"#
        case "/Tool/Explore":
            return #"{"result":true,"explore":[]}"#
        case "/Tool/Detail":
            return #"""
            {
              "result": true,
              "tool": [{
                "id": "1",
                "cleanslugowner": "black-forest-labs",
                "cleanslugproject": "flux-2-pro",
                "parameters": []
              }]
            }
            """#
        case "/Task/Detail":
            return #"""
            {
              "result": true,
              "tasklist": [{
                "taskid": "task-123",
                "socketaccesstoken": "tok-abc",
                "status": "task_queue",
                "parameters": {}
              }]
            }
            """#
        case "/Task/Cancel", "/Task/Kill":
            return #"{"result":true}"#
        default:
            return #"{"result":true,"taskid":"1","socketaccesstoken":"t"}"#
        }
    }
}

enum WireFixture {
    static func loadJSON(_ relativePath: String) throws -> WiroJSON {
        // Fixtures are copied as Tests/.../Fixtures → Bundle "Fixtures/...".
        let nsPath = relativePath as NSString
        let name = nsPath.deletingPathExtension
        let subdirectory = "Fixtures/"
            + nsPath.deletingLastPathComponent
        guard let url = Bundle.module.url(
            forResource: (name as NSString).lastPathComponent,
            withExtension: "json",
            subdirectory: subdirectory
        ) else {
            Issue.record("Missing fixture \(relativePath) in \(subdirectory)")
            throw WiroError.validation(
                message: "Missing fixture \(relativePath)",
                statusCode: 0,
                responseBody: nil
            )
        }
        let data = try Data(contentsOf: url)
        let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
        guard case .object(let object) = value else {
            throw WiroError.validation(
                message: "Fixture is not a JSON object: \(relativePath)",
                statusCode: 0,
                responseBody: nil
            )
        }
        return object
    }

    static func decodeBody(_ request: URLRequest) throws -> WiroJSON {
        guard let data = request.httpBody else { return [:] }
        let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
        guard case .object(let object) = value else { return [:] }
        return object
    }

    static func assertJSONEqual(
        _ actual: WiroJSON,
        _ expected: WiroJSON,
        label: String
    ) {
        #expect(
            Set(actual.keys) == Set(expected.keys),
            "\(label) key set mismatch: actual=\(actual.keys.sorted()) expected=\(expected.keys.sorted())"
        )
        for key in expected.keys.sorted() {
            #expect(
                actual[key] == expected[key],
                "\(label).\(key): actual=\(String(describing: actual[key])) expected=\(String(describing: expected[key]))"
            )
        }
    }
}
