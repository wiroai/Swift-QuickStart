import Foundation

/// Typed request for `black-forest-labs/flux-2-pro`.
public struct WiroFlux2ProRequest: WiroModelRequest, Sendable, Equatable {
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?
    /// Output width in pixels (`width`).
    public let width: Int?
    /// Output height in pixels (`height`).
    public let height: Int?
    /// Safety tolerance level (`safetyTolerance`).
    public let safetyTolerance: Int?
    /// Optional random seed (`seed`).
    public let seed: Int?
    /// Output image format (`outputFormat`).
    public let outputFormat: WiroFlux2ProOutputFormat?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("black-forest-labs", "flux-2-pro")
    }

    /// Creates a Flux 2 Pro request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - inputImages: Optional input images (`inputImage`).
    ///   - width: Output width in pixels (`width`).
    ///   - height: Output height in pixels (`height`).
    ///   - safetyTolerance: Safety tolerance level (`safetyTolerance`).
    ///   - seed: Optional random seed (`seed`).
    ///   - outputFormat: Output image format (`outputFormat`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
    public init(
        prompt: String,
        inputImages: [WiroFileInput]? = nil,
        width: Int? = nil,
        height: Int? = nil,
        safetyTolerance: Int? = nil,
        seed: Int? = nil,
        outputFormat: WiroFlux2ProOutputFormat? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireFluxDimension(width, label: "width")
        try WiroRequestValidation.requireFluxDimension(height, label: "height")
        try WiroRequestValidation.requireOptionalRange(
            safetyTolerance,
            min: 0,
            max: 5,
            label: "safetyTolerance"
        )
        try WiroRequestValidation.requireNonNegative(seed, label: "seed")
        self.prompt = prompt
        self.inputImages = inputImages
        self.width = width
        self.height = height
        self.safetyTolerance = safetyTolerance
        self.seed = seed
        self.outputFormat = outputFormat
    }

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
    public func parameters() -> WiroJSON {
        var json: WiroJSON = ["prompt": .string(prompt)]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        if let width { json["width"] = .number(Double(width)) }
        if let height { json["height"] = .number(Double(height)) }
        if let safetyTolerance {
            json["safetyTolerance"] = .number(Double(safetyTolerance))
        }
        if let seed { json["seed"] = .number(Double(seed)) }
        if let outputFormat {
            json["outputFormat"] = .string(outputFormat.apiValue)
        }
        return json
    }
}

/// Typed request for `openai/gpt-image-2`.
public struct WiroGptImage2Request: WiroModelRequest, Sendable, Equatable {
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Output resolution (`resolution`).
    public let resolution: WiroGptImage2Resolution
    /// Aspect ratio (`ratio`).
    public let ratio: WiroGptImage2Ratio
    /// Generation quality (`quality`).
    public let quality: WiroGptImage2Quality
    /// Number of samples to generate (`samples`).
    public let samples: Int
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?
    /// Optional input image masks (`inputImageMask`).
    public let inputImageMasks: [WiroFileInput]?
    /// Background mode (`background`).
    public let background: WiroGptImage2Background?
    /// Output image format (`outputFormat`).
    public let outputFormat: WiroGptImage2OutputFormat?
    /// Output compression level (`outputCompression`).
    public let outputCompression: Int?
    /// Content moderation level (`moderation`).
    public let moderation: WiroGptImage2Moderation?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("openai", "gpt-image-2")
    }

    /// Creates a GPT Image 2 request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - resolution: Output resolution (`resolution`).
    ///   - ratio: Aspect ratio (`ratio`).
    ///   - quality: Generation quality (`quality`).
    ///   - samples: Number of samples to generate (`samples`).
    ///   - inputImages: Optional input images (`inputImage`).
    ///   - inputImageMasks: Optional input image masks (`inputImageMask`).
    ///   - background: Background mode (`background`).
    ///   - outputFormat: Output image format (`outputFormat`).
    ///   - outputCompression: Output compression (`outputCompression`).
    ///   - moderation: Content moderation level (`moderation`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
    public init(
        prompt: String,
        resolution: WiroGptImage2Resolution,
        ratio: WiroGptImage2Ratio,
        quality: WiroGptImage2Quality,
        samples: Int,
        inputImages: [WiroFileInput]? = nil,
        inputImageMasks: [WiroFileInput]? = nil,
        background: WiroGptImage2Background? = nil,
        outputFormat: WiroGptImage2OutputFormat? = nil,
        outputCompression: Int? = nil,
        moderation: WiroGptImage2Moderation? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireMaxLength(
            prompt,
            max: 32_000,
            label: "prompt"
        )
        try WiroRequestValidation.requireRange(
            samples,
            min: 1,
            max: 10,
            label: "samples"
        )
        try WiroRequestValidation.requireOptionalRange(
            outputCompression,
            min: 0,
            max: 100,
            label: "outputCompression"
        )
        self.prompt = prompt
        self.resolution = resolution
        self.ratio = ratio
        self.quality = quality
        self.samples = samples
        self.inputImages = inputImages
        self.inputImageMasks = inputImageMasks
        self.background = background
        self.outputFormat = outputFormat
        self.outputCompression = outputCompression
        self.moderation = moderation
    }

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "prompt": .string(prompt),
            "resolution": .string(resolution.apiValue),
            "ratio": .string(ratio.apiValue),
            "quality": .string(quality.apiValue),
            "samples": .number(Double(samples)),
        ]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        if let files = WiroRequestEncoding.files(inputImageMasks) {
            json["inputImageMask"] = files
        }
        if let background {
            json["background"] = .string(background.apiValue)
        }
        if let outputFormat {
            json["outputFormat"] = .string(outputFormat.apiValue)
        }
        if let outputCompression {
            json["outputCompression"] = .number(Double(outputCompression))
        }
        if let moderation {
            json["moderation"] = .string(moderation.apiValue)
        }
        return json
    }
}

