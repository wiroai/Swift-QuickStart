import Foundation
import Testing
@testable import WiroKit

private let sampleURL = URL(string: "https://example.com/in.png")!
private let sampleFile = WiroFileInput.url(sampleURL)
private let maskURL = URL(string: "https://example.com/mask.png")!
private let maskFile = WiroFileInput.url(maskURL)

@Suite("Typed model requests")
struct RequestTests {


    @Test("Flux2Pro full, minimal, and validation")
    func flux2Pro() throws {
        let full = try Wiro.flux2Pro(
            prompt: "A mountain",
            inputImages: [sampleFile],
            width: 1024,
            height: 768,
            safetyTolerance: 2,
            seed: 42,
            outputFormat: .png
        )
        #expect(full.model.slug == "black-forest-labs/flux-2-pro")
        #expect(full.parameters() == [
            "prompt": .string("A mountain"),
            "inputImage": .array([.string(sampleURL.absoluteString)]),
            "width": .number(1024),
            "height": .number(768),
            "safetyTolerance": .number(2),
            "seed": .number(42),
            "outputFormat": .string("png"),
        ])

        let minimal = try Wiro.flux2Pro(prompt: "A mountain")
        #expect(minimal.parameters() == ["prompt": .string("A mountain")])

        let zero = try Wiro.flux2Pro(prompt: "A mountain", width: 0, height: 0)
        #expect(zero.parameters()["width"] == .number(0))

        #expect(throws: WiroError.self) { try Wiro.flux2Pro(prompt: "") }
        #expect(throws: WiroError.self) {
            try Wiro.flux2Pro(prompt: "x", width: 100)
        }
        #expect(throws: WiroError.self) {
            try Wiro.flux2Pro(prompt: "x", height: 4096)
        }
        #expect(throws: WiroError.self) {
            try Wiro.flux2Pro(prompt: "x", safetyTolerance: 6)
        }
        #expect(throws: WiroError.self) {
            try Wiro.flux2Pro(prompt: "x", seed: -1)
        }
    }

    @Test("GptImage2 full, minimal, and validation")
    func gptImage2() throws {
        let full = try Wiro.gptImage2(
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
        )
        #expect(full.model.slug == "openai/gpt-image-2")
        #expect(full.parameters() == [
            "prompt": .string("A mug"),
            "resolution": .string("1k"),
            "ratio": .string("1:1"),
            "quality": .string("low"),
            "samples": .number(2),
            "inputImage": .array([.string(sampleURL.absoluteString)]),
            "inputImageMask": .array([.string(maskURL.absoluteString)]),
            "background": .string("opaque"),
            "outputFormat": .string("webp"),
            "outputCompression": .number(80),
            "moderation": .string("low"),
        ])
        let minimal = try Wiro.gptImage2(
            prompt: "A mug",
            resolution: .r4k,
            ratio: .landscape16x9,
            quality: .high,
            samples: 1
        )
        #expect(minimal.parameters().keys.sorted() == [
            "prompt", "quality", "ratio", "resolution", "samples",
        ])
        #expect(throws: WiroError.self) {
            try Wiro.gptImage2(
                prompt: "A mug",
                resolution: .r1k,
                ratio: .square,
                quality: .low,
                samples: 11
            )
        }
    }

    @Test("NanoBananaPro serialization")
    func nanoBananaPro() throws {
        let req = try Wiro.nanoBananaPro(
            prompt: "A fox",
            inputImages: [sampleFile],
            aspectRatio: .ultrawide21x9,
            resolution: .r2k,
            safetySetting: .blockOnlyHigh
        )
        #expect(req.model.slug == "google/nano-banana-pro")
        #expect(req.parameters() == [
            "prompt": .string("A fox"),
            "inputImage": .array([.string(sampleURL.absoluteString)]),
            "aspectRatio": .string("21:9"),
            "resolution": .string("2K"),
            "safetySetting": .string("BLOCK_ONLY_HIGH"),
        ])
        #expect(throws: WiroError.self) {
            try Wiro.nanoBananaPro(prompt: "")
        }
    }

    @Test("SeedreamV4 string boolean")
    func seedreamV4() throws {
        let req = try Wiro.seedreamV4(
            prompt: "One poster",
            size: .panorama3024x1296,
            maxImages: 1,
            watermark: false
        )
        #expect(req.parameters() == [
            "prompt": .string("One poster"),
            "size": .string("3024x1296"),
            "maxImages": .number(1),
            "watermark": .string("false"),
        ])
        #expect(throws: WiroError.self) {
            try Wiro.seedreamV4(
                prompt: "x",
                size: .square2048,
                maxImages: 0,
                watermark: true
            )
        }
    }

    @Test("GrokImagineImage serialization")
    func grokImagineImage() throws {
        let req = try Wiro.grokImagineImage(
            prompt: "A neon alley",
            samples: 3,
            resolution: .r2k,
            aspectRatio: .landscape19_5x9
        )
        #expect(req.parameters() == [
            "prompt": .string("A neon alley"),
            "samples": .number(3),
            "resolution": .string("2k"),
            "aspectRatio": .string("19.5:9"),
        ])
    }

    @Test("RunwayGen45 full and validation")
    func runwayGen45() throws {
        let full = try Wiro.runwayGen45(
            prompt: "A drone shot",
            ratio: .landscape16x9,
            duration: 5,
            inputImages: [sampleFile],
            contentModeration: .low,
            seed: 7
        )
        #expect(full.parameters() == [
            "prompt": .string("A drone shot"),
            "ratio": .string("16:9"),
            "duration": .number(5),
            "inputImage": .array([.string(sampleURL.absoluteString)]),
            "contentModeration": .string("low"),
            "seed": .number(7),
        ])
        #expect(throws: WiroError.self) {
            try Wiro.runwayGen45(prompt: "", ratio: .auto, duration: 2)
        }
        #expect(throws: WiroError.self) {
            try Wiro.runwayGen45(
                prompt: String(repeating: "p", count: 1001),
                ratio: .auto,
                duration: 2
            )
        }
        #expect(throws: WiroError.self) {
            try Wiro.runwayGen45(prompt: "x", ratio: .auto, duration: 0)
        }
    }

    @Test("Seedance20 string fields")
    func seedance20() throws {
        let req = try Wiro.seedance20(
            resolution: .r480p,
            ratio: .adaptive,
            duration: 4,
            generateAudio: false,
            prompt: "A time-lapse",
            promptEnhancement: true,
            watermark: false,
            seed: 1
        )
        #expect(req.model.slug == "bytedance/seedance-2-0")
        #expect(req.parameters()["duration"] == .string("4"))
        #expect(req.parameters()["generateAudio"] == .string("false"))
        #expect(req.parameters()["promptEnhancement"] == .string("true"))
        #expect(req.parameters()["watermark"] == .string("false"))
        #expect(throws: WiroError.self) {
            try Wiro.seedance20(
                resolution: .r480p,
                ratio: .adaptive,
                duration: 3,
                generateAudio: true
            )
        }
    }

    @Test("KlingV3 on/off and multiPrompt default")
    func klingV3() throws {
        let req = try Wiro.klingV3(
            mode: .pro,
            duration: 5,
            ratio: .square,
            sound: true,
            prompt: "walk"
        )
        #expect(req.parameters()["sound"] == .string("on"))
        #expect(req.parameters()["duration"] == .string("5"))
        #expect(req.parameters()["multiPrompt"] == .string(""))
        let off = try Wiro.klingV3(
            mode: .std,
            duration: 10,
            ratio: .landscape16x9,
            sound: false
        )
        #expect(off.parameters()["sound"] == .string("off"))
        #expect(throws: WiroError.self) {
            try Wiro.klingV3(
                mode: .std,
                duration: 7,
                ratio: .square,
                sound: true
            )
        }
        #expect(throws: WiroError.self) {
            try Wiro.klingV3(
                mode: .std,
                duration: 5,
                ratio: .square,
                sound: true,
                multiShot: true,
                shotType: .customize
            )
        }
    }

    @Test("Veo31 string duration and keys")
    func veo31() throws {
        let req = try Wiro.veo31(
            durationSeconds: 4,
            prompt: "ocean",
            inputImage: [sampleFile],
            lastFrameImage: [sampleFile],
            referenceImages: [sampleFile],
            aspectRatio: .landscape16x9,
            resolution: .r720p,
            negativePrompt: "blur",
            seed: 3
        )
        #expect(req.parameters()["durationSeconds"] == .string("4"))
        #expect(req.parameters()["inputImage2"] != nil)
        #expect(req.parameters()["inputImage3"] != nil)
        #expect(throws: WiroError.self) {
            try Wiro.veo31(durationSeconds: 5)
        }
    }

    @Test("Sora2Pro seconds string")
    func sora2Pro() throws {
        let req = try Wiro.sora2Pro(prompt: "city", seconds: 8)
        #expect(req.parameters() == [
            "prompt": .string("city"),
            "seconds": .string("8"),
        ])
        #expect(throws: WiroError.self) {
            try Wiro.sora2Pro(prompt: "city", seconds: 7)
        }
    }

    @Test("Hailuo23Fast duration and resolution constraint")
    func hailuo23Fast() throws {
        let req = try Wiro.hailuo23Fast(
            inputImage: sampleFile,
            duration: 6,
            prompt: "zoom",
            promptOptimizer: true,
            resolution: .r768p
        )
        #expect(req.parameters()["duration"] == .string("6"))
        #expect(req.parameters()["promptOptimizer"] == .string("true"))
        #expect(throws: WiroError.self) {
            try Wiro.hailuo23Fast(
                inputImage: sampleFile,
                duration: 10,
                resolution: .r1080p
            )
        }
    }

    @Test("GrokImagineVideo serialization")
    func grokImagineVideo() throws {
        let req = try Wiro.grokImagineVideo(
            prompt: "rain",
            duration: 5,
            aspectRatio: .auto,
            resolution: .r720p
        )
        #expect(req.parameters() == [
            "prompt": .string("rain"),
            "duration": .string("5"),
            "aspectRatio": .string("auto"),
            "resolution": .string("720p"),
        ])
    }

    @Test("Lyria3 minimal and empty prompt")
    func lyria3() throws {
        let req = try Wiro.lyria3(prompt: "lofi")
        #expect(req.model.slug == "google/lyria-3")
        #expect(req.parameters() == ["prompt": .string("lofi")])
        #expect(throws: WiroError.self) { try Wiro.lyria3(prompt: "") }
    }

    @Test("Dynamic request and factories")
    func dynamicAndFactories() throws {
        let dyn = try Wiro.model(
            "owner/model",
            parameters: ["prompt": .string("hi")]
        )
        #expect(dyn.model.slug == "owner/model")
        #expect(dyn.parameters()["prompt"] == .string("hi"))
        #expect(throws: WiroError.self) {
            try Wiro.model("bad", parameters: [:])
        }
    }

    @Test("typed run posts resolved parameters")
    func typedRunEndToEnd() async throws {
        let transport = MockHTTPTransport { request in
            #expect(
                request.url?.path
                    == "/v1/Run/black-forest-labs/flux-2-pro"
            )
            let body = try decodeRequestJSON(request)
            #expect(body["prompt"] == .string("lake"))
            #expect(body["width"] == .number(1024))
            return MockHTTP.response(
                status: 200,
                json: #"{"result":true,"taskid":"1","socketaccesstoken":"t"}"#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let result = try await client.run(
            Wiro.flux2Pro(prompt: "lake", width: 1024)
        )
        #expect(result.taskToken?.rawValue == "t")
    }
}

private func decodeRequestJSON(_ request: URLRequest) throws -> WiroJSON {
    guard let data = request.httpBody else { return [:] }
    let value = try JSONDecoder().decode(WiroJSONValue.self, from: data)
    guard case .object(let object) = value else { return [:] }
    return object
}
