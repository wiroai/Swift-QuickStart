import Foundation

/// Typed request for `runway/gen-4-5`.
public struct WiroRunwayGen45Request: WiroModelRequest, Sendable, Equatable {
    public let prompt: String
    public let ratio: WiroRunwayGen45Ratio
    public let duration: Int
    public let inputImages: [WiroFileInput]?
    public let contentModeration: WiroRunwayGen45Moderation?
    public let seed: Int?

    public var model: WiroModelID {
        WiroRequestValidation.model("runway", "gen-4-5")
    }

    public init(
        prompt: String,
        ratio: WiroRunwayGen45Ratio,
        duration: Int,
        inputImages: [WiroFileInput]? = nil,
        contentModeration: WiroRunwayGen45Moderation? = nil,
        seed: Int? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireMaxLength(
            prompt,
            max: 1000,
            label: "prompt"
        )
        guard duration > 0 else {
            try WiroRequestValidation.fail("duration must be positive.")
        }
        if let seed {
            guard seed >= 0, seed <= 4_294_967_295 else {
                try WiroRequestValidation.fail(
                    "seed must be between 0 and 4294967295."
                )
            }
        }
        self.prompt = prompt
        self.ratio = ratio
        self.duration = duration
        self.inputImages = inputImages
        self.contentModeration = contentModeration
        self.seed = seed
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "prompt": .string(prompt),
            "ratio": .string(ratio.apiValue),
            "duration": .number(Double(duration)),
        ]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        if let contentModeration {
            json["contentModeration"] = .string(contentModeration.apiValue)
        }
        if let seed { json["seed"] = .number(Double(seed)) }
        return json
    }
}

/// Typed request for `bytedance/seedance-2-0`.
public struct WiroSeedance20Request: WiroModelRequest, Sendable, Equatable {
    public let resolution: WiroSeedance20Resolution
    public let ratio: WiroSeedance20Ratio
    public let duration: Int
    public let generateAudio: Bool
    public let prompt: String?
    public let inputImage: [WiroFileInput]?
    public let lastFrameImage: [WiroFileInput]?
    public let referenceImages: [WiroFileInput]?
    public let referenceAudios: [WiroFileInput]?
    public let promptEnhancement: Bool?
    public let watermark: Bool?
    public let seed: Int?

    public var model: WiroModelID {
        WiroRequestValidation.model("bytedance", "seedance-2-0")
    }

    public init(
        resolution: WiroSeedance20Resolution,
        ratio: WiroSeedance20Ratio,
        duration: Int,
        generateAudio: Bool,
        prompt: String? = nil,
        inputImage: [WiroFileInput]? = nil,
        lastFrameImage: [WiroFileInput]? = nil,
        referenceImages: [WiroFileInput]? = nil,
        referenceAudios: [WiroFileInput]? = nil,
        promptEnhancement: Bool? = nil,
        watermark: Bool? = nil,
        seed: Int? = nil
    ) throws {
        try WiroRequestValidation.requireRange(
            duration,
            min: 4,
            max: 15,
            label: "duration"
        )
        try WiroRequestValidation.requireOptionalCountRange(
            referenceImages,
            min: 1,
            max: 9,
            label: "referenceImages"
        )
        try WiroRequestValidation.requireOptionalCountRange(
            referenceAudios,
            min: 1,
            max: 3,
            label: "referenceAudios"
        )
        try WiroRequestValidation.requireNonNegative(seed, label: "seed")
        self.resolution = resolution
        self.ratio = ratio
        self.duration = duration
        self.generateAudio = generateAudio
        self.prompt = prompt
        self.inputImage = inputImage
        self.lastFrameImage = lastFrameImage
        self.referenceImages = referenceImages
        self.referenceAudios = referenceAudios
        self.promptEnhancement = promptEnhancement
        self.watermark = watermark
        self.seed = seed
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "resolution": .string(resolution.apiValue),
            "ratio": .string(ratio.apiValue),
            "duration": WiroRequestEncoding.stringInt(duration),
            "generateAudio": WiroRequestEncoding.stringBool(generateAudio),
        ]
        if let prompt { json["prompt"] = .string(prompt) }
        if let files = WiroRequestEncoding.files(inputImage) {
            json["inputImage"] = files
        }
        if let files = WiroRequestEncoding.files(lastFrameImage) {
            json["inputImageLast"] = files
        }
        if let files = WiroRequestEncoding.files(referenceImages) {
            json["inputImageReference"] = files
        }
        if let files = WiroRequestEncoding.files(referenceAudios) {
            json["inputAudio"] = files
        }
        if let promptEnhancement {
            json["promptEnhancement"] =
                WiroRequestEncoding.stringBool(promptEnhancement)
        }
        if let watermark {
            json["watermark"] = WiroRequestEncoding.stringBool(watermark)
        }
        if let seed { json["seed"] = .number(Double(seed)) }
        return json
    }
}

