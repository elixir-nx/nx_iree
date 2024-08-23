//
//  NxAddon.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import LiveViewNative
import SwiftUI

class iree_vm_instance_t {}
class iree_hal_driver_registry_t {}
class iree_hal_device_t {}

var globalVmInstance: UnsafeMutablePointer<iree_vm_instance_t>?
var globalDriverRegistry: UnsafeMutablePointer<iree_hal_driver_registry_t>?

@_silgen_name("nx_iree_initialize")
func nx_iree_initialize(
    _ vm_instance: UnsafeMutablePointer<iree_vm_instance_t>,
    _ driver_registry: UnsafeMutablePointer<iree_hal_driver_registry_t>,
    _ error_message: UnsafeMutablePointer<CChar>) -> Int

@_silgen_name("nx_iree_create_device")
func nx_iree_create_device(
    _ driver_registry: UnsafeMutablePointer<iree_hal_driver_registry_t>,
    _ name: UnsafePointer<CChar>) -> UnsafeMutablePointer<iree_hal_device_t>

@_silgen_name("nx_iree_call")
func nx_iree_call(
    _ vm_instance: UnsafeMutablePointer<iree_vm_instance_t>,
    _ device: UnsafeMutablePointer<iree_hal_device_t>,
    _ bytecode_size: UInt64,
    _ bytecode: UnsafePointer<CUnsignedChar>,
    _ num_inputs: UInt64,
    _ serialized_inputs: UnsafePointer<UnsafePointer<CChar>>,
    _ num_outputs: UInt64,
    _ serialized_outputs: UnsafePointer<UnsafePointer<CChar>>,
    _ error_message: UnsafeMutablePointer<CChar>) -> Int



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
