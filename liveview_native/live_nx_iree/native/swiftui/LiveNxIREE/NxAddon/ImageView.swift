//
//  Base64ImageView.swift
//  NxLVN
//
//  Created by Paulo.Valente on 1/28/24.
//

import SwiftUI
import LiveViewNative

public struct ImageView: View {
    /// The interactions allowed on the map.
    @_documentation(visibility: public)
    @State private var image: UIImage? = nil
    
    func update(_ image: UIImage?) {
        self.image = image
    }
        
    public var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable() // Make the image resizable
                .aspectRatio(contentMode: .fit) // Maintain aspect ratio and fill the frame
        }
    }
}
