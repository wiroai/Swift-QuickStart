import Foundation

/// Typed request for `black-forest-labs/flux-2-pro`.
public struct WiroFlux2ProRequest: WiroModelRequest, Sendable, Equatable {
    public let prompt: String
    public let inputImages: [WiroFileInput]?
    public let width: Int?
    public let height: Int?
    public let safetyTolerance: Int?
    public let seed: Int?
    public let outputFormat: WiroFlux2ProOutputFormat?

    public var model: WiroModelID {
        WiroRequestValidation.model("black-forest-labs", "flux-2-pro")
    }

    /// Creates a Flux 2 Pro request.
    ///
    /// - Throws: ``WiroError/validation`` when a constraint is violated.
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
    public let prompt: String
    public let resolution: WiroGptImage2Resolution
    public let ratio: WiroGptImage2Ratio
    public let quality: WiroGptImage2Quality
    public let samples: Int
    public let inputImages: [WiroFileInput]?
    public let inputImageMasks: [WiroFileInput]?
    public let background: WiroGptImage2Background?
    public let outputFormat: WiroGptImage2OutputFormat?
    public let outputCompression: Int?
    public let moderation: WiroGptImage2Moderation?

    public var model: WiroModelID {
        WiroRequestValidation.model("openai", "gpt-image-2")
    }

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
    public let prompt: String
    public let inputImages: [WiroFileInput]?
    public let aspectRatio: WiroNanoBananaProRatio?
    public let resolution: WiroNanoBananaProResolution?
    public let safetySetting: WiroNanoBananaProSafetySetting?

    public var model: WiroModelID {
        WiroRequestValidation.model("google", "nano-banana-pro")
    }

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
    public let prompt: String
    public let size: WiroSeedreamV4Size
    public let maxImages: Int
    public let watermark: Bool
    public let inputImages: [WiroFileInput]?

    public var model: WiroModelID {
        WiroRequestValidation.model("bytedance", "seedream-v4")
    }

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
    public let prompt: String
    public let samples: Int
    public let resolution: WiroGrokImagineImageResolution
    public let inputImages: [WiroFileInput]?
    public let aspectRatio: WiroGrokImagineImageRatio?

    public var model: WiroModelID {
        WiroRequestValidation.model("xai", "grok-imagine-image")
    }

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

/// Typed request for `google/upscaler`.
public struct WiroUpscalerRequest: WiroModelRequest, Sendable, Equatable {
    public let inputImages: [WiroFileInput]
    public let upscaleFactor: Int
    public let outputType: WiroUpscalerOutputType
    public let compressionQuality: Int?

    public var model: WiroModelID {
        WiroRequestValidation.model("google", "upscaler")
    }

    /// Creates an upscaler request.
    ///
    /// - Parameter inputImage: A single required input image (matches the
    ///   Dart factory wrapping a list).
    public init(
        inputImage: WiroFileInput,
        upscaleFactor: Int,
        outputType: WiroUpscalerOutputType,
        compressionQuality: Int? = nil
    ) throws {
        try WiroRequestValidation.requireOptionalRange(
            compressionQuality,
            min: 0,
            max: 100,
            label: "compressionQuality"
        )
        self.inputImages = [inputImage]
        self.upscaleFactor = upscaleFactor
        self.outputType = outputType
        self.compressionQuality = compressionQuality
    }

    public func parameters() -> WiroJSON {
        var json: WiroJSON = [
            "inputImage": WiroRequestEncoding.filesRequired(inputImages),
            "upscaleFactor": .number(Double(upscaleFactor)),
            "outputType": .string(outputType.apiValue),
        ]
        if let compressionQuality {
            json["compressionQuality"] = .number(Double(compressionQuality))
        }
        return json
    }
}
