import SwiftUI
import SwiftData

/// Form for adding a new word with its translation, context and visual scene.
struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddWordViewModel()
    @State private var scannerTarget: ScannerTarget?

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "word.field.word")) {
                    HStack {
                        TextField(String(localized: "word.field.word"), text: $viewModel.word)
                            .textInputAutocapitalization(.never)

                        if !viewModel.word.isEmpty {
                            SpeakButton(text: viewModel.word, languageCode: viewModel.languageCode)
                        }
                    }

                    Button {
                        scannerTarget = .word
                    } label: {
                        Label("word.scan_word", systemImage: "text.viewfinder")
                    }
                    .accessibilityHint(String(localized: "accessibility.scan_word_hint"))

                    TextField(String(localized: "word.field.translation"), text: $viewModel.translation)

                    AutoTranslateButton(sourceText: viewModel.word) { translated in
                        viewModel.translation = translated
                    }
                }

                Section {
                    TextField(String(localized: "word.field.context"), text: $viewModel.example, axis: .vertical)
                        .lineLimit(2...4)

                    Button {
                        scannerTarget = .context
                    } label: {
                        Label("word.scan_context", systemImage: "camera.viewfinder")
                    }
                    .accessibilityHint(String(localized: "accessibility.scan_context_hint"))
                    .disabled(viewModel.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("word.field.context")
                }

                Section {
                    TextField(
                        String(localized: "word.visual_scene_placeholder"),
                        text: $viewModel.visualAssociation,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                } header: {
                    Text("word.field.visual_scene")
                } footer: {
                    Text("word.visual_scene_hint")
                }

                Section(String(localized: "word.field.book")) {
                    TextField(String(localized: "word.book_placeholder"), text: $viewModel.bookTitle)
                    TextField(String(localized: "word.field.chapter"), text: $viewModel.chapter)
                }

                Section {
                    Picker(String(localized: "word.field.difficulty"), selection: $viewModel.difficulty) {
                        ForEach(WordDifficulty.allCases) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("word.field.difficulty")
                } footer: {
                    Text("word.difficulty_hint")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("word.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: String(localized: "common.save"), isEnabled: viewModel.canSave) {
                    saveWord()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .tint(.lavender)
        .sheet(item: $scannerTarget) { target in
            LiveTextScannerView(
                selectionMode: target.selectionMode,
                searchWord: target == .context ? viewModel.word : nil
            ) { text in
                switch target {
                case .word:
                    viewModel.applyScannedText(text)
                case .context:
                    viewModel.applyScannedContext(text)
                }
                Haptics.success()
            }
            .preferredColorScheme(.light)
        }
        // Sheets are separate presentations and don't inherit the
        // root's light appearance, so set it here as well.
        .preferredColorScheme(.light)
    }

    private func saveWord() {
        guard viewModel.save(context: modelContext) != nil else { return }
        dismiss()
    }

    private enum ScannerTarget: String, Identifiable {
        case word
        case context

        var id: String { rawValue }

        var selectionMode: LiveTextScannerSelectionMode {
            switch self {
            case .word: .word
            case .context: .context
            }
        }
    }
}

#Preview {
    AddWordView()
        .modelContainer(for: VocabularyWord.self, inMemory: true)
}
