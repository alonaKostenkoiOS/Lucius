import SwiftUI
import SwiftData
import PhotosUI

/// Import many words at once from a book passage — paste it or snap a photo
/// of the page, pick which words to learn, and Lucius translates and adds
/// them all as scheduled cards.
struct ImportWordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportWordsViewModel()
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    sourceSection
                    if !viewModel.candidates.isEmpty {
                        candidatesSection
                    }
                }
                .padding(Spacing.xl)
            }
            .background(AppBackgroundGradient())
            .navigationTitle("import.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { importBar }
            .onAppear { viewModel.loadExisting(context: modelContext) }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await viewModel.recognizeText(in: data)
                    }
                }
            }
        }
        .tint(.lavender)
        .preferredColorScheme(.light)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("import.passage")
                .font(.cardLabel)
                .foregroundStyle(Color.lavender)
                .textCase(.uppercase)

            ZStack(alignment: .topLeading) {
                if viewModel.sourceText.isEmpty {
                    Text("import.passage_hint")
                        .foregroundStyle(.secondary)
                        .padding(Spacing.md)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $viewModel.sourceText)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

            HStack(spacing: Spacing.md) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(viewModel.isRecognizing ? "Scanning…" : "Scan a page", systemImage: "text.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lavender)
                }
                .disabled(viewModel.isRecognizing)

                if viewModel.isRecognizing {
                    ProgressView().tint(.lavender)
                }
            }

            TextField("Book title (optional)", text: $viewModel.bookTitle)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("import.words_to_learn")
                    .font(.cardLabel)
                    .foregroundStyle(Color.lavender)
                    .textCase(.uppercase)
                Spacer()
                Button(viewModel.selected.count == viewModel.candidates.count ? "Clear" : "Select all") {
                    viewModel.selected.count == viewModel.candidates.count
                        ? viewModel.clearSelection()
                        : viewModel.selectAll()
                }
                .font(.caption.weight(.semibold))
            }

            FlowLayout {
                ForEach(viewModel.candidates, id: \.self) { word in
                    chip(word)
                }
            }

            Text("import.selection_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ word: String) -> some View {
        let isOn = viewModel.selected.contains(word)
        return Button {
            viewModel.toggle(word)
        } label: {
            Text(word)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? .white : Color.deepPurple)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isOn ? Color.lavender : Color.lavenderSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word)
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    @ViewBuilder
    private var importBar: some View {
        if !viewModel.candidates.isEmpty {
            VStack(spacing: Spacing.sm) {
                if viewModel.isImporting {
                    ProgressView(value: viewModel.importProgress) {
                        Text(String(format: String(localized: "import.adding_progress"), viewModel.importedCount, viewModel.selected.count))
                            .font(.caption)
                    }
                    .tint(.lavender)
                }

                PrimaryButton(
                    title: viewModel.selected.isEmpty ? "Select words to add" : "Add \(viewModel.selected.count) words",
                    systemImage: "plus.circle.fill",
                    isEnabled: viewModel.canImport
                ) {
                    Task {
                        await viewModel.importSelected(context: modelContext)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.sm)
        }
    }
}

#Preview {
    ImportWordsView()
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
