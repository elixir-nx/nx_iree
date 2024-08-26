//
//  NxFunction.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import SwiftUI
import LiveViewNative

@LiveElement
struct NxCameraFunctionView<Root: RootRegistry>: View {
    @_documentation(visibility: public)
    @LiveAttribute("bytecode") private var bytecode: String? = nil
    @LiveAttribute("device") private var deviceURI: String? = nil
    @Event("on-mount", type: "change") private var onMount
    
    @LiveElementIgnored
    private var vmInstance: UnsafePointer<iree_vm_instance_t>? = nil
    
    private let imageView = Base64ImageView()
    
    init() {
        vmInstance = nx_iree_create_instance()
    }
    
    var body: some View {
        VStack {
            if bytecode != nil {
                Text("Code loaded")
                    .padding()
            } else {
                Text("Code not loaded")
                    .padding()
            }
            CameraCaptureView()
            imageView
        }
        .onAppear() {
            onMount(value: nxIREEListAllDevices())
        }
    }
    
    private func convertBase64StringToBytecode(_ base64String: String) -> (bytecodeSize: UInt64, bytecodePointer: UnsafePointer<CUnsignedChar>?)? {
        // Step 1: Decode the Base64 string into Data
        guard let decodedData = Data(base64Encoded: base64String) else {
            print("Failed to decode base64 string.")
            return nil
        }
        
        // Step 2: Get the size of the data
        let bytecodeSize = UInt64(decodedData.count)
        
        // Step 3: Convert Data to UnsafePointer<CUnsignedChar>
        // We use `withUnsafeBytes` to get a pointer to the data
        let bytecodePointer = decodedData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> UnsafePointer<CUnsignedChar>? in
            return pointer.bindMemory(to: CUnsignedChar.self).baseAddress
        }
        
        return (bytecodeSize, bytecodePointer)
    }
    
    private func convertToCStringArray(from strings: [String]) -> UnsafePointer<UnsafePointer<CChar>>? {
        // Array to hold the C strings (UnsafePointer<CChar>)
        var cStrings: [UnsafePointer<CChar>] = []
        
        for string in strings {
            // Decode the base64 string to Data
            guard let decodedData = Data(base64Encoded: string) else {
                print("Failed to decode base64 string: \(string)")
                return nil
            }
            
            // Convert Data to a C string (null-terminated UTF-8)
            let cString = decodedData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> UnsafePointer<CChar>? in
                guard let baseAddress = pointer.baseAddress else { return nil }
                // Allocate memory for the C string and copy the data
                let cStringPointer = UnsafeMutablePointer<CChar>.allocate(capacity: decodedData.count + 1)
                cStringPointer.initialize(from: baseAddress.assumingMemoryBound(to: CChar.self), count: decodedData.count)
                cStringPointer[decodedData.count] = 0 // Null-terminate the string
                return UnsafePointer(cStringPointer)
            }
            
            guard let cStr = cString else {
                print("Failed to convert Data to C string.")
                return nil
            }
            
            cStrings.append(cStr)
        }
        
        // Allocate memory for the array of C strings
        let cStringsPointer = UnsafeMutablePointer<UnsafePointer<CChar>>.allocate(capacity: cStrings.count)
        
        // Copy the C strings to the allocated array
        cStringsPointer.initialize(from: &cStrings, count: cStrings.count)
        
        // Return the pointer to the array
        return UnsafePointer(cStringsPointer)
    }
    
    private func base64EncodedStrings(
        from serializedOutputs: UnsafePointer<UnsafePointer<CChar>>,
        sizes: UnsafeMutablePointer<UInt64>,
        count: Int) -> [String] {
        var base64Strings: [String] = []

        for i in 0..<count {
            let cStringPointer = serializedOutputs.advanced(by: i).pointee
            let size = Int(sizes[i])  // Convert UInt64 to Int

            // Create a Data object from the raw bytes
            let data = Data(bytes: cStringPointer, count: size)

            // Encode the Data to Base64
            let base64String = data.base64EncodedString()
            print("base64String: \(base64String)")
            base64Strings.append(base64String)
        }

        return base64Strings
    }
    
    private func run() {
        print("run called")
   }
}
