import SwiftUI
import SwiftData

/// Full word card: translation, example, visual scene, book and review actions.
struct WordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WordDetailViewModel

    private let generationManager = SceneImageGenerationManager.shared

    init(word: VocabularyWord) {
        _viewModel = State(initialValue: WordDetailViewModel(word: word))
    }

    private var word: VocabularyWord { viewModel.word }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let example = word.example {
                    infoCard(title: "Example from book", systemImage: "text.quote") {
                        Text("\u{201C}\(example)\u{201D}")
                            .font(.body.italic())
                    }
                }

                if let visualAssociation = word.visualAssociation {
                    VisualSceneCard(text: visualAssociation)
                }

                sceneImageSection

                if word.bookTitle != nil || word.chapter != nil {
                    bookCard
                }

                reviewInfoCard

                ReviewAnswerButtons { answer in
                    viewModel.answer(answer, context: modelContext)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color.appBackground)
        .overlay { CelebrationView(isActive: $viewModel.celebrate) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    viewModel.delete(context: modelContext)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .tint(.lavender)
        .alert(
            "Couldn't generate the image",
            isPresented: Binding(
                get: {
                    AppFeatures.imageGenerationEnabled && generationManager.failureMessage(for: word) != nil
                },
                set: { isPresented in
                    if !isPresented {
                        generationManager.clearFailure(for: word)
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(generationManager.failureMessage(for: word) ?? "")
        }
    }

    /// AI scene image: the stored image with regenerate/remove actions,
    /// or a generate button (Image Playground on supported devices,
    /// free network generation everywhere else).
    @ViewBuilder
    private var sceneImageSection: some View {
        if let sceneImageData = word.sceneImageData {
            VStack(spacing: 8) {
                SceneImageView(imageData: sceneImageData)

                HStack(spacing: 12) {
                    if AppFeatures.imageGenerationEnabled {
                        generationButton(title: "Again")
                    }

                    Button {
                        Task { await viewModel.saveSceneImageToPhotos() }
                    } label: {
                        Label(
                            viewModel.isSavedToPhotos ? "Saved" : "Save",
                            systemImage: viewModel.isSavedToPhotos ? "checkmark" : "square.and.arrow.down"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lavender)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.lavenderSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        viewModel.removeSceneImage(context: modelContext)
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        } else if AppFeatures.imageGenerationEnabled {
            generationButton(title: "Generate scene image")
        }
    }

    private func generationButton(title: String) -> some View {
        SceneImageGenerationButton(
            word: word,
            title: title,
            isGenerating: generationManager.isGenerating(word),
            etaSeconds: generationManager.eta(for: word),
            onPlaygroundImage: { url in
                viewModel.saveSceneImage(from: url, context: modelContext)
            },
            onNetworkGenerate: {
                generationManager.generateImage(for: word)
            }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(word.word)
                    .font(.largeWord)

                SpeakButton(text: word.word)

                Spacer()

                StatusBadge(status: word.reviewStatus)
            }

            Text(word.translation)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var bookCard: some View {
        infoCard(title: "Source", systemImage: "book") {
            VStack(alignment: .leading, spacing: 4) {
                if let bookTitle = word.bookTitle {
                    Text(bookTitle)
                        .font(.body.weight(.medium))
                }
                if let chapter = word.chapter {
                    Text(chapter)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var reviewInfoCard: some View {
        infoCard(title: "Next review", systemImage: "clock") {
            if let nextReviewDate = word.nextReviewDate {
                Text(nextReviewDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.body.weight(.medium))
            } else {
                Text("Not scheduled")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoCard(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        WordDetailView(word: VocabularyWord(
            word: "serendipity",
            translation: "счастливая случайность",
            example: "It was pure serendipity that she found the letter.",
            visualAssociation: "Imagine a dark rainy room with one candle on the table.",
            bookTitle: "The Midnight Library",
            chapter: "Chapter 7",
            nextReviewDate: .now.addingTimeInterval(6 * 60 * 60)
        ))
    }
    .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
