import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var apiKey = ""
    @State private var status: String?

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("Paste API key", text: $apiKey)
                    .textContentType(.password)

                HStack {
                    if model.apiKeyConfigured {
                        Label("Stored in macOS Keychain", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("No API key configured", systemImage: "key")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove", role: .destructive) {
                        do {
                            try KeychainStore.deleteAPIKey()
                            apiKey = ""
                            status = "Removed"
                            model.refreshAPIKeyState()
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                    .disabled(!model.apiKeyConfigured)
                    Button("Save") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        do {
                            try KeychainStore.saveAPIKey(trimmed)
                            apiKey = ""
                            status = "Saved securely"
                            model.refreshAPIKeyState()
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let status {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Text("Message text stays in memory and is sent only to OpenAI for translation and verification. The app does not save message history or API responses.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 260)
    }
}
