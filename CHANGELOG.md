# Changelog

All notable changes to WiroKit are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## 0.1.0 - 2026-08-17

Initial public Swift 6 SDK for iOS 17+.

- Typed request factories for popular image, video, and audio models,
  plus `Wiro.model(_:parameters:)` for any other slug
- Model search, explore, and schema validation
- `run` / `subscribe` / `subscribeStream` task lifecycle APIs
- Automatic file uploads for device-local `WiroFileInput` values
- Polling and WebSocket task tracking, with polling fallback
- Task cancel and kill against the live Wiro API
- Retry with exponential backoff, timeouts, and structured logging
- API key, HMAC signature, and proxy authentication
- Zero third-party dependencies (Foundation, URLSession, CryptoKit)
