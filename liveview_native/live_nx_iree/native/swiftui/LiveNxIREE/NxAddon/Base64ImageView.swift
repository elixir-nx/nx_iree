//
//  Base64ImageView.swift
//  NxLVN
//
//  Created by Paulo.Valente on 1/28/24.
//

import SwiftUI
import LiveViewNative

public struct Base64ImageView: View {
    /// The interactions allowed on the map.
    @_documentation(visibility: public)
    @State private var data: String? = nil
        
    public var body: some View {
        if let uiImage = decodeBase64ToImage(base64String: data) {
            Image(uiImage: uiImage)
                .resizable() // Make the image resizable
                .aspectRatio(contentMode: .fit) // Maintain aspect ratio and fill the frame
        }
    }

    /// Decodes a base64 encoded string to a `UIImage`.
    /// - Parameter base64String: The base64 encoded string of the image.
    /// - Returns: An optional `UIImage` if decoding is successful.
    func decodeBase64ToImage(base64String: String?) -> UIImage? {
        if (base64String == nil) { return nil }
        guard let imageData = Data(base64Encoded: base64String!) else {
            print("Failed to decode image!")
            return nil
        }
        return UIImage(data: imageData)
    }
}
