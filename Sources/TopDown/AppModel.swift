import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case translating
        case verified(Int)
        case reverted(String)
    }

    @Published var source = ""
    @Published var result = ""
    @Published var phase: Phase = .idle
    @Published var errorMessage: String?
    @Published var copied = false
    @Published private(set) var apiKeyConfigured = KeychainStore.hasAPIKey

    private var translatedSource = ""
    private var translationTask: Task<Void, Never>?

    var isTranslating: Bool { phase == .translating }
    var canTranslate: Bool { !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating }
    var characterCount: Int { source.count }

    func sourceDidChange() {
        copied = false
        errorMessage = nil
        guard source != translatedSource, !isTranslating else { return }
        result = ""
        phase = .idle
    }

    func paste() {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        source = value
        sourceDidChange()
    }

    func clear() {
        translationTask?.cancel()
        source = ""
        result = ""
        translatedSource = ""
        errorMessage = nil
        copied = false
        phase = .idle
    }

    func translate() {
        guard canTranslate else { return }
        guard let apiKey = try? KeychainStore.loadAPIKey(), !apiKey.isEmpty else {
            errorMessage = "Add an OpenAI API key in Settings first."
            apiKeyConfigured = false
            return
        }

        let input = source
        errorMessage = nil
        copied = false
        phase = .translating
        translationTask?.cancel()
        translationTask = Task {
            do {
                let outcome = try await TranslatorService().translate(input, apiKey: apiKey)
                try Task.checkCancellation()
                guard source == input else { return }
                translatedSource = input
                result = outcome.text
                if outcome.reverted {
                    phase = .reverted(outcome.reason)
                } else {
                    phase = .verified(outcome.faithfulnessScore)
                }
            } catch is CancellationError {
                phase = .idle
            } catch {
                guard source == input else { return }
                phase = .idle
                errorMessage = error.localizedDescription
            }
        }
    }

    func copyResult() {
        guard !result.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
        copied = true
    }

    func refreshAPIKeyState() {
        apiKeyConfigured = KeychainStore.hasAPIKey
        if apiKeyConfigured, errorMessage == "Add an OpenAI API key in Settings first." {
            errorMessage = nil
        }
    }
}
