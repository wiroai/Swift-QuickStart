# WiroExample

SwiftUI demo app for [WiroKit](../README.md).

## Open

```bash
open Example/WiroExample.xcodeproj
```

The project depends on the local `WiroKit` package at the repository root.

## Configure

1. Run on an iOS 17+ Simulator.
2. Open **Settings** and paste a Wiro API key (optional secret), or enable
   proxy mode with your backend URL.
3. Enter a prompt and tap **Generate**.

> Do not ship long-lived API secrets in App Store builds. Prefer proxy mode.

## Cancel

While a run is in progress, **Cancel** stops the local Swift `Task`
immediately. When the remote task identifiers are available, you can also
cancel a queued task or kill a running task through the Wiro API.
