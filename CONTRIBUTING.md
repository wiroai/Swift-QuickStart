# Contributing

Thank you for improving the Wiro Swift SDK.

## Requirements

- Xcode 16 or later
- Swift 6
- Git

## Setup

```bash
git clone https://github.com/wiroai/Swift-QuickStart.git
cd Swift-QuickStart
open Package.swift
```

The example app lives at `Example/WiroExample.xcodeproj` and depends on
the local package.

## Development checks

Run these checks before opening a pull request. The package is iOS-only,
so tests run on the iOS Simulator:

```bash
xcodebuild test \
  -scheme WiroKit \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES

xcodebuild docbuild \
  -scheme WiroKit \
  -destination 'generic/platform=iOS'

xcodebuild build \
  -project Example/WiroExample.xcodeproj \
  -scheme WiroExample \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

CI enforces 90% line coverage on the `WiroKit` target.

## Public API changes

- Keep the SDK free of third-party dependencies.
- Document every public member with DocC comments.
- Add tests for success, failure, cancellation, and wire serialization.
- Preserve backward compatibility unless a major version is planned.

## Pull requests

- Keep changes focused.
- Add a changelog entry for developer-visible behavior.
- Never commit API keys, API secrets, private prompts, or generated media.
- Ensure CI passes on `main`.

## Releases

This project follows [Semantic Versioning](https://semver.org/):

- Patch: backward-compatible fixes
- Minor: backward-compatible functionality
- Major: breaking public API changes

Maintainers update `CHANGELOG.md` and `WiroKitInfo.version`, then push a
`vX.Y.Z` tag. Swift Package Manager resolves that tag from this
repository.

The release tag must match the package version, prefixed with `v`. For
example, `WiroKitInfo.version` `0.1.0` is released with tag `v0.1.0`.
