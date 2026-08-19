<div align="center">

<img src="https://wiro.ai/images/logos/logo/logo.png" alt="Wiro" width="180" />

# WiroKit for iOS

**Official Swift SDK for discovering and running AI models on [Wiro](https://wiro.ai)**

[![CI](https://img.shields.io/github/actions/workflow/status/wiroai/Swift-QuickStart/ci.yml?style=for-the-badge&label=CI)](https://github.com/wiroai/Swift-QuickStart/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6-orange?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17%2B-blue?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen?style=for-the-badge)](https://swift.org/package-manager/)
[![MIT](https://img.shields.io/badge/license-MIT-6f42c1?style=for-the-badge)](LICENSE)

[Docs](https://wiro.ai/docs) · [Models](https://wiro.ai/models) · [Dashboard](https://wiro.ai/panel) · [Create Project](https://wiro.ai/panel/project/new)

</div>

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
        url: "https://github.com/wiroai/Swift-QuickStart.git",
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

> **Mobile tip:** Prefer `WiroClient(proxyURL:headers:)` in shipped apps so
> long-lived API secrets never ship inside the binary.

## Authentication

### API key

```swift
let client = try WiroClient(apiKey: "your-api-key")
```

### API key + HMAC signature

```swift
let client = try WiroClient(
    apiKey: "your-api-key",
    apiSecret: "your-api-secret"
)
```

Signature mode sends `x-api-key`, `x-nonce`, and an HMAC-SHA256
`x-signature` header. The configured credentials must match the
authentication type selected for the Wiro project.

### Proxy (recommended for production)

```swift
let client = try WiroClient(
    proxyURL: URL(string: "https://api.myapp.com/wiro/v1")!,
    headers: ["Authorization": "Bearer \(sessionToken)"]
)
```

Your backend attaches Wiro credentials server-side. The SDK never stores an
API key in proxy mode. Task WebSocket streams still connect directly to Wiro
because they authenticate with per-task tokens.

## Which call do I need?

| I want to… | Call |
| --- | --- |
| Generate with a supported model | `client.subscribe(Wiro.flux2Pro(...))` |
| Run any other model | `client.subscribe(Wiro.model("owner/project", parameters: [...]))` |
| Fire-and-forget then wait | `run` / `runModel`, then `waitForTask` |
| Stream live status updates | `subscribeStream(...)` |
| Find a model | `searchModels(search:)` / `explore()` |
| Inspect parameters | `getModelSchema(...)`, then `schema.validate(...)` |
| Send device bytes | `WiroFileInput.data(bytes, fileName: "photo.png")` |
| Send a hosted file | `WiroFileInput.url(url)` |
| Stop work | Cancel the Swift `Task`, or `cancelTask` / `killTask` |

## Typed and dynamic requests

Typed factories check required parameters, value ranges, and select options
at compile time. Type `Wiro.` in Xcode to list them.

| Category | Models |
| --- | --- |
| Image | FLUX.2 Pro, GPT Image 2, Nano Banana Pro, Seedream v4, Grok Imagine Image |
| Video | Runway Gen-4.5, Seedance 2.0, Kling V3, Veo 3.1, Sora 2 Pro, Hailuo 2.3 Fast, Grok Imagine Video |
| Music | Lyria 3 |

```swift
// Typed
let request = try Wiro.flux2Pro(
    prompt: "Sunset over the bay",
    width: 1024,
    height: 1024
)

// Dynamic
let dynamic = try Wiro.model(
    "black-forest-labs/flux-2-pro",
    parameters: [
        "prompt": "Sunset over the bay",
        "width": 1024,
        "height": 1024,
    ]
)
```

Read the accepted parameters before running a model:

```swift
let schema = try await client.getModelSchema(
    WiroModelID(parsing: "openai/sora-2")!
)
let problems = schema.validate(["prompt": "A cinematic mountain lake"])
```

`validate` returns human-readable problems and an empty array when the
parameters satisfy the schema.

## Polling and WebSocket tracking

Polling is the default tracking mode:

```swift
let result = try await client.subscribe(
    Wiro.flux2Pro(prompt: "A cinematic mountain lake"),
    onUpdate: { update in
        print(update.status as Any)
    }
)
```

Use WebSocket tracking for realtime events:

```swift
let result = try await client.subscribe(
    Wiro.flux2Pro(prompt: "A cinematic mountain lake"),
    trackingMode: .webSocket
)
```

Use `subscribeStream` when a `for try await` loop is more convenient than a
callback:

```swift
for try await update in try await client.subscribeStream(
    Wiro.flux2Pro(prompt: "A cinematic mountain lake")
) {
    print(update.status as Any)
}
```

WebSocket tracking falls back to polling when the socket closes before a
terminal event. To manage submission and tracking separately:

```swift
let run = try await client.run(
    Wiro.flux2Pro(prompt: "A cinematic mountain lake")
)
guard let token = run.taskToken else { return }
let task = try await client.waitForTask(token)
```

## Uploads

File parameters take `WiroFileInput` values. Unresolved file inputs are
uploaded automatically before `/Run`.

```swift
// Device-local bytes
let input = WiroFileInput.data(imageData, fileName: "photo.png")

// Already-hosted file
let hosted = WiroFileInput.url(
    URL(string: "https://example.com/photo.png")!
)

let result = try await client.subscribe(
    Wiro.model("owner/project", parameters: ["image": .fileInput(input)])
)
```

To manage uploads yourself, call `uploadFile(_:fileName:)` for in-memory
bytes, or `uploadFile(at:fileName:)` to stream a local file from disk
without loading it fully into memory:

```swift
let upload = try await client.uploadFile(imageData, fileName: "photo.png")
let url = upload.files.first?.url
```

## Task cancellation and lifecycle

- Cancel the Swift `Task` that awaits a call to stop local work
  immediately; the SDK surfaces `WiroError.cancelled`.
- Call `cancelTask(taskID)` when a queued task id is known.
- Call `killTask(token)` or `killTask(taskID)` to stop a remote worker.
- Tie tracking to the owning view or model lifetime so navigation does not
  leak work. Do not auto-restart a billable run after a relaunch unless the
  user explicitly taps Generate again.

Model runs and file uploads are never retried automatically because they can
create duplicate billable work. Retries apply to read-like operations such as
model and task lookup, and rate-limit retries respect `Retry-After`.

## Errors

```swift
do {
    _ = try await client.explore()
} catch let error as WiroError {
    switch error {
    case .apiResult(let message, let code, _, _):
        print(code as Any, message)
    case .authentication:
        break
    case .validation, .schemaValidation:
        break
    case .rateLimited(_, _, let retryAfter, _):
        print(retryAfter as Any)
    case .network, .webSocket, .timedOut:
        break
    case .cancelled:
        break
    case .unknownAPI(let message, let statusCode, _):
        print(statusCode, message)
    }
}
```

Wiro can report application-level failures with HTTP 2xx and
`"result": false`. Those responses surface as `WiroError.apiResult`.

## Security guidance

- Ship App Store builds in proxy mode.
- Never log API keys, secrets, proxy tokens, or raw response bodies.
- Error descriptions exclude credentials, headers, and request bodies; use
  `responseBody` only for local diagnostics.
- Do not commit credentials to the repository.

## Example app

```bash
open Example/WiroExample.xcodeproj
```

Configure an API key or proxy URL in **Settings**, enter a prompt, and tap
**Generate**. See [`Example/README.md`](Example/README.md).

## Documentation

- Product docs: [https://wiro.ai/docs](https://wiro.ai/docs)
- Available models: [https://wiro.ai/models](https://wiro.ai/models)
- DocC catalog: `Sources/WiroKit/WiroKit.docc`
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Security policy: [`SECURITY.md`](SECURITY.md)
- Contributing guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Development

```bash
xcodebuild test -scheme WiroKit \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES

xcodebuild docbuild -scheme WiroKit \
  -destination 'generic/platform=iOS'

xcodebuild build -project Example/WiroExample.xcodeproj \
  -scheme WiroExample \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

<img src="https://wiro.ai/images/koala/accent-heavy-koala.png" alt="Wiro" width="80" />

**Built with 💚 by the Wiro team**

[wiro.ai](https://wiro.ai) · [GitHub @wiroai](https://github.com/wiroai)

</div>
