// LiveTextScannerView.swift
// Adds a live camera text scanning sheet using VisionKit's DataScanner.

import Foundation
import NaturalLanguage
import SwiftUI
import UIKit
import Vision
import VisionKit

enum LiveTextScannerSelectionMode: Equatable {
    case word
    case context

    var title: String {
        switch self {
        case .word: "Scan word"
        case .context: "Scan context"
        }
    }

    var instruction: String {
        switch self {
        case .word: "Tap a word on the camera preview to add it"
        case .context: "Keep the word and its sentence in view"
        }
    }
}

@available(iOS 16.0, *)
struct LiveTextScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true

    var selectionMode: LiveTextScannerSelectionMode = .word
    var searchWord: String?
    var onSelection: (String) -> Void

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if isScannerAvailable {
                    DataScannerContainer(
                        isScanning: $isScanning,
                        selectionMode: selectionMode,
                        searchWord: searchWord
                    ) { text in
                        onSelection(text)
                        dismiss()
                    }
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Camera text scanning isn’t available on this device.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle(selectionMode.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isScannerAvailable {
                    if selectionMode == .context {
                        contextControls
                    } else {
                        Label(selectionMode.instruction, systemImage: "hand.tap")
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var contextControls: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("We are searching for context")
                .font(.headline)

            if let searchWord, !searchWord.isEmpty {
                Text("Looking for “\(searchWord)” and the sentence containing it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(selectionMode.instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

/// Finds individual words and their positions within a recognized line.
enum ScannedWordExtractor {
    struct Match {
        let word: String
        let range: NSRange
    }

    private static let expression = try! NSRegularExpression(
        pattern: #"\p{L}+(?:['’-]\p{L}+)*"#
    )

    static func matches(in text: String) -> [Match] {
        let fullRange = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: fullRange).compactMap { result in
            guard let range = Range(result.range, in: text) else { return nil }
            let word = text[range]
                .lowercased()
                .replacingOccurrences(of: "’", with: "'")
            return Match(word: word, range: result.range)
        }
    }

}

/// Splits recognized camera text into complete, unique sentence candidates.
enum ScannedContextExtractor {
    static func sentences(in recognizedText: String) -> [String] {
        let text = recognizedText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !text.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var seen = Set<String>()
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.split(whereSeparator: \.isWhitespace).count >= 2,
               seen.insert(sentence).inserted {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    static func sentence(containing searchTerm: String, in recognizedText: String) -> String? {
        sentences(in: recognizedText).first { sentence in
            contains(searchTerm: searchTerm, in: sentence)
        }
    }

    static func contains(searchTerm: String, in text: String) -> Bool {
        let term = normalized(searchTerm)
        guard !term.isEmpty else { return false }

        let pattern = #"(?<!\p{L})"# + NSRegularExpression.escapedPattern(for: term) + #"(?!\p{L})"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let source = normalized(text)
        return expression.firstMatch(
            in: source,
            range: NSRange(source.startIndex..., in: source)
        ) != nil
    }

    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "’", with: "'")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@available(iOS 16.0, *)
struct DataScannerContainer: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    var selectionMode: LiveTextScannerSelectionMode
    var searchWord: String?
    var onRecognized: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectionMode: selectionMode,
            searchWord: searchWord,
            onRecognized: onRecognized
        )
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: false
        )
        controller.delegate = context.coordinator
        context.coordinator.attach(to: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    static func dismantleUIViewController(
        _ uiViewController: DataScannerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopScanning()
        coordinator.detach()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate, UIGestureRecognizerDelegate {
        private let onRecognized: (String) -> Void
        private let selectionMode: LiveTextScannerSelectionMode
        private let searchWord: String
        private weak var scanner: DataScannerViewController?
        private var recognizedItems: [RecognizedItem] = []
        private var tapRecognizer: UITapGestureRecognizer?
        private var isCapturingContext = false
        private var lastCaptureAttempt = Date.distantPast

        init(
            selectionMode: LiveTextScannerSelectionMode,
            searchWord: String?,
            onRecognized: @escaping (String) -> Void
        ) {
            self.selectionMode = selectionMode
            self.searchWord = searchWord?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.onRecognized = onRecognized
        }

        func attach(to scanner: DataScannerViewController) {
            self.scanner = scanner
            guard selectionMode == .word else { return }
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            scanner.view.addGestureRecognizer(recognizer)
            tapRecognizer = recognizer
        }

        func detach() {
            if let tapRecognizer {
                scanner?.view.removeGestureRecognizer(tapRecognizer)
            }
            tapRecognizer = nil
            recognizedItems = []
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            recognizedItems = allItems
            searchForContextIfNeeded(using: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            recognizedItems = allItems
            searchForContextIfNeeded(using: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            recognizedItems = allItems
            searchForContextIfNeeded(using: dataScanner)
        }

        private func searchForContextIfNeeded(using dataScanner: DataScannerViewController) {
            guard selectionMode == .context,
                  !searchWord.isEmpty,
                  !isCapturingContext,
                  Date().timeIntervalSince(lastCaptureAttempt) >= 1.5
            else { return }

            let liveText = recognizedItems.compactMap { item -> String? in
                guard case .text(let textItem) = item else { return nil }
                return textItem.transcript
            }.joined(separator: "\n")
            guard ScannedContextExtractor.contains(searchTerm: searchWord, in: liveText) else { return }

            isCapturingContext = true
            lastCaptureAttempt = Date()
            Task { [weak self, weak dataScanner] in
                guard let self, let dataScanner else { return }

                var capturedSentence: String?
                if let image = try? await dataScanner.capturePhoto(),
                   let data = image.jpegData(compressionQuality: 0.95),
                   let text = try? await TextRecognitionService.recognizeText(in: data) {
                    capturedSentence = ScannedContextExtractor.sentence(
                        containing: searchWord,
                        in: text
                    )
                }

                if let sentence = capturedSentence {
                    onRecognized(sentence)
                } else {
                    isCapturingContext = false
                }
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = scanner?.view else { return }
            let point = recognizer.location(in: view)

            let hits = recognizedItems.flatMap(wordHits)
            if let exactHit = hits
                .filter({ $0.path.contains(point) })
                .min(by: { $0.area < $1.area }) {
                onRecognized(exactHit.word)
                return
            }

            // OCR boxes can be a few pixels tighter than a fingertip. Accept only
            // a nearby word, so a tap on empty space never adds something random.
            if let nearbyHit = hits
                .map({ ($0, distance(from: point, to: $0.center)) })
                .filter({ $0.1 <= 24 })
                .min(by: { $0.1 < $1.1 })?.0 {
                onRecognized(nearbyHit.word)
            }
        }

        private struct WordHit {
            let word: String
            let path: UIBezierPath
            let center: CGPoint
            let area: CGFloat
        }

        private func wordHits(for item: RecognizedItem) -> [WordHit] {
            guard case .text(let textItem) = item,
                  let candidate = textItem.observation.topCandidates(1).first
            else { return [] }

            return ScannedWordExtractor.matches(in: candidate.string).compactMap { match in
                guard let range = Range(match.range, in: candidate.string),
                      let wordBox = try? candidate.boundingBox(for: range)
                else { return nil }

                let topLeft = viewPoint(
                    for: wordBox.topLeft,
                    in: textItem.observation,
                    viewBounds: textItem.bounds
                )
                let topRight = viewPoint(
                    for: wordBox.topRight,
                    in: textItem.observation,
                    viewBounds: textItem.bounds
                )
                let bottomRight = viewPoint(
                    for: wordBox.bottomRight,
                    in: textItem.observation,
                    viewBounds: textItem.bounds
                )
                let bottomLeft = viewPoint(
                    for: wordBox.bottomLeft,
                    in: textItem.observation,
                    viewBounds: textItem.bounds
                )

                let path = UIBezierPath()
                path.move(to: topLeft)
                path.addLine(to: topRight)
                path.addLine(to: bottomRight)
                path.addLine(to: bottomLeft)
                path.close()

                return WordHit(
                    word: match.word,
                    path: path,
                    center: CGPoint(
                        x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4,
                        y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4
                    ),
                    area: polygonArea([topLeft, topRight, bottomRight, bottomLeft])
                )
            }
        }

        /// Maps a normalized Vision point inside its text observation to the
        /// matching point in DataScanner's live view quadrilateral.
        private func viewPoint(
            for point: CGPoint,
            in observation: VNRecognizedTextObservation,
            viewBounds: RecognizedItem.Bounds
        ) -> CGPoint {
            let origin = observation.bottomLeft
            let horizontal = CGPoint(
                x: observation.bottomRight.x - origin.x,
                y: observation.bottomRight.y - origin.y
            )
            let vertical = CGPoint(
                x: observation.topLeft.x - origin.x,
                y: observation.topLeft.y - origin.y
            )
            let relative = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
            let determinant = horizontal.x * vertical.y - horizontal.y * vertical.x
            guard abs(determinant) > .ulpOfOne else { return viewBounds.topLeft }

            let horizontalFraction = (relative.x * vertical.y - relative.y * vertical.x) / determinant
            let verticalFraction = (horizontal.x * relative.y - horizontal.y * relative.x) / determinant
            let bottom = interpolate(
                viewBounds.bottomLeft,
                viewBounds.bottomRight,
                fraction: horizontalFraction
            )
            let top = interpolate(
                viewBounds.topLeft,
                viewBounds.topRight,
                fraction: horizontalFraction
            )
            return interpolate(bottom, top, fraction: verticalFraction)
        }

        private func interpolate(_ start: CGPoint, _ end: CGPoint, fraction: CGFloat) -> CGPoint {
            CGPoint(
                x: start.x + (end.x - start.x) * fraction,
                y: start.y + (end.y - start.y) * fraction
            )
        }

        private func polygonArea(_ points: [CGPoint]) -> CGFloat {
            guard points.count > 2 else { return 0 }
            return abs(points.indices.reduce(CGFloat.zero) { result, index in
                let next = points[(index + 1) % points.count]
                return result + points[index].x * next.y - next.x * points[index].y
            }) / 2
        }

        private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
            hypot(second.x - first.x, second.y - first.y)
        }

    }
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    LiveTextScannerView(selectionMode: .word, searchWord: nil) { _ in }
}
#endif
