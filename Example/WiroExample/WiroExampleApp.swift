import SwiftUI

@main
struct WiroExampleApp: App {
    @State private var credentials = CredentialsStore()

    var body: some Scene {
        WindowGroup {
            GenerateImageView(credentials: credentials)
        }
    }
}