/// Typed request for `klingai/kling-v3`.
public struct WiroKlingV3Request: WiroModelRequest, Sendable, Equatable {
    public let mode: WiroKlingV3Mode
    public let duration: Int
    public let ratio: WiroKlingV3Ratio
    public let sound: Bool
    public let prompt: String?
    public let inputImage: [WiroFileInput]?
    public let lastFrameImage: [WiroFileInput]?
    public let multiShot: Bool?
    public let shotType: WiroKlingV3ShotType?
    public let multiPrompt: String?

    public var model: WiroModelID {
        WiroRequestValidation.model("klingai", "kling-v3")
    }

    public init(
        mode: WiroKlingV3Mode,
        duration: Int,
        ratio: WiroKlingV3Ratio,
        sound: Bool,
        prompt: String? = nil,
        inputImage: [WiroFileInput]? = nil,
        lastFrameImage: [WiroFileInput]? = nil,
        multiShot: Bool? = nil,
        shotType: WiroKlingV3ShotType? = nil,
        multiPrompt: String? = nil
    ) throws {
        try WiroRequestValidation.requireOneOf(
            duration,
            allowed: [5, 10, 15],
            label: "duration"
        )
        if multiShot == true,
            shotType == .customize,
            multiPrompt == nil
        {
            try WiroRequestValidation.fail(
                "multiPrompt is required when multiShot is true and shotType is customize."
            )
        }
        self.mode = mode
        self.duration = duration
        self.ratio = ratio
        self.sound = sound
        self.prompt = prompt
        self.inputImage = inputImage
        self.lastFrameImage = lastFrameImage
        self.multiShot = multiShot
        self.shotType = shotType
        self.multiPrompt = multiPrompt
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "mode": .string(mode.apiValue),
            "duration": WiroRequestEncoding.stringInt(duration),
            "ratio": .string(ratio.apiValue),
            "sound": WiroRequestEncoding.onOff(sound),
            "multiPrompt": .string(multiPrompt ?? ""),
        ]
        if let prompt { json["prompt"] = .string(prompt) }
        if let files = WiroRequestEncoding.files(inputImage) {
            json["inputImage"] = files
        }
        if let files = WiroRequestEncoding.files(lastFrameImage) {
            json["inputImage2"] = files
        }
        if let multiShot {
            json["multiShot"] = WiroRequestEncoding.stringBool(multiShot)
        }
        if let shotType {
            json["shotType"] = .string(shotType.apiValue)
        }
        return json
    }
}

/// Typed request for `google/veo3-1`.
public struct WiroVeo31Request: WiroModelRequest, Sendable, Equatable {
    public let durationSeconds: Int
    public let prompt: String?
    public let inputImage: [WiroFileInput]?
    public let lastFrameImage: [WiroFileInput]?
    public let referenceImages: [WiroFileInput]?
    public let aspectRatio: WiroVeo31Ratio?
    public let resolution: WiroVeo31Resolution?
    public let negativePrompt: String?
    public let seed: Int?

    public var model: WiroModelID {
        WiroRequestValidation.model("google", "veo3-1")
    }

    public init(
        durationSeconds: Int,
        prompt: String? = nil,
        inputImage: [WiroFileInput]? = nil,
        lastFrameImage: [WiroFileInput]? = nil,
        referenceImages: [WiroFileInput]? = nil,
        aspectRatio: WiroVeo31Ratio? = nil,
        resolution: WiroVeo31Resolution? = nil,
        negativePrompt: String? = nil,
        seed: Int? = nil
    ) throws {
        try WiroRequestValidation.requireOneOf(
            durationSeconds,
            allowed: [4, 6, 8],
            label: "durationSeconds"
        )
        try WiroRequestValidation.requireOptionalCountRange(
            referenceImages,
            min: 1,
            max: 3,
            label: "referenceImages"
        )
        try WiroRequestValidation.requireNonNegative(seed, label: "seed")
        self.durationSeconds = durationSeconds
        self.prompt = prompt
        self.inputImage = inputImage
        self.lastFrameImage = lastFrameImage
        self.referenceImages = referenceImages
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.negativePrompt = negativePrompt
        self.seed = seed
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "durationSeconds": WiroRequestEncoding.stringInt(durationSeconds),
        ]
        if let prompt { json["prompt"] = .string(prompt) }
        if let files = WiroRequestEncoding.files(inputImage) {
            json["inputImage"] = files
        }
        if let files = WiroRequestEncoding.files(lastFrameImage) {
            json["inputImage2"] = files
        }
        if let files = WiroRequestEncoding.files(referenceImages) {
            json["inputImage3"] = files
        }
        if let aspectRatio {
            json["aspectRatio"] = .string(aspectRatio.apiValue)
        }
        if let resolution {
            json["resolution"] = .string(resolution.apiValue)
        }
        if let negativePrompt {
            json["negativePrompt"] = .string(negativePrompt)
        }
        if let seed { json["seed"] = .number(Double(seed)) }
        return json
    }
}

