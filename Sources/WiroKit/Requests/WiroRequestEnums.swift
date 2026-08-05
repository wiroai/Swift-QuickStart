import Foundation

/// Wire values for ``WiroFlux2ProOutputFormat``.
public enum WiroFlux2ProOutputFormat: String, Sendable, Equatable, Hashable {
    /// Wire value `jpeg`.
    case jpeg
    /// Wire value `png`.
    case png

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGptImage2Resolution``.
public enum WiroGptImage2Resolution: String, Sendable, Equatable, Hashable {
    /// Wire value `1k`.
    case r1k = "1k"
    /// Wire value `2k`.
    case r2k = "2k"
    /// Wire value `4k`.
    case r4k = "4k"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGptImage2Ratio``.
public enum WiroGptImage2Ratio: String, Sendable, Equatable, Hashable {
    /// Wire value `1:1`.
    case square = "1:1"
    /// Wire value `3:2`.
    case landscape3x2 = "3:2"
    /// Wire value `2:3`.
    case portrait2x3 = "2:3"
    /// Wire value `4:3`.
    case standard4x3 = "4:3"
    /// Wire value `3:4`.
    case portrait3x4 = "3:4"
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGptImage2Quality``.
public enum WiroGptImage2Quality: String, Sendable, Equatable, Hashable {
    /// Wire value `low`.
    case low
    /// Wire value `medium`.
    case medium
    /// Wire value `high`.
    case high

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGptImage2Background``.
public enum WiroGptImage2Background: String, Sendable, Equatable, Hashable {
    /// Wire value `auto`.
    case auto
    /// Wire value `opaque`.
    case opaque

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGptImage2OutputFormat``.
public enum WiroGptImage2OutputFormat: String, Sendable, Equatable, Hashable {
    /// Wire value `png`.
    case png
    /// Wire value `jpeg`.
    case jpeg
    /// Wire value `webp`.
    case webp

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGptImage2Moderation``.
public enum WiroGptImage2Moderation: String, Sendable, Equatable, Hashable {
    /// Wire value `auto`.
    case auto
    /// Wire value `low`.
    case low

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroNanoBananaProRatio``.
public enum WiroNanoBananaProRatio: String, Sendable, Equatable, Hashable {
    /// Wire value `1:1`.
    case square = "1:1"
    /// Wire value `2:3`.
    case portrait2x3 = "2:3"
    /// Wire value `3:2`.
    case landscape3x2 = "3:2"
    /// Wire value `3:4`.
    case portrait3x4 = "3:4"
    /// Wire value `4:3`.
    case standard4x3 = "4:3"
    /// Wire value `4:5`.
    case portrait4x5 = "4:5"
    /// Wire value `5:4`.
    case landscape5x4 = "5:4"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `21:9`.
    case ultrawide21x9 = "21:9"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroNanoBananaProResolution``.
public enum WiroNanoBananaProResolution: String, Sendable, Equatable, Hashable {
    /// Wire value `1K`.
    case r1k = "1K"
    /// Wire value `2K`.
    case r2k = "2K"
    /// Wire value `4K`.
    case r4k = "4K"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroNanoBananaProSafetySetting``.
public enum WiroNanoBananaProSafetySetting: String, Sendable, Equatable, Hashable {
    /// Wire value `BLOCK_LOW_AND_ABOVE`.
    case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
    /// Wire value `BLOCK_MEDIUM_AND_ABOVE`.
    case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
    /// Wire value `BLOCK_ONLY_HIGH`.
    case blockOnlyHigh = "BLOCK_ONLY_HIGH"
    /// Wire value `BLOCK_NONE`.
    case blockNone = "BLOCK_NONE"
    /// Wire value `OFF`.
    case off = "OFF"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroSeedreamV4Size``.
public enum WiroSeedreamV4Size: String, Sendable, Equatable, Hashable {
    /// Wire value `2048x2048`.
    case square2048 = "2048x2048"
    /// Wire value `2304x1728`.
    case landscape2304x1728 = "2304x1728"
    /// Wire value `1728x2304`.
    case portrait1728x2304 = "1728x2304"
    /// Wire value `2560x1440`.
    case landscape2560x1440 = "2560x1440"
    /// Wire value `1440x2560`.
    case portrait1440x2560 = "1440x2560"
    /// Wire value `2496x1664`.
    case landscape2496x1664 = "2496x1664"
    /// Wire value `1664x2496`.
    case portrait1664x2496 = "1664x2496"
    /// Wire value `3024x1296`.
    case panorama3024x1296 = "3024x1296"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGrokImagineImageRatio``.
public enum WiroGrokImagineImageRatio: String, Sendable, Equatable, Hashable {
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `1:1`.
    case square = "1:1"
    /// Wire value `4:3`.
    case standard4x3 = "4:3"
    /// Wire value `3:4`.
    case portrait3x4 = "3:4"
    /// Wire value `3:2`.
    case landscape3x2 = "3:2"
    /// Wire value `2:3`.
    case portrait2x3 = "2:3"
    /// Wire value `2:1`.
    case landscape2x1 = "2:1"
    /// Wire value `1:2`.
    case portrait1x2 = "1:2"
    /// Wire value `19.5:9`.
    case landscape19_5x9 = "19.5:9"
    /// Wire value `9:19.5`.
    case portrait9x19_5 = "9:19.5"
    /// Wire value `20:9`.
    case landscape20x9 = "20:9"
    /// Wire value `9:20`.
    case portrait9x20 = "9:20"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGrokImagineImageResolution``.
public enum WiroGrokImagineImageResolution: String, Sendable, Equatable, Hashable {
    /// Wire value `1k`.
    case r1k = "1k"
    /// Wire value `2k`.
    case r2k = "2k"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroRunwayGen45Ratio``.
public enum WiroRunwayGen45Ratio: String, Sendable, Equatable, Hashable {
    /// Wire value `auto`.
    case auto
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `1:1`.
    case square = "1:1"
    /// Wire value `4:3`.
    case standard4x3 = "4:3"
    /// Wire value `3:4`.
    case portrait3x4 = "3:4"
    /// Wire value `21:9`.
    case ultrawide21x9 = "21:9"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroRunwayGen45Moderation``.
public enum WiroRunwayGen45Moderation: String, Sendable, Equatable, Hashable {
    /// Wire value `auto`.
    case auto
    /// Wire value `low`.
    case low

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroSeedance20Resolution``.
public enum WiroSeedance20Resolution: String, Sendable, Equatable, Hashable {
    /// Wire value `480p`.
    case r480p = "480p"
    /// Wire value `720p`.
    case r720p = "720p"
    /// Wire value `1080p`.
    case r1080p = "1080p"
    /// Wire value `4k`.
    case r4k = "4k"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroSeedance20Ratio``.
public enum WiroSeedance20Ratio: String, Sendable, Equatable, Hashable {
    /// Wire value `adaptive`.
    case adaptive
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `4:3`.
    case standard4x3 = "4:3"
    /// Wire value `1:1`.
    case square = "1:1"
    /// Wire value `3:4`.
    case portrait3x4 = "3:4"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `21:9`.
    case ultrawide21x9 = "21:9"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroKlingV3Mode``.
public enum WiroKlingV3Mode: String, Sendable, Equatable, Hashable {
    /// Wire value `std`.
    case std
    /// Wire value `pro`.
    case pro
    /// Wire value `4k`.
    case ultra4k = "4k"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroKlingV3Ratio``.
public enum WiroKlingV3Ratio: String, Sendable, Equatable, Hashable {
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `1:1`.
    case square = "1:1"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroKlingV3ShotType``.
public enum WiroKlingV3ShotType: String, Sendable, Equatable, Hashable {
    /// Wire value `customize`.
    case customize
    /// Wire value `intelligence`.
    case intelligence

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroVeo31Ratio``.
public enum WiroVeo31Ratio: String, Sendable, Equatable, Hashable {
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `match_input_image`.
    case matchInputImage = "match_input_image"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroVeo31Resolution``.
public enum WiroVeo31Resolution: String, Sendable, Equatable, Hashable {
    /// Wire value `720p`.
    case r720p = "720p"
    /// Wire value `1080p`.
    case r1080p = "1080p"
    /// Wire value `4k`.
    case r4k = "4k"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroSora2ProResolution``.
public enum WiroSora2ProResolution: String, Sendable, Equatable, Hashable {
    /// Wire value `720p`.
    case r720p = "720p"
    /// Wire value `1024p`.
    case r1024p = "1024p"
    /// Wire value `1080p`.
    case r1080p = "1080p"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroSora2ProRatio``.
public enum WiroSora2ProRatio: String, Sendable, Equatable, Hashable {
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `auto`.
    case auto

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroHailuo23FastResolution``.
public enum WiroHailuo23FastResolution: String, Sendable, Equatable, Hashable {
    /// Wire value `768P`.
    case r768p = "768P"
    /// Wire value `1080P`.
    case r1080p = "1080P"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGrokImagineVideoRatio``.
public enum WiroGrokImagineVideoRatio: String, Sendable, Equatable, Hashable {
    /// Wire value `auto`.
    case auto
    /// Wire value `16:9`.
    case landscape16x9 = "16:9"
    /// Wire value `9:16`.
    case portrait9x16 = "9:16"
    /// Wire value `1:1`.
    case square = "1:1"
    /// Wire value `4:3`.
    case standard4x3 = "4:3"
    /// Wire value `3:4`.
    case portrait3x4 = "3:4"
    /// Wire value `3:2`.
    case landscape3x2 = "3:2"
    /// Wire value `2:3`.
    case portrait2x3 = "2:3"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}

/// Wire values for ``WiroGrokImagineVideoResolution``.
public enum WiroGrokImagineVideoResolution: String, Sendable, Equatable, Hashable {
    /// Wire value `480p`.
    case r480p = "480p"
    /// Wire value `720p`.
    case r720p = "720p"

    /// Value sent to the Wiro API.
    public var apiValue: String { rawValue }
}
