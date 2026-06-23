import Photos

/// Saves generated scene images into the user's photo library.
/// Uses add-only access, so iOS shows the lightweight permission prompt.
struct PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private init() {}

    func save(imageData: Data) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
