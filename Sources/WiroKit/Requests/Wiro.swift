import Foundation

/// Discoverable entry point for every typed model request in the SDK.
///
/// Type `Wiro.` in your IDE to list all models with typed parameters.
public enum Wiro {
    /// Runs any Wiro model with dynamic `parameters`.
    ///
    /// - Parameter slug: An `owner/project` identifier.
    /// - Throws: ``WiroError/validation`` when `slug` is malformed.
    public static func model(
        _ slug: String,
        parameters: WiroJSON
    ) throws -> WiroDynamicRequest {
        guard let id = WiroModelID(parsing: slug) else {
            throw WiroError.validation(
                message:
                    "slug must be a valid owner/project identifier.",
                statusCode: 0,
                responseBody: nil
            )
        }
        return WiroDynamicRequest(model: id, parameters: parameters)
    }

    // MARK: - Image

    /// Generates images with `black-forest-labs/flux-2-pro`.
    public static func flux2Pro(
        prompt: String,
        inputImages: [WiroFileInput]? = nil,
        width: Int? = nil,
        height: Int? = nil,
        safetyTolerance: Int? = nil,
        seed: Int? = nil,
        outputFormat: WiroFlux2ProOutputFormat? = nil
    ) throws -> WiroFlux2ProRequest {
        try WiroFlux2ProRequest(
            prompt: prompt,
            inputImages: inputImages,
            width: width,
            height: height,
            safetyTolerance: safetyTolerance,
            seed: seed,
            outputFormat: outputFormat
        )
    }

    /// Generates or edits images with `openai/gpt-image-2`.
    public static func gptImage2(
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
    ) throws -> WiroGptImage2Request {
        try WiroGptImage2Request(
            prompt: prompt,
            resolution: resolution,
            ratio: ratio,
            quality: quality,
            samples: samples,
            inputImages: inputImages,
            inputImageMasks: inputImageMasks,
            background: background,
            outputFormat: outputFormat,
            outputCompression: outputCompression,
            moderation: moderation
        )
    }

    /// Generates or edits images with `google/nano-banana-pro`.
    public static func nanoBananaPro(
        prompt: String,
        inputImages: [WiroFileInput]? = nil,
        aspectRatio: WiroNanoBananaProRatio? = nil,
        resolution: WiroNanoBananaProResolution? = nil,
        safetySetting: WiroNanoBananaProSafetySetting? = nil
    ) throws -> WiroNanoBananaProRequest {
        try WiroNanoBananaProRequest(
            prompt: prompt,
            inputImages: inputImages,
            aspectRatio: aspectRatio,
            resolution: resolution,
            safetySetting: safetySetting
        )
    }

    /// Generates images with `bytedance/seedream-v4`.
    public static func seedreamV4(
        prompt: String,
        size: WiroSeedreamV4Size,
        maxImages: Int,
        watermark: Bool,
        inputImages: [WiroFileInput]? = nil
    ) throws -> WiroSeedreamV4Request {
        try WiroSeedreamV4Request(
            prompt: prompt,
            size: size,
            maxImages: maxImages,
            watermark: watermark,
            inputImages: inputImages
        )
    }

    /// Generates images with `xai/grok-imagine-image`.
    public static func grokImagineImage(
        prompt: String,
        samples: Int,
        resolution: WiroGrokImagineImageResolution,
        inputImages: [WiroFileInput]? = nil,
        aspectRatio: WiroGrokImagineImageRatio? = nil
    ) throws -> WiroGrokImagineImageRequest {
        try WiroGrokImagineImageRequest(
            prompt: prompt,
            samples: samples,
            resolution: resolution,
            inputImages: inputImages,
            aspectRatio: aspectRatio
        )
    }

    /// Upscales an image with `google/upscaler`.
    public static func upscaler(
        inputImage: WiroFileInput,
        upscaleFactor: Int,
        outputType: WiroUpscalerOutputType,
        compressionQuality: Int? = nil
    ) throws -> WiroUpscalerRequest {
        try WiroUpscalerRequest(
            inputImage: inputImage,
            upscaleFactor: upscaleFactor,
            outputType: outputType,
            compressionQuality: compressionQuality
        )
    }

    // MARK: - Video

