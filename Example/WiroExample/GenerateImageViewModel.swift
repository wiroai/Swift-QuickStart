import Foundation
import WiroKit

/// Drives the Flux 2 Pro generate-image demo.
@Observable
@MainActor
final class GenerateImageViewModel {
    var prompt: String = "A cinematic mountain lake at sunrise"
    var width: Int = 1024
    var height: Int = 1024
    var state: GenerationState = .idle
    var taskID: WiroTaskID?
    var taskToken: WiroTaskToken?
    var showCancelAPIOptions = false

    /// Valid Flux 2 Pro dimensions (multiples of 16, 64…2048).
    static let dimensionChoices: [Int] = [
        512, 768, 1024, 1280, 1536, 1792, 2048,
    ]

    private var generationTask: Task<Void, Never>?
    private let credentials: CredentialsStore

    init(credentials: CredentialsStore) {
        self.credentials = credentials
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    func generate() {
        guard !isRunning else { return }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .failed(message: "Enter a prompt before generating.")
            return
        }
        guard credentials.hasCredentials else {
            state = .failed(
                message: "Add an API key or proxy URL in Settings."
            )
            return
        }

        generationTask?.cancel()
        taskID = nil
        taskToken = nil
        state = .running(status: "Submitting…")

        generationTask = Task { [weak self] in
            await self?.runGeneration(prompt: trimmed)
        }
    }

    /// Cancels the local Swift Task (cooperative cancellation).
    func cancelLocal() {
        generationTask?.cancel()
        generationTask = nil
        if isRunning {
            state = .failed(message: WiroError.cancelled.friendlyMessage)
        }
    }

    /// Cancels a queued task via the Wiro API.
    func cancelRemote() {
        guard let id = taskID else { return }
        Task {
            do {
                let client = try makeClient()
                _ = try await client.cancelTask(id)
                cancelLocal()
            } catch {
                state = .failed(message: error.friendlyMessage)
            }
        }
    }

    /// Kills a running task via the Wiro API.
    func killRemote() {
        guard taskToken != nil || taskID != nil else { return }
        Task {
            do {
                let client = try makeClient()
                if let token = taskToken {
                    _ = try await client.killTask(token)
                } else if let id = taskID {
                    _ = try await client.killTask(id)
                }
                cancelLocal()
            } catch {
                state = .failed(message: error.friendlyMessage)
            }
        }
    }

    private func runGeneration(prompt: String) async {
        do {
            let client = try makeClient()
            let request = try Wiro.flux2Pro(
                prompt: prompt,
                width: width,
                height: height,
                outputFormat: .png
            )

            let stream = try await client.subscribeStream(request)
            var lastStatus = "Queued"
            var outputURLs: [URL] = []

            for try await update in stream {
                try Task.checkCancellation()

                if let status = update.status {
                    lastStatus = status.apiValue
                    state = .running(status: lastStatus)
                }

                switch update {
                case .snapshot(let task):
                    if let id = task.id {
                        taskID = id
                    }
                    if let token = task.taskToken {
                        taskToken = token
                    }
                    let urls = task.outputs.compactMap(\.url)
                    if !urls.isEmpty {
                        outputURLs = urls
                    }
                    if task.status.isTerminal {
                        if task.isSuccessful, !outputURLs.isEmpty {
                            state = .succeeded(outputs: outputURLs)
                        } else if task.isSuccessful {
                            state = .failed(
                                message: "Task completed without image URLs."
                            )
                        } else {
                            state = .failed(
                                message: task.debugOutput
                                    ?? "Generation failed (\(task.status.apiValue))."
                            )
                        }
                        return
                    }
                case .event(let message):
                    if let id = message.id {
                        taskID = id
                    }
                    if let token = message.taskToken {
                        taskToken = token
                    }
                    let urls = message.outputs.compactMap(\.url)
                    if !urls.isEmpty {
                        outputURLs = urls
                    }
                case .binary:
                    break
                }
            }

            try Task.checkCancellation()
            if !outputURLs.isEmpty {
                state = .succeeded(outputs: outputURLs)
            } else {
                state = .failed(
                    message: "Stream ended without a terminal result."
                )
            }
        } catch is CancellationError {
            state = .failed(message: WiroError.cancelled.friendlyMessage)
        } catch {
            state = .failed(message: error.friendlyMessage)
        }
    }

    private func makeClient() throws -> WiroClient {
        if credentials.useProxy {
            let trimmed = credentials.proxyURLString
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed) else {
                throw WiroError.validation(
                    message: "Proxy URL is invalid.",
                    statusCode: 0,
                    responseBody: nil
                )
            }
            return try WiroClient(proxyURL: url)
        }

        let key = credentials.apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = credentials.apiSecret
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try WiroClient(
            apiKey: key,
            apiSecret: secret.isEmpty ? nil : secret
        )
    }
}
