// LiveTextScannerView.swift
// Adds a live camera text scanning sheet using VisionKit's DataScanner.

import Foundation
import SwiftUI
import VisionKit

@available(iOS 16.0, *)
struct LiveTextScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true
    @State private var candidateWords: [String] = []

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
                        handleRecognizedText(text)
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
                    scannerControls
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
    private var scannerControls: some View {
        if candidateWords.isEmpty {
            Label("Point at printed text, then tap the highlighted word or phrase", systemImage: "hand.tap")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
        } else {
            VStack(spacing: 12) {
                Text("Choose one word")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(candidateWords, id: \.self) { word in
                            Button(word) { select(word) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Button("Scan again", systemImage: "camera.viewfinder") {
                    candidateWords = []
                    isScanning = true
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    private func handleRecognizedText(_ text: String) {
        let words = ScannedWordExtractor.words(in: text)
        guard !words.isEmpty else { return }

        if words.count == 1, let word = words.first {
            select(word)
        } else {
            candidateWords = words
            isScanning = false
        }
    }

    private func select(_ word: String) {
        onSelection(word)
        dismiss()
    }
}

/// Splits a recognized line into the individual words the user can choose.
enum ScannedWordExtractor {
    static func words(in text: String) -> [String] {
        var seen = Set<String>()

        return text
            .lowercased()
            .split { character in
                !character.isLetter && character != "'" && character != "’" && character != "-"
            }
            .compactMap { token in
                let word = String(token).replacingOccurrences(of: "’", with: "'")
                guard !word.isEmpty, seen.insert(word).inserted else { return nil }
                return word
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
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onRecognized: (String) -> Void

        init(onRecognized: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let textItem) = item {
                onRecognized(textItem.transcript)
            }
        }
    }
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    LiveTextScannerView { _ in }
}
#endif
