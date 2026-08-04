import Foundation

/// Typed request for `runway/gen-4-5`.
public struct WiroRunwayGen45Request: WiroModelRequest, Sendable, Equatable {
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Output aspect ratio (`ratio`).
    public let ratio: WiroRunwayGen45Ratio
    /// Clip duration in seconds (`duration`).
    public let duration: Int
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?
    /// Optional content moderation setting (`contentModeration`).
    public let contentModeration: WiroRunwayGen45Moderation?
    /// Optional random seed (`seed`).
    public let seed: Int?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("runway", "gen-4-5")
    }

    /// Creates a Runway Gen 4.5 request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - ratio: Output aspect ratio (`ratio`).
    ///   - duration: Clip duration in seconds (`duration`).
    ///   - inputImages: Optional input images (`inputImage`).
    ///   - contentModeration: Optional moderation (`contentModeration`).
    ///   - seed: Optional random seed (`seed`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Output resolution (`resolution`).
    public let resolution: WiroSeedance20Resolution
    /// Output aspect ratio (`ratio`).
    public let ratio: WiroSeedance20Ratio
    /// Clip duration in seconds (`duration`).
    public let duration: Int
    /// Whether to generate audio (`generateAudio`).
    public let generateAudio: Bool
    /// Optional text prompt (`prompt`).
    public let prompt: String?
    /// Optional first-frame images (`inputImage`).
    public let inputImage: [WiroFileInput]?
    /// Optional last-frame images (`inputImageLast`).
    public let lastFrameImage: [WiroFileInput]?
    /// Optional reference images (`inputImageReference`).
    public let referenceImages: [WiroFileInput]?
    /// Optional reference audios (`inputAudio`).
    public let referenceAudios: [WiroFileInput]?
    /// Optional prompt enhancement flag (`promptEnhancement`).
    public let promptEnhancement: Bool?
    /// Optional watermark flag (`watermark`).
    public let watermark: Bool?
    /// Optional random seed (`seed`).
    public let seed: Int?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("bytedance", "seedance-2-0")
    }

    /// Creates a Seedance 2.0 request.
    ///
    /// - Parameters:
    ///   - resolution: Output resolution (`resolution`).
    ///   - ratio: Output aspect ratio (`ratio`).
    ///   - duration: Clip duration in seconds (`duration`).
    ///   - generateAudio: Whether to generate audio (`generateAudio`).
    ///   - prompt: Optional text prompt (`prompt`).
    ///   - inputImage: Optional first-frame images (`inputImage`).
    ///   - lastFrameImage: Optional last-frame images (`inputImageLast`).
    ///   - referenceImages: Optional reference images
    ///     (`inputImageReference`).
    ///   - referenceAudios: Optional reference audios (`inputAudio`).
    ///   - promptEnhancement: Optional prompt enhancement
    ///     (`promptEnhancement`).
    ///   - watermark: Optional watermark flag (`watermark`).
    ///   - seed: Optional random seed (`seed`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Generation mode (`mode`).
    public let mode: WiroKlingV3Mode
    /// Clip duration in seconds (`duration`).
    public let duration: Int
    /// Output aspect ratio (`ratio`).
    public let ratio: WiroKlingV3Ratio
    /// Whether to include sound (`sound`).
    public let sound: Bool
    /// Optional text prompt (`prompt`).
    public let prompt: String?
    /// Optional first-frame images (`inputImage`).
    public let inputImage: [WiroFileInput]?
    /// Optional last-frame images (`inputImage2`).
    public let lastFrameImage: [WiroFileInput]?
    /// Optional multi-shot flag (`multiShot`).
    public let multiShot: Bool?
    /// Optional multi-shot type (`shotType`).
    public let shotType: WiroKlingV3ShotType?
    /// Optional multi-shot prompt (`multiPrompt`).
    public let multiPrompt: String?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("klingai", "kling-v3")
    }

    /// Creates a Kling v3 request.
    ///
    /// - Parameters:
    ///   - mode: Generation mode (`mode`).
    ///   - duration: Clip duration in seconds (`duration`).
    ///   - ratio: Output aspect ratio (`ratio`).
    ///   - sound: Whether to include sound (`sound`).
    ///   - prompt: Optional text prompt (`prompt`).
    ///   - inputImage: Optional first-frame images (`inputImage`).
    ///   - lastFrameImage: Optional last-frame images (`inputImage2`).
    ///   - multiShot: Optional multi-shot flag (`multiShot`).
    ///   - shotType: Optional multi-shot type (`shotType`).
    ///   - multiPrompt: Optional multi-shot prompt (`multiPrompt`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Clip duration in seconds (`durationSeconds`).
    public let durationSeconds: Int
    /// Optional text prompt (`prompt`).
    public let prompt: String?
    /// Optional first-frame images (`inputImage`).
    public let inputImage: [WiroFileInput]?
    /// Optional last-frame images (`inputImage2`).
    public let lastFrameImage: [WiroFileInput]?
    /// Optional reference images (`inputImage3`).
    public let referenceImages: [WiroFileInput]?
    /// Optional aspect ratio (`aspectRatio`).
    public let aspectRatio: WiroVeo31Ratio?
    /// Optional output resolution (`resolution`).
    public let resolution: WiroVeo31Resolution?
    /// Optional negative prompt (`negativePrompt`).
    public let negativePrompt: String?
    /// Optional random seed (`seed`).
    public let seed: Int?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("google", "veo3-1")
    }

    /// Creates a Veo 3.1 request.
    ///
    /// - Parameters:
    ///   - durationSeconds: Clip duration in seconds (`durationSeconds`).
    ///   - prompt: Optional text prompt (`prompt`).
    ///   - inputImage: Optional first-frame images (`inputImage`).
    ///   - lastFrameImage: Optional last-frame images (`inputImage2`).
    ///   - referenceImages: Optional reference images (`inputImage3`).
    ///   - aspectRatio: Optional aspect ratio (`aspectRatio`).
    ///   - resolution: Optional output resolution (`resolution`).
    ///   - negativePrompt: Optional negative prompt (`negativePrompt`).
    ///   - seed: Optional random seed (`seed`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Clip duration in seconds (`seconds`).
    public let seconds: Int
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?
    /// Optional output resolution (`resolution`).
    public let resolution: WiroSora2ProResolution?
    /// Optional aspect ratio (`ratio`).
    public let ratio: WiroSora2ProRatio?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("openai", "sora-2-pro")
    }

    /// Creates a Sora 2 Pro request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - seconds: Clip duration in seconds (`seconds`).
    ///   - inputImages: Optional input images (`inputImage`).
    ///   - resolution: Optional output resolution (`resolution`).
    ///   - ratio: Optional aspect ratio (`ratio`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Required input images (`inputImage`).
    public let inputImages: [WiroFileInput]
    /// Clip duration in seconds (`duration`).
    public let duration: Int
    /// Optional text prompt (`prompt`).
    public let prompt: String?
    /// Optional prompt optimizer flag (`promptOptimizer`).
    public let promptOptimizer: Bool?
    /// Optional output resolution (`resolution`).
    public let resolution: WiroHailuo23FastResolution?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("minimax", "hailuo-2-3-fast")
    }

    /// Creates a Hailuo 2.3 Fast request.
    ///
    /// - Parameters:
    ///   - inputImage: Required input image (`inputImage`).
    ///   - duration: Clip duration in seconds (`duration`).
    ///   - prompt: Optional text prompt (`prompt`).
    ///   - promptOptimizer: Optional prompt optimizer (`promptOptimizer`).
    ///   - resolution: Optional output resolution (`resolution`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Clip duration in seconds (`duration`).
    public let duration: Int
    /// Output aspect ratio (`aspectRatio`).
    public let aspectRatio: WiroGrokImagineVideoRatio
    /// Output resolution (`resolution`).
    public let resolution: WiroGrokImagineVideoResolution
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("xai", "grok-imagine-video")
    }

    /// Creates a Grok Imagine Video request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - duration: Clip duration in seconds (`duration`).
    ///   - aspectRatio: Output aspect ratio (`aspectRatio`).
    ///   - resolution: Output resolution (`resolution`).
    ///   - inputImages: Optional input images (`inputImage`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
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

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
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
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("google", "lyria-3")
    }

    /// Creates a Lyria 3 request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - inputImages: Optional input images (`inputImage`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
    public init(
        prompt: String,
        inputImages: [WiroFileInput]? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        self.prompt = prompt
        self.inputImages = inputImages
    }

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
    public func parameters() -> WiroJSON {
        var json: WiroJSON = ["prompt": .string(prompt)]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        return json
    }
}
