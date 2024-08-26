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
    private let imageHeight = 300.0
    private let processImageCallback: (UIImage) -> Void
    
    init(processImageCallback: @escaping (UIImage) -> Void) {
        self.processImageCallback = processImageCallback
    }

    public var body: some View {
        VStack { // Use VStack to stack the preview and the button
            CameraPreview(cameraManager: cameraManager, desiredHeight: imageHeight).frame(height: imageHeight) // Set your desired height

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
                startSession()
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
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) {
            captureCompletion?(image)
        }
    }
}

/// Camera Preview to display the camera feed.
struct CameraPreview: UIViewRepresentable {
    typealias UIViewType = UIView
    var cameraManager: CameraManager
    var desiredHeight: CGFloat // Add a desired height parameter

    func makeUIView(context: Context) -> UIViewType {
        let view = UIView()
        // Set the frame of the view to have the desired height while maintaining the screen width
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: desiredHeight)

        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.frame = view.bounds // Set the previewLayer frame to match the view bounds
        previewLayer.videoGravity = .resizeAspect // Use .resizeAspect to maintain the aspect ratio
        previewLayer.connection?.videoOrientation = currentVideoOrientation()
        view.layer.addSublayer(previewLayer)

        return view
    }
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
       switch UIDevice.current.orientation {
       case .portrait:
           return .portrait
       case .portraitUpsideDown:
           return .portraitUpsideDown
       case .landscapeRight:
           return .landscapeLeft
       case .landscapeLeft:
           return .landscapeRight
       default:
           return .portrait
       }
   }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        // If you need to update the view's frame or the preview layer's frame when the desiredHeight changes, do it here.
        // For example, if the desiredHeight can change, you might want to adjust the frame of both the uiView and the previewLayer here.
    }
}
