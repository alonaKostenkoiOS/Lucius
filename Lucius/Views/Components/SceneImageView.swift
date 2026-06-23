import SwiftUI

/// Displays a stored scene image as a rounded card.
struct SceneImageView: View {
    let imageData: Data
    var height: CGFloat = 220

    var body: some View {
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .elevation(.card)
                .accessibilityLabel("Generated memory scene image")
        }
    }
}
