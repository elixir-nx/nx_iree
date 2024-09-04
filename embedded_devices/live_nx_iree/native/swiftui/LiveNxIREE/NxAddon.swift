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

@_silgen_name("nx_iree_list_all_devices")
func nx_iree_list_all_devices(_ count: UnsafeMutablePointer<UInt64>) -> UnsafePointer<UnsafePointer<CChar>?>?

@_silgen_name("nx_iree_create_device")
func nx_iree_create_device(_ name: UnsafePointer<CChar>) -> UnsafePointer<iree_hal_device_t>?

@_silgen_name("nx_iree_release_device")
func nx_iree_release_device(_ device: UnsafePointer<iree_hal_device_t>?) -> Void

@_silgen_name("nx_iree_call")
func nx_iree_call(
    _ vm_instance: UnsafePointer<iree_vm_instance_t>,
    _ device: UnsafePointer<iree_hal_device_t>,
    _ bytecode_size: UInt64,
    _ bytecode: UnsafePointer<CUnsignedChar>,
    _ num_inputs: UInt64,
    _ serialized_inputs: UnsafePointer<UnsafePointer<CChar>>,
    _ num_outputs: UInt64,
    _ error_message: UnsafeMutablePointer<CChar>,
    _ output_byte_sizes: UnsafeMutablePointer<UInt64>
) -> UnsafePointer<UnsafePointer<CChar>>?

@_silgen_name("nx_iree_image_call")
func nx_iree_image_call(
    _ vm_instance: UnsafePointer<iree_vm_instance_t>,
    _ device: UnsafePointer<iree_hal_device_t>,
    _ bytecode_size: UInt64,
    _ bytecode: UnsafePointer<CUnsignedChar>,
    _ input_dims: UnsafePointer<UInt64>,
    _ serialized_input: UnsafePointer<CUnsignedChar>,
    _ error_message: UnsafeMutablePointer<CChar>,
    _ seed: UInt32,
    _ noiseAmount: Float
) -> UnsafeMutablePointer<CUnsignedChar>?

func nxIREEListAllDevices() -> [String] {
    var count: UInt64 = 0
    guard let devicesPointer = nx_iree_list_all_devices(&count) else {
        return []
    }
    
    var devices: [String] = []
    for i in 0..<Int(count) {
        if let deviceCString = devicesPointer[i] {
            devices.append(String(cString: deviceCString))
        }
    }
    
    return devices
}

public extension Addons {
    @Addon
    struct NxAddon<Root: RootRegistry> {
        public enum TagName: String {
            case nxFunction = "NxFunction"
            case nxCameraFunction = "NxCameraFunction"
        }

        @ViewBuilder
        public static func lookup(_ name: TagName, element: ElementNode) -> some View {
            switch name {
            case .nxFunction:
                NxFunctionView<Root>()
            case .nxCameraFunction:
                NxCameraFunctionView<Root>()
            }
        }
    }
}