/// Typed request for `openai/sora-2-pro`.
public struct WiroSora2ProRequest: WiroModelRequest, Sendable, Equatable {
    public let prompt: String
    public let seconds: Int
    public let inputImages: [WiroFileInput]?
    public let resolution: WiroSora2ProResolution?
    public let ratio: WiroSora2ProRatio?

    public var model: WiroModelID {
        WiroRequestValidation.model("openai", "sora-2-pro")
    }

    public init(
        prompt: String,
        seconds: Int,
        inputImages: [WiroFileInput]? = nil,
        resolution: WiroSora2ProResolution? = nil,
        ratio: WiroSora2ProRatio? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireOneOf(
            seconds,
            allowed: [4, 8, 12, 16, 20],
            label: "seconds"
        )
        self.prompt = prompt
        self.seconds = seconds
        self.inputImages = inputImages
        self.resolution = resolution
        self.ratio = ratio
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "prompt": .string(prompt),
            "seconds": WiroRequestEncoding.stringInt(seconds),
        ]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        if let resolution {
            json["resolution"] = .string(resolution.apiValue)
        }
        if let ratio { json["ratio"] = .string(ratio.apiValue) }
        return json
    }
}

/// Typed request for `minimax/hailuo-2-3-fast`.
public struct WiroHailuo23FastRequest: WiroModelRequest, Sendable, Equatable {
    public let inputImages: [WiroFileInput]
    public let duration: Int
    public let prompt: String?
    public let promptOptimizer: Bool?
    public let resolution: WiroHailuo23FastResolution?

    public var model: WiroModelID {
        WiroRequestValidation.model("minimax", "hailuo-2-3-fast")
    }

    public init(
        inputImage: WiroFileInput,
        duration: Int,
        prompt: String? = nil,
        promptOptimizer: Bool? = nil,
        resolution: WiroHailuo23FastResolution? = nil
    ) throws {
        try WiroRequestValidation.requireOneOf(
            duration,
            allowed: [6, 10],
            label: "duration"
        )
        if duration == 10, resolution == .r1080p {
            try WiroRequestValidation.fail(
                "10-second videos are only available at 768P."
            )
        }
        self.inputImages = [inputImage]
        self.duration = duration
        self.prompt = prompt
        self.promptOptimizer = promptOptimizer
        self.resolution = resolution
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "inputImage": WiroRequestEncoding.filesRequired(inputImages),
            "duration": WiroRequestEncoding.stringInt(duration),
        ]
        if let prompt { json["prompt"] = .string(prompt) }
        if let promptOptimizer {
            json["promptOptimizer"] =
                WiroRequestEncoding.stringBool(promptOptimizer)
        }
        if let resolution {
            json["resolution"] = .string(resolution.apiValue)
        }
        return json
    }
}

/// Typed request for `xai/grok-imagine-video`.
public struct WiroGrokImagineVideoRequest: WiroModelRequest, Sendable,
    Equatable
{
    public let prompt: String
    public let duration: Int
    public let aspectRatio: WiroGrokImagineVideoRatio
    public let resolution: WiroGrokImagineVideoResolution
    public let inputImages: [WiroFileInput]?

    public var model: WiroModelID {
        WiroRequestValidation.model("xai", "grok-imagine-video")
    }

    public init(
        prompt: String,
        duration: Int,
        aspectRatio: WiroGrokImagineVideoRatio,
        resolution: WiroGrokImagineVideoResolution,
        inputImages: [WiroFileInput]? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireOneOf(
            duration,
            allowed: [5, 10, 15],
            label: "duration"
        )
        try WiroRequestValidation.requireOptionalCount(
            inputImages,
            max: 1,
            label: "inputImages"
        )
        self.prompt = prompt
        self.duration = duration
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.inputImages = inputImages
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "prompt": .string(prompt),
            "duration": WiroRequestEncoding.stringInt(duration),
            "aspectRatio": .string(aspectRatio.apiValue),
            "resolution": .string(resolution.apiValue),
        ]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        return json
    }
}

/// Typed request for `google/lyria-3`.
public struct WiroLyria3Request: WiroModelRequest, Sendable, Equatable {
    public let prompt: String
    public let inputImages: [WiroFileInput]?

    public var model: WiroModelID {
        WiroRequestValidation.model("google", "lyria-3")
    }

    public init(
        prompt: String,
        inputImages: [WiroFileInput]? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        self.prompt = prompt
        self.inputImages = inputImages
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = ["prompt": .string(prompt)]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        return json
    }
}