/// Typed request for `google/nano-banana-pro`.
public struct WiroNanoBananaProRequest: WiroModelRequest, Sendable, Equatable {
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?
    /// Aspect ratio (`aspectRatio`).
    public let aspectRatio: WiroNanoBananaProRatio?
    /// Output resolution (`resolution`).
    public let resolution: WiroNanoBananaProResolution?
    /// Safety setting (`safetySetting`).
    public let safetySetting: WiroNanoBananaProSafetySetting?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("google", "nano-banana-pro")
    }

    /// Creates a Nano Banana Pro request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - inputImages: Optional input images (`inputImage`).
    ///   - aspectRatio: Aspect ratio (`aspectRatio`).
    ///   - resolution: Output resolution (`resolution`).
    ///   - safetySetting: Safety setting (`safetySetting`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
    public init(
        prompt: String,
        inputImages: [WiroFileInput]? = nil,
        aspectRatio: WiroNanoBananaProRatio? = nil,
        resolution: WiroNanoBananaProResolution? = nil,
        safetySetting: WiroNanoBananaProSafetySetting? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireOptionalCount(
            inputImages,
            max: 14,
            label: "inputImages"
        )
        self.prompt = prompt
        self.inputImages = inputImages
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.safetySetting = safetySetting
    }

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
    public func parameters() -> WiroJSON {
        var json: WiroJSON = ["prompt": .string(prompt)]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        if let aspectRatio {
            json["aspectRatio"] = .string(aspectRatio.apiValue)
        }
        if let resolution {
            json["resolution"] = .string(resolution.apiValue)
        }
        if let safetySetting {
            json["safetySetting"] = .string(safetySetting.apiValue)
        }
        return json
    }
}

/// Typed request for `bytedance/seedream-v4`.
public struct WiroSeedreamV4Request: WiroModelRequest, Sendable, Equatable {
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Output size (`size`).
    public let size: WiroSeedreamV4Size
    /// Maximum number of images (`maxImages`).
    public let maxImages: Int
    /// Whether to include a watermark (`watermark`).
    public let watermark: Bool
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("bytedance", "seedream-v4")
    }

    /// Creates a Seedream V4 request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - size: Output size (`size`).
    ///   - maxImages: Maximum number of images (`maxImages`).
    ///   - watermark: Whether to include a watermark (`watermark`).
    ///   - inputImages: Optional input images (`inputImage`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
    public init(
        prompt: String,
        size: WiroSeedreamV4Size,
        maxImages: Int,
        watermark: Bool,
        inputImages: [WiroFileInput]? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireRange(
            maxImages,
            min: 1,
            max: 15,
            label: "maxImages"
        )
        self.prompt = prompt
        self.size = size
        self.maxImages = maxImages
        self.watermark = watermark
        self.inputImages = inputImages
    }

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "prompt": .string(prompt),
            "size": .string(size.apiValue),
            "maxImages": .number(Double(maxImages)),
            "watermark": WiroRequestEncoding.stringBool(watermark),
        ]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        return json
    }
}

/// Typed request for `xai/grok-imagine-image`.
public struct WiroGrokImagineImageRequest: WiroModelRequest, Sendable,
    Equatable
{
    /// Text prompt (`prompt`).
    public let prompt: String
    /// Number of samples to generate (`samples`).
    public let samples: Int
    /// Output resolution (`resolution`).
    public let resolution: WiroGrokImagineImageResolution
    /// Optional input images (`inputImage`).
    public let inputImages: [WiroFileInput]?
    /// Aspect ratio (`aspectRatio`).
    public let aspectRatio: WiroGrokImagineImageRatio?

    /// Target model identifier (`owner/project`).
    public var model: WiroModelID {
        WiroRequestValidation.model("xai", "grok-imagine-image")
    }

    /// Creates a Grok Imagine Image request.
    ///
    /// - Parameters:
    ///   - prompt: Text prompt (`prompt`).
    ///   - samples: Number of samples to generate (`samples`).
    ///   - resolution: Output resolution (`resolution`).
    ///   - inputImages: Optional input images (`inputImage`).
    ///   - aspectRatio: Aspect ratio (`aspectRatio`).
    /// - Throws: `WiroError.validation` when a constraint is violated.
    public init(
        prompt: String,
        samples: Int,
        resolution: WiroGrokImagineImageResolution,
        inputImages: [WiroFileInput]? = nil,
        aspectRatio: WiroGrokImagineImageRatio? = nil
    ) throws {
        try WiroRequestValidation.requireNonEmpty(prompt, label: "prompt")
        try WiroRequestValidation.requireRange(
            samples,
            min: 1,
            max: 10,
            label: "samples"
        )
        try WiroRequestValidation.requireOptionalCount(
            inputImages,
            max: 1,
            label: "inputImages"
        )
        self.prompt = prompt
        self.samples = samples
        self.resolution = resolution
        self.inputImages = inputImages
        self.aspectRatio = aspectRatio
    }

    /// Builds the wire JSON dictionary for `/Run`, including unresolved
    /// file inputs.
    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "prompt": .string(prompt),
            "samples": .number(Double(samples)),
            "resolution": .string(resolution.apiValue),
        ]
        if let files = WiroRequestEncoding.files(inputImages) {
            json["inputImage"] = files
        }
        if let aspectRatio {
            json["aspectRatio"] = .string(aspectRatio.apiValue)
        }
        return json
    }
}
