import SwiftUI
import AVFoundation
import LiveViewNative

/// `CameraCaptureView` component for capturing images using the camera.
///
/// Use an event attribute to specify which event to fire when an image is captured.
///
/// Example usage in SwiftUI:
///
/// ```swift
/// CameraCaptureView(phx_capture: "imageCaptured")
/// ```
///
/// Handling the captured image event:
///
/// ```swift
/// func handleEvent("imageCaptured", capturedImage: UIImage, socket) do {
///     // Process the captured image
/// }
/// ```
///
/// ## Attributes
/// * `phx_capture` - The event name to fire when an image is captured.
///
/// ## Events
/// * `capture` - Fired when an image is captured.
public struct CameraCaptureView: View {
    /// Event triggered when an image is captured.
    @State var serializedTensor: String?
    
    private let cameraManager = CameraManager()
    private let imageHeight: Int
    private let imageWidth: Int
    private let processImageCallback: (UIImage) -> Void
    
    init(height: Int, width: Int, processImageCallback: @escaping (UIImage) -> Void) {
        self.processImageCallback = processImageCallback
        self.imageWidth = width
        self.imageHeight = height
    }

    public var body: some View {
        VStack { // Use VStack to stack the preview and the button
            CameraPreview(cameraManager: cameraManager, desiredHeight: imageHeight, desiredWidth: imageWidth).frame(width: CGFloat(imageWidth), height: CGFloat(imageHeight))

            // Button directly under the camera preview
            Button(action: {
                cameraManager.captureImage { image in
                    processImageCallback(image)
                }
            }) {
                Text("Capture")
                    .foregroundColor(.white)
                    .lineLimit(1) // Ensure the text does not wrap to multiple lines
                    .minimumScaleFactor(0.5) // Allow the text to scale down if needed, up to 50% of its original size
                    .frame(width: 70, height: 70) // Define a frame for the text which matches the circle size
                    .background(Circle().fill(Color.blue))
                    .padding(.top) // Optional: Additional padding to separate the button from other content
            }
        }
    }
}

/// Camera Manager for handling camera setup and image capture.
public class CameraManager: NSObject, ObservableObject {
    internal let session = AVCaptureSession()
    private var output = AVCapturePhotoOutput()
    private var permissionGranted = false
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    var captureCompletion: ((UIImage) -> Void)?

    override init() {
        super.init()
        setupSession()
    }
    
    func checkAndRequestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                }
            }
        default:
            permissionGranted = false
        }

    }
    
    private func setupSession() {
        guard let camera = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .front
        ).devices.first else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) && session.canAddOutput(output) {
                session.addInput(input)
                session.addOutput(output)
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.startSession()
                }
            }
        } catch {
            print("Error setting up camera input: \(error)")
        }
    }
    
    private func startSession() {
        session.startRunning()
    }
    
    func captureImage(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    private func correctImageOrientation(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let orientation = UIDevice.current.orientation

        var transform: CGAffineTransform = .identity

        switch orientation {
        case .portrait:
            transform = .identity
        case .portraitUpsideDown:
            transform = .identity
        case .landscapeLeft:
            transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        case .landscapeRight:
            transform = CGAffineTransform(rotationAngle: 0)
        default:
            transform = .identity
        }

        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: cgImage.bytesPerRow,
            space: cgImage.colorSpace!,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        )!

        context.concatenate(transform)

        var rect: CGRect = .init(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
//        if !(orientation == .portrait || orientation == .portraitUpsideDown) {
        rect = rect.applying(transform)
//        }

        context.draw(cgImage, in: rect)

        if let newCgImage = context.makeImage() {
            return UIImage(cgImage: newCgImage)
        } else {
            return image
        }
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) {
            captureCompletion?(correctImageOrientation(image: image))
        }
    }
}

/// Camera Preview to display the camera feed.
struct CameraPreview: UIViewRepresentable {
    typealias UIViewType = UIView
    var cameraManager: CameraManager
    var desiredHeight: Int // Add a desired height parameter
    var desiredWidth: Int
    var previewLayer: AVCaptureVideoPreviewLayer? = nil

    func makeUIView(context: Context) -> UIViewType {
        let view = UIView()
        // Set the frame of the view to have the desired height while maintaining the screen width
        view.frame = CGRect(x: 0, y: 0, width: CGFloat(desiredWidth), height: CGFloat(desiredHeight))

        if (previewLayer == nil) {
            let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
            previewLayer.frame = view.bounds // Set the previewLayer frame to match the view bounds
            previewLayer.videoGravity = .resizeAspect // Use .resizeAspect to maintain the aspect ratio
            //        previewLayer.connection?.videoOrientation = UIDevice.current.orientation
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        guard let layer = previewLayer else { return }
        layer.videoGravity = .resizeAspect // Use .resizeAspect to maintain the aspect ratio
    }
}
