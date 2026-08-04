import Foundation
@testable import WiroKit

final class ControllableClock: @unchecked Sendable {
    private var now: Date
    private(set) var sleepDurations: [Duration] = []

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    var clock: WiroClock {
        { [self] in self.now }
    }

    var sleeper: WiroSleeper {
        { [self] duration in
            try Task.checkCancellation()
            self.sleepDurations.append(duration)
            self.now = self.now.addingTimeInterval(durationToSeconds(duration))
        }
    }
}

final class UpdateBox: @unchecked Sendable {
    private var _updates: [WiroTaskUpdate] = []

    var updates: [WiroTaskUpdate] { _updates }

    var statuses: [WiroTaskStatus] {
        _updates.compactMap(\.status)
    }

    func append(_ update: WiroTaskUpdate) {
        _updates.append(update)
    }
}

func durationToSeconds(_ duration: Duration) -> TimeInterval {
    let components = duration.components
    return TimeInterval(components.seconds)
        + TimeInterval(components.attoseconds)
        / 1_000_000_000_000_000_000
}

func parkingSleeper(_ duration: Duration) async throws {
    _ = duration
    try await Task.sleep(for: .seconds(3600))
}
