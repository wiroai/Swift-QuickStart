# WiroKit

[![CI](https://github.com/yasinertekinwiro/Swift-QuickStart/actions/workflows/ci.yml/badge.svg)](https://github.com/yasinertekinwiro/Swift-QuickStart/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

Official Swift SDK for discovering and running AI models on
[Wiro](https://wiro.ai).

## Features

- Typed request factories for popular image, video, and audio models
- Dynamic model requests with `Wiro.model("owner/project", parameters:)`
- Model search, explore, and schema validation
- `subscribe` / `run` / `subscribeStream` task lifecycle APIs
- Automatic file uploads for device-local inputs
- Polling and WebSocket task tracking
- Task cancel / kill
- Retry with exponential backoff, timeouts, and structured logging
- API key, HMAC signature, and proxy authentication
- Zero third-party dependencies (Foundation, URLSession, CryptoKit)

## Requirements

- iOS 17.0+
- Swift 6 (Xcode 16 or later)
- A [Wiro project and API key](https://wiro.ai/panel/project/new)

## Installation

### Swift Package Manager

Add WiroKit to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/yasinertekinwiro/Swift-QuickStart.git",
        from: "0.1.0"
    ),
],
```

Or in Xcode choose **File > Add Package Dependencies...** and enter the
repository URL, then link the `WiroKit` product.

## Quick start

```swift
import WiroKit

let client = try WiroClient(apiKey: "your-api-key")

let result = try await client.subscribe(
    Wiro.flux2Pro(
        prompt: "A cinematic mountain lake",
        width: 1024,
        height: 1024
    )
)

switch result {
case .success(let task):
    print(task.outputs.first?.url as Any)
case .failure(_, let reason):
    print("Failed:", reason)
}
```

> **Mobile tip:** Prefer
> `WiroClient(proxyURL:headers:)` in shipped apps so long-lived API
> secrets never ship inside the binary. See
> the [DocC proxy guide](Sources/WiroKit/WiroKit.docc/WiroKit.md#proxy-authentication-for-mobile-apps).

## Which call do I need?

| I want to… | Call |
| --- | --- |
| Generate with a supported model | `client.subscribe(Wiro.flux2Pro(...))` |
| Run any other model | `client.subscribe(Wiro.model("owner/project", parameters: [...]))` |
| Find a model | `client.searchModels(search:)` / `client.explore()` |
| Inspect parameters | `client.getModelSchema(...)` then `schema.validate(...)` |
| Watch progress | `onUpdate:` or `client.subscribeStream(...)` |
| Send a device file | `WiroFileInput.data(bytes, fileName: "photo.png")` |
| Stop work | Cancel the Swift `Task`, or `cancelTask` / `killTask` |

## Documentation

- Product docs: [https://wiro.ai/docs](https://wiro.ai/docs)
- DocC catalog ships with the package (`Sources/WiroKit/WiroKit.docc`)

## License

See the repository license file.
