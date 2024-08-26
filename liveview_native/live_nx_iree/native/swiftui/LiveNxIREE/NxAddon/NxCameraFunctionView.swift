//
//  NxFunction.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import SwiftUI
import LiveViewNative

import UIKit

extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage? {
        // Use the scale of the current image to ensure the correct size
        let scale = self.scale
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        self.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func getRGBData() -> ([UInt8], [UInt64])? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4 // Only RGB (3 bytes per pixel)
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow
        
        var rgbData = [UInt8](repeating: 0, count: totalBytes)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &rgbData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return (rgbData, [3, UInt64(height), UInt64(width)])
    }
}

@LiveElement
struct NxCameraFunctionView<Root: RootRegistry>: View {
    @_documentation(visibility: public)
    @LiveAttribute("bytecode") private var bytecode: String? = nil
    @LiveAttribute("device") private var deviceURI: String? = nil
    @LiveAttribute("height") private var height: Int? = nil
    @LiveAttribute("width") private var width: Int? = nil
    @Event("on-mount", type: "change") private var onMount
    
    @LiveElementIgnored
    private var vmInstance: UnsafePointer<iree_vm_instance_t>? = nil
    
    @LiveElementIgnored
    @StateObject private var imageView = ImageView()
    
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
            CameraCaptureView(height: height!, width: width!) { image in
                run(image)
            }
            ImageViewContainer(imageView: imageView)
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
    
    private func imageFromRGBData(rgbData: [UInt8], width: Int, height: Int) -> UIImage? {
        // Ensure that the data size is correct
        let expectedSize = width * height * 3
        guard rgbData.count == expectedSize else {
            print("Invalid data size")
            return nil
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        
        guard let context = CGContext(
            data: UnsafeMutableRawPointer(mutating: rgbData),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("Failed to create CGContext")
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            print("Failed to create CGImage")
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func run(_ image: UIImage) {
        print("run called")
        
        if vmInstance != nil,
           deviceURI != nil,
           bytecode != nil,
           let resizedImage = image.resize(to: CGSize(width: width!, height: height!)),
           let (pixelData, inputDims) = resizedImage.getRGBData(),
           let (bytecodeSize, bytecodePointer) = convertBase64StringToBytecode(bytecode!) {
            let deviceURIcstr = strdup(deviceURI!)
            let device = nx_iree_create_device(UnsafePointer(deviceURIcstr)!)
            deviceURIcstr?.deallocate()
            
            let errorMessage = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
                        
            let outputPixelDataPointer = nx_iree_image_call(vmInstance!, device!, bytecodeSize, bytecodePointer!, inputDims, pixelData, errorMessage)
            
            guard let _ = outputPixelDataPointer else {
               return
           }
    
           // Create a [UInt8] array from the pointer
           let buffer = UnsafeBufferPointer(start: outputPixelDataPointer, count: width! * height! * 3)
           let outputPixelData = Array(buffer)
            
            let outputImage = imageFromRGBData(rgbData: outputPixelData, width: width!, height: height!)
            
            self.imageView.update(outputImage);
        }
   }
}
