import SwiftUI

struct GenerateImageView: View {
    @Bindable var credentials: CredentialsStore
    @State private var model: GenerateImageViewModel
    @State private var showSettings = false

    init(credentials: CredentialsStore) {
        self.credentials = credentials
        _model = State(
            initialValue: GenerateImageViewModel(credentials: credentials)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    promptSection
                    dimensionSection
                    actionSection
                    statusSection
                    resultsSection
                }
                .padding()
            }
            .navigationTitle("Generate Image")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings") {
                        showSettings = true
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(credentials: credentials)
            }
            .confirmationDialog(
                "Stop generation",
                isPresented: $model.showCancelAPIOptions,
                titleVisibility: .visible
            ) {
                Button("Cancel local Task", role: .destructive) {
                    model.cancelLocal()
                }
                if model.taskToken != nil {
                    Button("Cancel via API") {
                        model.cancelRemote()
                    }
                    Button("Kill via API", role: .destructive) {
                        model.killRemote()
                    }
                }
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(
                    "Local cancel stops the stream immediately. API cancel/kill asks Wiro to stop the remote task when a token is available."
                )
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(.headline)
            TextField("Describe an image", text: $model.prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }

    private var dimensionSection: some View {
        HStack(spacing: 16) {
            Picker("Width", selection: $model.width) {
                ForEach(GenerateImageViewModel.dimensionChoices, id: \.self) {
                    Text("\($0)").tag($0)
                }
            }
            .pickerStyle(.menu)

            Picker("Height", selection: $model.height) {
                ForEach(GenerateImageViewModel.dimensionChoices, id: \.self) {
                    Text("\($0)").tag($0)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button {
                model.generate()
            } label: {
                Text(model.isRunning ? "Generating…" : "Generate")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunning)

            if model.isRunning {
                Button("Cancel", role: .destructive) {
                    model.showCancelAPIOptions = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch model.state {
        case .idle:
            Text("Ready. Enter a prompt and tap Generate.")
                .foregroundStyle(.secondary)
        case .running(let status):
            HStack(spacing: 10) {
                ProgressView()
                Text("Status: \(status)")
                    .font(.body.monospaced())
            }
        case .succeeded:
            Label("Done", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if case .succeeded(let outputs) = model.state {
            VStack(alignment: .leading, spacing: 12) {
                Text("Outputs")
                    .font(.headline)
                ForEach(outputs, id: \.absoluteString) { url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Text("Could not load \(url.absoluteString)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}
