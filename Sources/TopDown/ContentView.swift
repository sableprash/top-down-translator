import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var sourceFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            header
            editor(
                title: "Original",
                text: $model.source,
                placeholder: "Paste the message you’re about to send…",
                minHeight: 150,
                focused: $sourceFocused
            )

            HStack(spacing: 8) {
                Button("Paste", systemImage: "doc.on.clipboard") { model.paste() }
                Button("Clear", systemImage: "xmark") { model.clear() }
                    .disabled(model.source.isEmpty && model.result.isEmpty)
                Spacer()
                Text("\(model.characterCount) characters")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(model.characterCount > 150 ? .secondary : .tertiary)
                Button {
                    model.translate()
                } label: {
                    if model.isTranslating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                        Text("Translating…")
                    } else {
                        Label("Make it top-down", systemImage: "arrow.down.to.line.compact")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!model.canTranslate)
            }

            Divider()

            resultHeader
            editor(
                title: "",
                text: $model.result,
                placeholder: "Your verified rewrite will appear here.",
                minHeight: 170,
                focused: nil
            )

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Label("Messages aren’t saved", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    model.copyResult()
                } label: {
                    Label(model.copied ? "Copied" : "Copy for Slack", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.result.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 560, height: 650)
        .onAppear { sourceFocused = true }
        .onChange(of: model.source) { _, _ in model.sourceDidChange() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text("TopDown")
                    .font(.headline)
                Text("Lead with the point. Keep the meaning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink {
                Image(systemName: model.apiKeyConfigured ? "gearshape" : "key.fill")
            }
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit TopDown")
        }
    }

    private var resultHeader: some View {
        HStack {
            Text("Ready for Slack")
                .font(.subheadline.weight(.semibold))
            Spacer()
            switch model.phase {
            case .idle:
                EmptyView()
            case .translating:
                statusPill("Checking meaning", color: .blue, icon: "ellipsis")
            case .verified(let score):
                statusPill("Verified \(score)", color: .green, icon: "checkmark.shield.fill")
            case .reverted:
                statusPill("Original kept", color: .orange, icon: "arrow.uturn.backward.circle.fill")
            }
        }
    }

    private func statusPill(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func editor(
        title: String,
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat,
        focused: FocusState<Bool>.Binding?
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.separator.opacity(0.7), lineWidth: 1)
                    }
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 11)
                        .allowsHitTesting(false)
                }
                if let focused {
                    TextEditor(text: text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(5)
                        .focused(focused)
                } else {
                    TextEditor(text: text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(5)
                }
            }
            .frame(minHeight: minHeight)
        }
    }
}
