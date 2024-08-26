//
//  Base64ImageView.swift
//  NxLVN
//
//  Created by Paulo.Valente on 1/28/24.
//

import SwiftUI
import LiveViewNative

class ImageView: ObservableObject {
    @Published var image: UIImage? = nil
    
    func update(_ newImage: UIImage?) {
        self.image = newImage
    }
}

public struct ImageViewContainer: View {
    /// The interactions allowed on the map.
    @_documentation(visibility: public)
    @ObservedObject var imageView: ImageView
        
    public var body: some View {
        if let image = imageView.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text("No image available")
                .padding()
        }
    }
}
