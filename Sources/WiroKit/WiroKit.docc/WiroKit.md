# ``WiroKit``

The official Swift SDK for discovering and running AI models on Wiro.

## Overview

WiroKit is a Swift 6 package for iOS 17+ with zero third-party dependencies.
Use it to search models, submit runs, stream task progress over polling or
WebSocket, upload files, and cancel or kill tasks — all through a single
``WiroClient`` actor. Learn more at [wiro.ai](https://wiro.ai).

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(
        url: "https://github.com/wiroai/Swift-QuickStart.git",
        from: "0.1.0"
    ),
],
```

Then link the `WiroKit` product to your app target.

## Quick start

Subscribe to a typed model request and wait for the terminal result:

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
case .failure(let task, let reason):
    print("Failed:", reason, task.status)
}
```

## Which API should I use?

| I want to… | Call |
|---|---|
| Generate with a supported model and wait | `subscribe(Wiro.flux2Pro(...))` |
| Fire a run without waiting | `run(...)` then `waitForTask(...)` |
| Stream live status updates | `subscribeStream(...)` |
| Run any other model | `Wiro.model("owner/project", parameters:)` |
| Find a model | `searchModels` or `explore` |
| Inspect parameters | `getModelSchema` then `schema.validate` |
| Send a device file | `WiroFileInput.data(_:fileName:)` |
| Stop work | Cancel the Swift `Task`, or `cancelTask` / `killTask` |

## File inputs

Wrap already-hosted files with ``WiroFileInput/url(_:)`` or local bytes with
``WiroFileInput/data(_:fileName:)``. Embed them in parameters as
``WiroJSONValue/fileInput(_:)`` arrays. ``WiroClient`` resolves and uploads
file inputs automatically before the billable `/Run` call.

## Polling vs WebSocket tracking

- ``WiroTaskTrackingMode/polling`` (default) repeatedly calls `/Task/Detail`
  using ``WiroClient/pollInterval``.
- ``WiroTaskTrackingMode/webSocket`` opens ``WiroClient/socketURL``, sends a
  `task_info` handshake, and streams ``WiroSocketEvent`` values. If the
  socket closes without a terminal event, the client fetches task detail
  once and falls back to polling for the remaining timeout budget.

Use ``WiroClient/watchTask(_:timeout:)`` or
``WiroClient/watchTaskSocket(_:timeout:)`` when you already have a
``WiroTaskToken``.

## Proxy authentication for mobile apps

> Important: Do **not** embed long-lived Wiro API keys or secrets in App
> Store builds. Prefer a backend proxy that attaches credentials
> server-side.

```swift
let client = try WiroClient(
    proxyURL: URL(string: "https://api.myapp.com/wiro/v1")!,
    headers: ["Authorization": "Bearer \(userToken)"]
)
```

REST calls go through `proxyURL` with your headers. Task WebSockets still
connect directly to ``WiroClient/socketURL`` because they authenticate with
per-task tokens, not API keys.

## Retries and logging

Transient HTTP failures retry according to ``WiroRetryPolicy``. Billable
paths (`/Run/...`, `/File/Upload`) never retry. Attach a ``WiroLogger`` to
observe request lifecycle events — log messages never include credentials,
signatures, headers, or request bodies.

## Errors

All failures surface as ``WiroError``:

| Case | When |
|---|---|
| `apiResult` | 2xx with `"result": false` |
| `authentication` | HTTP 401 / 403 |
| `validation` | HTTP 400 / 422 or local precondition |
| `rateLimited` | HTTP 429 |
| `unknownAPI` | Other unexpected API shapes |
| `schemaValidation` | Local schema validation |
| `network` | Transport failure |
| `webSocket` | Socket failure |
| `timedOut` | Deadline exceeded |
| `cancelled` | Swift `Task` cancellation |

## Topics

### Client

- ``WiroClient``
- ``WiroAuthType``
- ``WiroRetryPolicy``
- ``WiroHTTPTransport``

### Typed requests

- ``Wiro``
- ``WiroModelRequest``
- ``WiroDynamicRequest``
- ``WiroFlux2ProRequest``
- ``WiroGptImage2Request``
- ``WiroNanoBananaProRequest``
- ``WiroSeedreamV4Request``
- ``WiroGrokImagineImageRequest``
- ``WiroRunwayGen45Request``
- ``WiroSeedance20Request``
- ``WiroKlingV3Request``
- ``WiroVeo31Request``
- ``WiroSora2ProRequest``
- ``WiroHailuo23FastRequest``
- ``WiroGrokImagineVideoRequest``
- ``WiroLyria3Request``

### Tasks and tracking

- ``WiroTask``
- ``WiroTaskStatus``
- ``WiroTaskResult``
- ``WiroTaskUpdate``
- ``WiroTaskTrackingMode``
- ``WiroSocketEvent``

### Files and JSON

- ``WiroFileInput``
- ``WiroJSONValue``
- ``WiroUploadResult``

### Errors and logging

- ``WiroError``
- ``WiroLogEvent``
- ``WiroLogger``
