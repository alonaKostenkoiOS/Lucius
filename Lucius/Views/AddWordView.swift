import SwiftUI
import SwiftData
import UIKit

/// A guided collection flow that progressively reveals one decision at a time.
struct AddWordView: View {
    private enum Step: Int, CaseIterable { case word, context, visual, source, finish }
    private enum Field: Hashable { case word, translation, context, visual, book, chapter }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = AddWordViewModel()
    @State private var step: Step = .word
    @State private var scannerTarget: ScannerTarget?
    @State private var contextInputVisible = false
    @State private var visualInputVisible = false
    @State private var collected = false
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if collected { successCard } else { flow }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88), value: step)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackgroundGradient())
            .navigationTitle("word.add.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .tint(.lavender)
        .onAppear { focusedField = .word }
        .onChange(of: viewModel.word) { oldValue, newValue in
            guard oldValue != newValue else { return }
            viewModel.wordDidChange()
            if step != .word { withAnimation { step = .word } }
        }
        .onChange(of: viewModel.translation) { _, newValue in
            guard step == .word,
                  !viewModel.isTranslating,
                  !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            focusedField = nil
            withAnimation { step = .context }
        }
        .task(id: viewModel.word) {
            let candidate = viewModel.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            if await viewModel.translateAutomatically(expectedWord: candidate) {
                focusedField = nil
                withAnimation { step = .context }
            }
        }
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
                    withAnimation { step = .visual }
                }
                Haptics.success()
            }
        }
    }

    @ViewBuilder private var flow: some View {
        stepCard(.word, icon: "textformat", title: "word.flow.discover") { wordStep } summary: {
            summary(viewModel.word, detail: viewModel.translation)
        }
        if step.rawValue >= Step.context.rawValue {
            stepCard(.context, icon: "quote.bubble", title: "word.flow.context") { contextStep } summary: {
                summary(viewModel.example.isEmpty ? String(localized: "word.flow.skipped") : viewModel.example)
            }
        }
        if step.rawValue >= Step.visual.rawValue {
            stepCard(.visual, icon: "wand.and.stars", title: "word.flow.visual") { visualStep } summary: {
                summary(visualSummary)
            }
        }
        if step.rawValue >= Step.source.rawValue {
            stepCard(.source, icon: "books.vertical", title: "word.flow.source") { sourceStep } summary: {
                summary(sourceSummary)
            }
        }
        if step == .finish { finishStep }
    }

    private var wordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("word.flow.discover")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "",
                text: $viewModel.word,
                prompt: Text("word.field.word")
                    .font(.body)
                    .foregroundStyle(.secondary)
            )
                .font(.title2.weight(.semibold))
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($focusedField, equals: .word)
                .frame(minHeight: 30)
                .flowField(isElevated: isWordFieldElevated)
                .accessibilityLabel(String(localized: "word.field.word"))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    pasteButton
                    scanWordButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    pasteButton
                    scanWordButton
                }
            }
            .opacity(viewModel.word.isEmpty ? 1 : 0.68)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: viewModel.word.isEmpty)

            if viewModel.isTranslating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("word.translating")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if !viewModel.word.isEmpty {
                TextField(String(localized: "word.field.translation"), text: $viewModel.translation)
                    .font(.body.weight(.medium))
                    .focused($focusedField, equals: .translation)
                    .flowField()
            }
        }
    }

    private var contextStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            question("word.flow.context")
            if contextInputVisible {
                TextField(String(localized: "word.field.context"), text: $viewModel.example, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .context)
                    .flowField()
                actionButton("word.flow.continue", icon: "arrow.right") { advance(to: .visual) }
                    .disabled(viewModel.example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                choice("word.flow.add_sentence", icon: "text.quote") {
                    contextInputVisible = true; focusedField = .context
                }
                choice("word.scan_context", icon: "camera.viewfinder") { scannerTarget = .context }
                choice("word.flow.skip", icon: "arrow.right") { advance(to: .visual) }
            }
        }
    }

    private var visualStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            question("word.flow.visual")
            if visualInputVisible {
                TextField(String(localized: "word.visual_scene_placeholder"), text: $viewModel.visualAssociation, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .visual)
                    .flowField()
                actionButton("word.flow.continue", icon: "arrow.right") { advance(to: .source) }
            } else {
                if AppFeatures.imageGenerationEnabled {
                    choice("word.flow.generate_scene", icon: "photo.badge.plus") {
                        viewModel.shouldGenerateScene = true; advance(to: .source)
                    }
                }
                choice("word.flow.write_scene", icon: "pencil") {
                    visualInputVisible = true; focusedField = .visual
                }
                choice("word.flow.skip", icon: "arrow.right") { advance(to: .source) }
            }
        }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            question("word.flow.source")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 10) {
                ForEach(AddWordViewModel.SourceKind.allCases) { kind in
                    Button {
                        viewModel.sourceKind = kind
                        if kind != .book {
                            viewModel.bookTitle = kind.localizedTitle
                            advance(to: .finish)
                        }
                    } label: {
                        Text(verbatim: kind.localizedTitle)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(viewModel.sourceKind == kind ? Color.lavender.opacity(0.9) : Color.lavenderSoft.opacity(0.6))
                            .foregroundStyle(viewModel.sourceKind == kind ? .white : Color.deepPurple)
                            .clipShape(Capsule())
                    }
                }
            }
            if viewModel.sourceKind == .book {
                TextField(String(localized: "word.book_placeholder"), text: $viewModel.bookTitle)
                    .focused($focusedField, equals: .book).flowField()
                TextField(String(localized: "word.flow.chapter_optional"), text: $viewModel.chapter)
                    .focused($focusedField, equals: .chapter).flowField()
                actionButton("word.flow.continue", icon: "arrow.right") { advance(to: .finish) }
                    .disabled(viewModel.bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Button("word.flow.skip") { advance(to: .finish) }
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private var finishStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("word.flow.review_pace").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Picker("word.field.difficulty", selection: $viewModel.difficulty) {
                    ForEach(WordDifficulty.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .flowCard()

            PrimaryButton(title: String(localized: "word.flow.collect"), isEnabled: viewModel.canSave) {
                collectWord()
            }
            .accessibilityHint(String(localized: "word.flow.collect_hint"))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var successCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54)).foregroundStyle(Color.lavender)
            Text("word.flow.collected")
            .font(.title2.weight(.semibold))
            Text(viewModel.word).font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(32).flowCard()
        .scaleEffect(collected ? 0.94 : 1)
        .transition(.scale(scale: 1.08).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    private func stepCard<Content: View, Summary: View>(
        _ cardStep: Step,
        icon: String,
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content,
        @ViewBuilder summary: () -> Summary
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if step == cardStep {
                content()
            } else {
                Button { withAnimation { step = cardStep } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lavender)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            summary()
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .flowCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func summary(_ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.body.weight(.semibold)).lineLimit(1)
            if let detail, !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1) }
        }
    }

    private func question(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func choice(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.lavender.opacity(0.8))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.lavenderSoft.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func actionButton(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .tint(Color.lavender.opacity(0.78))
    }

    private var pasteButton: some View {
        actionButton("word.flow.paste", icon: "doc.on.clipboard") {
            if let value = UIPasteboard.general.string { viewModel.word = value }
        }
    }

    private var scanWordButton: some View {
        actionButton("word.scan_word", icon: "camera.viewfinder") { scannerTarget = .word }
    }

    private var isWordFieldElevated: Bool {
        focusedField == .word && !viewModel.word.isEmpty
    }

    private var visualSummary: String {
        if viewModel.shouldGenerateScene { return String(localized: "word.flow.scene_queued") }
        return viewModel.visualAssociation.isEmpty ? String(localized: "word.flow.skipped") : viewModel.visualAssociation
    }

    private var sourceSummary: String {
        guard let source = viewModel.sourceKind else { return String(localized: "word.flow.skipped") }
        if source == .book, !viewModel.bookTitle.isEmpty { return viewModel.bookTitle }
        return source.localizedTitle
    }

    private func advance(to next: Step) {
        focusedField = nil
        withAnimation { step = next }
    }

    private func collectWord() {
        guard let saved = viewModel.save(context: modelContext) else { return }
        if AppFeatures.imageGenerationEnabled && viewModel.shouldGenerateScene {
            SceneImageGenerationManager.shared.generateImage(for: saved)
        }
        focusedField = nil
        Haptics.success()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { collected = true }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            dismiss()
        }
    }

    private enum ScannerTarget: String, Identifiable {
        case word, context
        var id: String { rawValue }
        var selectionMode: LiveTextScannerSelectionMode { self == .word ? .word : .context }
    }
}

private extension View {
    func flowCard() -> some View {
        modifier(FlowCardModifier())
    }

    func flowField(isElevated: Bool = false) -> some View {
        modifier(FlowFieldModifier(isElevated: isElevated))
    }
}

private struct FlowCardModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.separator.opacity(contrast == .increased ? 0.65 : 0.18), lineWidth: 0.5)
            }
            .shadow(color: Color.deepPurple.opacity(0.055), radius: 12, y: 4)
    }
}

private struct FlowFieldModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    let isElevated: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appBackground.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isElevated ? Color.lavender.opacity(0.72) : Color.lavender.opacity(contrast == .increased ? 0.52 : 0.24),
                        lineWidth: isElevated ? 1.25 : 0.75
                    )
            }
            .shadow(color: Color.deepPurple.opacity(isElevated ? 0.12 : 0), radius: 8, y: 3)
            .scaleEffect(isElevated ? 1.006 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.86), value: isElevated)
    }
}

#Preview { AddWordView().modelContainer(for: VocabularyWord.self, inMemory: true) }
