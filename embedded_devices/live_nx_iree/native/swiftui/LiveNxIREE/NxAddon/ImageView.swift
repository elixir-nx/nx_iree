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
    @Published var width: Int? = nil
    @Published var height: Int? = nil
    
    func update(_ newImage: UIImage?, _ width: Int?, _ height: Int?) {
        self.image = newImage
        self.width = width
        self.height = height
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
                .aspectRatio(contentMode: .fit)
                .frame(width: CGFloat(imageView.width!), height: CGFloat(imageView.height!))
                .clipped()
        } else {
            Text("No image available")
                .padding()
        }
    }
}
