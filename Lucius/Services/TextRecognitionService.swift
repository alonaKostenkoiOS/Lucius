import Foundation
import Vision
import UIKit

/// Runs on-device OCR over a photo of a book page using the Vision
/// framework. Fully offline and private — nothing leaves the device.
enum TextRecognitionService {
    enum RecognitionError: Error {
        case invalidImage
        case failed
    }

    /// Recognizes printed text in the given image data and returns it as
    /// newline-joined lines, in reading order.
    static func recognizeText(in imageData: Data) async throws -> String {
        guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
            throw RecognitionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    continuation.resume(throwing: RecognitionError.failed)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: uiImage.cgImageOrientation)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: RecognitionError.failed)
            }
        }
    }
}

private extension UIImage {
    /// Maps UIKit image orientation to the CGImagePropertyOrientation Vision wants.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
