import SwiftUI

struct SettingsView: View {
    @Bindable var credentials: CredentialsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Do not ship long-lived Wiro API keys or secrets in App Store builds. Prefer a backend proxy that attaches credentials server-side."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Security warning")
                }

                Section("Mode") {
                    Toggle("Use proxy URL", isOn: $credentials.useProxy)
                }

                if credentials.useProxy {
                    Section("Proxy") {
                        TextField(
                            "https://api.myapp.com/wiro/v1",
                            text: $credentials.proxyURLString
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    }
                } else {
                    Section("Credentials") {
                        SecureField("API key", text: $credentials.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField(
                            "API secret (optional)",
                            text: $credentials.apiSecret
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
