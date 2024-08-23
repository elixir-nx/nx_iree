//
//  NxAddon.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import LiveViewNative
import SwiftUI

class iree_vm_instance_t {}
class iree_hal_device_t {}

@_silgen_name("nx_iree_create_instance")
func nx_iree_create_instance() -> UnsafePointer<iree_vm_instance_t>?

@_silgen_name("nx_iree_create_device")
func nx_iree_create_device(_ name: UnsafePointer<CChar>) -> UnsafePointer<iree_hal_device_t>?

@_silgen_name("nx_iree_call")
func nx_iree_call(
    _ vm_instance: UnsafePointer<iree_vm_instance_t>,
    _ device: UnsafePointer<iree_hal_device_t>,
    _ bytecode_size: UInt64,
    _ bytecode: UnsafePointer<CUnsignedChar>,
    _ num_inputs: UInt64,
    _ serialized_inputs: UnsafePointer<UnsafePointer<CChar>>,
    _ num_outputs: UInt64,
    _ error_message: UnsafeMutablePointer<CChar>) -> UnsafePointer<UnsafePointer<CChar>>?



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
