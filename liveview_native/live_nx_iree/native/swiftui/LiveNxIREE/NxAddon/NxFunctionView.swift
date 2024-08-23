//
//  NxFunction.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import SwiftUI
import LiveViewNative

@LiveElement
struct NxFunctionView<Root: RootRegistry>: View {
    @_documentation(visibility: public)
    @LiveAttribute("bytecode") private var bytecode: String? = nil
    @LiveAttribute("signature") private var signature: String? = nil
    @LiveAttribute("device") private var deviceURI: String? = nil
    @LiveAttribute("inputs") private var serializedInputs: [String]? = nil
    @LiveAttribute("num-outputs") private var numOutputs: Int? = nil
    @Event("on-execution", type: "change") private var change
    
    @LiveElementIgnored
    private var vmInstance: UnsafePointer<iree_vm_instance_t>? = nil
    
    init() {
        vmInstance = nx_iree_create_instance()
    }
    
    var body: some View {
        VStack {
            if signature != nil {
                Text(signature!)
                    .padding()
            }
        }
        .onAppear() {
            run()
        }
        .onChange(of: bytecode) {
            run()  // Run the function when bytecode changes
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
    
    private func base64EncodedStrings(from serializedOutputs: UnsafePointer<UnsafePointer<CChar>>, count: Int) -> [String] {
        // Convert UnsafePointer to a Swift array of UnsafePointer<CChar>
        let cStringPointers = Array(UnsafeBufferPointer(start: serializedOutputs, count: count))
        
        var base64Strings: [String] = []
        
        for cStringPointer in cStringPointers {
            // Convert each C string to a Swift String
            let string = String(cString: cStringPointer)
            
            // Encode the string to Base64
            if let data = string.data(using: .utf8) {
                let base64String = data.base64EncodedString()
                base64Strings.append(base64String)
            }
        }
        
        return base64Strings
    }

    
    private func run() {
        if bytecode != nil,
           deviceURI != nil,
           vmInstance != nil,
           serializedInputs != nil,
           let (bytecodeSize, bytecodePointer) = convertBase64StringToBytecode(bytecode!),
           let inputs = convertToCStringArray(from: serializedInputs!) {
            let deviceURIcstr = strdup(deviceURI!)
            let device = nx_iree_create_device(UnsafePointer(deviceURIcstr)!)
            deviceURIcstr?.deallocate()
            
            let errorMessage = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
            
            print("Executing function \(signature ?? "None") on device: \(deviceURI ?? "None")")

            let serializedOutputs = nx_iree_call(
                vmInstance!,
                device!,
                bytecodeSize,
                bytecodePointer!,
                UInt64(serializedInputs!.count),
                inputs,
                UInt64(numOutputs!),
                errorMessage)
            
            if serializedOutputs == nil {
                let errorString = String(cString: errorMessage)
                print("Failed execution with error: \(errorString)")
                return
            }
            
            for i in 0..<serializedInputs!.count {
                inputs[i].deallocate()
            }
            inputs.deallocate()
            
            print("Finished executing. Preparing to send results back.")
            print("outputs: \(serializedOutputs)")
            print("numOutputs: \(numOutputs)")
            
            change(value: base64EncodedStrings(from: serializedOutputs!, count: numOutputs!))
        } else {
            print("vm: \(vmInstance)")
            print("deviceURI: \(deviceURI)")
            print("bytecode: \(bytecode)")
            print("IREE components are not initialized.")
        }
   }
}
