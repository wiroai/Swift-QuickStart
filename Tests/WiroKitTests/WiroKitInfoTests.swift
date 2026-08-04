import Testing
import WiroKit

@Suite("WiroKitInfo")
struct WiroKitInfoTests {
    @Test("version matches the current package version")
    func versionMatchesCurrentPackageVersion() {
        #expect(WiroKitInfo.version == "0.1.0")
    }
}
