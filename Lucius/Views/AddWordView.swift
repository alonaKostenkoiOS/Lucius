import SwiftUI
import SwiftData

/// Form for adding a new word with its translation, context and visual scene.
struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddWordViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    HStack {
                        TextField("Word", text: $viewModel.word)
                            .textInputAutocapitalization(.never)

                        if !viewModel.word.isEmpty {
                            SpeakButton(text: viewModel.word)
                        }
                    }

                    TextField("Translation", text: $viewModel.translation)

                    AutoTranslateButton(sourceText: viewModel.word) { translated in
                        viewModel.translation = translated
                    }
                }

                Section {
                    TextField("Example from book", text: $viewModel.example, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Context")
                }

                Section {
                    TextField(
                        "Imagine a dark rainy room with one candle…",
                        text: $viewModel.visualAssociation,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                } header: {
                    Text("Visual scene")
                } footer: {
                    Text("A vivid mental image makes the word much easier to recall.")
                }

                Section("Book") {
                    TextField("Book title", text: $viewModel.bookTitle)
                    TextField("Chapter", text: $viewModel.chapter)
                }

                Section {
                    Picker("Difficulty", selection: $viewModel.difficulty) {
                        ForEach(WordDifficulty.allCases) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Difficulty")
                } footer: {
                    Text("Harder words come back for review sooner.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("New word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Save word", isEnabled: viewModel.canSave) {
                    saveWord()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .tint(.lavender)
        // Sheets are separate presentations and don't inherit the
        // root's light appearance, so set it here as well.
        .preferredColorScheme(.light)
    }

    private func saveWord() {
        guard viewModel.save(context: modelContext) != nil else { return }
        dismiss()
    }
}

#Preview {
    AddWordView()
        .modelContainer(for: VocabularyWord.self, inMemory: true)
}
