//
//  NxAddon.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import LiveViewNative
import SwiftUI

public extension Addons {
    @Addon
    struct NxAddon<Root: RootRegistry> {
        public enum TagName: String {
            case nxFunction = "NxFunction"
        }

        @ViewBuilder
        public static func lookup(_ name: TagName, element: ElementNode) -> some View {
            switch name {
            case .nxFunction:
                NxFunctionView<Root>()
            }
        }
    }
}
