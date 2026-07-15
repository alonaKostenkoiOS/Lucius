// LiveTextScannerView.swift
// Adds a live camera text scanning sheet using VisionKit's DataScanner.

import Foundation
import SwiftUI
import UIKit
import Vision
import VisionKit

@available(iOS 16.0, *)
struct LiveTextScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true

    /// Called when the user taps a highlighted text item.
    var onSelection: (String) -> Void

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if isScannerAvailable {
                    DataScannerContainer(isScanning: $isScanning) { text in
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
            .navigationTitle("Live scan")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isScannerAvailable {
                    Label("Tap a word on the camera preview to add it", systemImage: "hand.tap")
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

@available(iOS 16.0, *)
struct DataScannerContainer: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    var onRecognized: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized)
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
        private weak var scanner: DataScannerViewController?
        private var recognizedItems: [RecognizedItem] = []
        private var tapRecognizer: UITapGestureRecognizer?

        init(onRecognized: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
        }

        func attach(to scanner: DataScannerViewController) {
            self.scanner = scanner
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
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            recognizedItems = allItems
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            recognizedItems = allItems
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
    LiveTextScannerView { _ in }
}
#endif