    /// Generates video with `runway/gen-4-5`.
    public static func runwayGen45(
        prompt: String,
        ratio: WiroRunwayGen45Ratio,
        duration: Int,
        inputImages: [WiroFileInput]? = nil,
        contentModeration: WiroRunwayGen45Moderation? = nil,
        seed: Int? = nil
    ) throws -> WiroRunwayGen45Request {
        try WiroRunwayGen45Request(
            prompt: prompt,
            ratio: ratio,
            duration: duration,
            inputImages: inputImages,
            contentModeration: contentModeration,
            seed: seed
        )
    }

    /// Generates video with `bytedance/seedance-2-0`.
    public static func seedance20(
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
    ) throws -> WiroSeedance20Request {
        try WiroSeedance20Request(
            resolution: resolution,
            ratio: ratio,
            duration: duration,
            generateAudio: generateAudio,
            prompt: prompt,
            inputImage: inputImage,
            lastFrameImage: lastFrameImage,
            referenceImages: referenceImages,
            referenceAudios: referenceAudios,
            promptEnhancement: promptEnhancement,
            watermark: watermark,
            seed: seed
        )
    }

    /// Generates video with `klingai/kling-v3`.
    public static func klingV3(
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
    ) throws -> WiroKlingV3Request {
        try WiroKlingV3Request(
            mode: mode,
            duration: duration,
            ratio: ratio,
            sound: sound,
            prompt: prompt,
            inputImage: inputImage,
            lastFrameImage: lastFrameImage,
            multiShot: multiShot,
            shotType: shotType,
            multiPrompt: multiPrompt
        )
    }

    /// Generates video with `google/veo3-1`.
    public static func veo31(
        durationSeconds: Int,
        prompt: String? = nil,
        inputImage: [WiroFileInput]? = nil,
        lastFrameImage: [WiroFileInput]? = nil,
        referenceImages: [WiroFileInput]? = nil,
        aspectRatio: WiroVeo31Ratio? = nil,
        resolution: WiroVeo31Resolution? = nil,
        negativePrompt: String? = nil,
        seed: Int? = nil
    ) throws -> WiroVeo31Request {
        try WiroVeo31Request(
            durationSeconds: durationSeconds,
            prompt: prompt,
            inputImage: inputImage,
            lastFrameImage: lastFrameImage,
            referenceImages: referenceImages,
            aspectRatio: aspectRatio,
            resolution: resolution,
            negativePrompt: negativePrompt,
            seed: seed
        )
    }

    /// Generates video with `openai/sora-2-pro`.
    public static func sora2Pro(
        prompt: String,
        seconds: Int,
        inputImages: [WiroFileInput]? = nil,
        resolution: WiroSora2ProResolution? = nil,
        ratio: WiroSora2ProRatio? = nil
    ) throws -> WiroSora2ProRequest {
        try WiroSora2ProRequest(
            prompt: prompt,
            seconds: seconds,
            inputImages: inputImages,
            resolution: resolution,
            ratio: ratio
        )
    }

    /// Generates video with `minimax/hailuo-2-3-fast`.
    public static func hailuo23Fast(
        inputImage: WiroFileInput,
        duration: Int,
        prompt: String? = nil,
        promptOptimizer: Bool? = nil,
        resolution: WiroHailuo23FastResolution? = nil
    ) throws -> WiroHailuo23FastRequest {
        try WiroHailuo23FastRequest(
            inputImage: inputImage,
            duration: duration,
            prompt: prompt,
            promptOptimizer: promptOptimizer,
            resolution: resolution
        )
    }

    /// Generates video with `xai/grok-imagine-video`.
    public static func grokImagineVideo(
        prompt: String,
        duration: Int,
        aspectRatio: WiroGrokImagineVideoRatio,
        resolution: WiroGrokImagineVideoResolution,
        inputImages: [WiroFileInput]? = nil
    ) throws -> WiroGrokImagineVideoRequest {
        try WiroGrokImagineVideoRequest(
            prompt: prompt,
            duration: duration,
            aspectRatio: aspectRatio,
            resolution: resolution,
            inputImages: inputImages
        )
    }

    // MARK: - Audio

    /// Generates music with `google/lyria-3`.
    public static func lyria3(
        prompt: String,
        inputImages: [WiroFileInput]? = nil
    ) throws -> WiroLyria3Request {
        try WiroLyria3Request(prompt: prompt, inputImages: inputImages)
    }
}
