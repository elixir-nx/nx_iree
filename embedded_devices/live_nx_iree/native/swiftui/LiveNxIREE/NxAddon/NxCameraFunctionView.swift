//
//  NxFunction.swift
//  LiveNxIREE
//
//  Created by Paulo.Valente on 8/22/24.
//

import SwiftUI
import LiveViewNative

import UIKit
import Combine

extension UIImage {
    func correctImageOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }

    func resize(to targetSize: CGSize) -> UIImage? {
        // Use the scale of the current image to ensure the correct size
        let scale = self.scale
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        self.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func getRGBAData() -> ([UInt8], [UInt64])? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4  // RGBA has 4 bytes per pixel
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow
        
        var rgbaData = [UInt8](repeating: 0, count: totalBytes)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &rgbaData,
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
        
        return (rgbaData, [UInt64(height), UInt64(width), 4])  // 4 channels (RGBA)
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
    
//    @LiveElementIgnored
//    @State private var bytecodeSize: UInt64 = 0
//    
//    @LiveElementIgnored
//    @State private var bytecodePointer: UnsafePointer<CUnsignedChar>? = nil
//    
    @LiveElementIgnored
    private var vmInstance: UnsafePointer<iree_vm_instance_t>? = nil
    
    @LiveElementIgnored
    @State private var device: UnsafePointer<iree_hal_device_t>? = nil
    
    @LiveElementIgnored
    @StateObject private var cameraView: CameraCaptureView = CameraCaptureView()
    
    @LiveElementIgnored
    @StateObject private var imageView = ImageView()
    
    @LiveElementIgnored
    @StateObject private var previewImageView = ImageView()
    
    @LiveElementIgnored
    @State private var timer: AnyCancellable?
    
    @LiveElementIgnored
    @State private var noiseAmount: Float = 0
    
    init() {
        if self.deviceURI != nil {
            let deviceURIcstr = strdup(deviceURI!)
            self.device = nx_iree_create_device(UnsafePointer(deviceURIcstr)!)
            free(deviceURIcstr)
        }
        
        vmInstance = nx_iree_create_instance()
        initCameraPreview()
    }
    
    private func initCameraPreview() {
        if let height = height, let width = width {
            cameraView.initCameraPreview(height: height, width: width)
        }
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
            HStack {
                Text("Noise Amount:").padding()
                SwiftUI.Slider(
                    value: $noiseAmount,
                    in: 0...1
                )
            }
            HStack {
                VStack {
                    Text("Input").padding()
                    CameraCaptureViewContainer(cameraView: cameraView)
                }
                VStack {
                    Text("Output").padding()
                    ImageViewContainer(imageView: imageView)
                }
            }
        }
        .onAppear() {
            initCameraPreview() // Initialize when the view appears
            onMount(value: nxIREEListAllDevices())
            startCaptureTimer()
        }
        .onChange(of: height) {
            initCameraPreview()
        }
        .onChange(of: width) {
            initCameraPreview()
        }
        .onDisappear {
            stopCaptureTimer()
        }
        .onChange(of: deviceURI) {
            if self.deviceURI != nil {
                if self.device != nil {
                    nx_iree_release_device(self.device)
                }
                let deviceURIcstr = strdup(deviceURI!)
                self.device?.deallocate()
                self.device = nx_iree_create_device(UnsafePointer(deviceURIcstr)!)
                free(deviceURIcstr)
            }
        }
        .onChange(of: bytecode) {
            stopCaptureTimer()
            startCaptureTimer()
        }
    }
    
    private func startCaptureTimer() {
        timer = Timer.publish(every: 1/60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                captureAndProcessImage()
            }
    }

    private func stopCaptureTimer() {
        timer?.cancel()
    }

    private func captureAndProcessImage() {
        cameraView.cameraManager.captureImage { image in
            DispatchQueue.main.async {
                self.run(image)
            }
        }
    }
        
    private func convertBase64StringToBytecode(_ decodedData: Data) -> (bytecodeSize: UInt64, bytecodePointer: UnsafePointer<CUnsignedChar>?)? {
        // Step 1: Get the size of the data
        let bytecodeSize = UInt64(decodedData.count)
        
        // Step 2: Convert Data to UnsafePointer<CUnsignedChar>
        // We use withUnsafeBytes to get a pointer to the data
        let bytecodePointer = decodedData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> UnsafePointer<CUnsignedChar>? in
            return pointer.bindMemory(to: CUnsignedChar.self).baseAddress
        }
        
        return (bytecodeSize, bytecodePointer)
    }
    
    func imageFromRGBAData(rgbaData: [UInt8], width: Int, height: Int) -> UIImage? {
        // Ensure that the data size matches the expected size
        guard rgbaData.count == width * height * 4 else {
            print("Invalid data size")
            return nil
        }
        
        // Create a CFData object from the RGBA data array
        let cfData = CFDataCreate(nil, rgbaData, rgbaData.count)
        
        // Create a CGDataProvider from the CFData object
        guard let dataProvider = CGDataProvider(data: cfData!) else {
            print("Failed to create CGDataProvider")
            return nil
        }
        
        // Define the color space (sRGB)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a CGImage from the data provider
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,        // 8 bits per component (per color channel)
            bitsPerPixel: 32,           // 32 bits per pixel (RGBA, 4 channels * 8 bits each)
            bytesPerRow: width * 4,     // 4 bytes per pixel times the width
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            print("Failed to create CGImage")
            return nil
        }
        
        // Convert the CGImage to a UIImage and return it
        return UIImage(cgImage: cgImage)
    }
    
    private func run(_ image: UIImage) {
        if vmInstance != nil,
           device != nil,
           bytecode != nil,
           let resizedImage = image.resize(to: CGSize(width: width!, height: height!)),
           var (pixelData, inputDims) = resizedImage.getRGBAData(),
           let decodedData = Data(base64Encoded: bytecode!),
           let (bytecodeSize, bytecodePointer) = convertBase64StringToBytecode(decodedData) {
            let errorMessageCapacity = 256
            let errorMessage = UnsafeMutablePointer<CChar>.allocate(capacity: errorMessageCapacity)
            
            let seed: UInt32 = .random(in: UInt32.min...UInt32.max)
            var outputPixelDataPointer: UnsafeMutablePointer<CUnsignedChar>? = nil
//            let outputPixelDataPointer: UnsafeMutablePointer<CUnsignedChar>? = nil
            pixelData.withUnsafeMutableBytes { rawBufferPointer in
                let ptr = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                // Now you can pass `cPointer` to your C function
                outputPixelDataPointer = nx_iree_image_call(vmInstance!, device!, bytecodeSize, UnsafePointer(bytecodePointer)!, inputDims, ptr, errorMessage, seed, noiseAmount)
            }
            
            
            guard let _ = outputPixelDataPointer else {
                let errorString = String(cString: errorMessage)
                print("Failed execution with error: \(errorString)")
                let mutablePointer = errorMessage.withMemoryRebound(to: CChar.self, capacity: Int(errorMessageCapacity), { $0 })
                mutablePointer.deallocate()
                return
            }
    
            // Create a [UInt8] array from the pointer
            let bufferCount = width! * height! * 4
            let buffer = UnsafeBufferPointer(start: UnsafePointer(outputPixelDataPointer), count: bufferCount)
            let outputPixelData = Array(buffer)
            
            let outputImage = imageFromRGBAData(rgbaData: outputPixelData, width: width!, height: height!)
            
            self.imageView.update(outputImage, width!, height!)
            
            let mutablePointer = errorMessage.withMemoryRebound(to: CChar.self, capacity: Int(errorMessageCapacity), { $0 })
            mutablePointer.deallocate()
            
            if let ptr = outputPixelDataPointer?.withMemoryRebound(to: CUnsignedChar.self, capacity: Int(bufferCount), { $0 }) {
                ptr.deallocate()
            }
        }
   }
}
