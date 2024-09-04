import SwiftUI
import AVFoundation
import LiveViewNative

class CameraCaptureView: ObservableObject {
    @Published var cameraManager: CameraManager
    @Published var imageHeight: Int
    @Published var imageWidth: Int
    @Published var cameraPreview: CameraPreview?
    
    init() {
        let cameraManager = CameraManager()
        self.cameraManager = cameraManager
        self.imageHeight = 0
        self.imageWidth = 0
        self.cameraPreview = nil
    }
    
    func initCameraPreview(height: Int, width: Int) {
        self.imageHeight = height
        self.imageWidth = width
        self.cameraPreview = CameraPreview(cameraManager: cameraManager, desiredHeight: height, desiredWidth: width)
    }
}

public struct CameraCaptureViewContainer: View  {
    @ObservedObject var cameraView: CameraCaptureView
    
    init(cameraView: CameraCaptureView) {
        self.cameraView = cameraView
    }
    
    public var body: some View {
        VStack {
            if let view = cameraView.cameraPreview {
                view.frame(width: CGFloat(cameraView.imageWidth), height: CGFloat(cameraView.imageHeight))
                    
            } else {
                Text("No preview available")
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
    var previewLayer: AVCaptureVideoPreviewLayer?

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
            transform = transform.scaledBy(x: -1, y: 1)
        case .landscapeRight:
            transform = CGAffineTransform(rotationAngle: 0)
            transform = transform.scaledBy(x: -1, y: 1)
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
    @ObservedObject var cameraManager: CameraManager
    var desiredHeight: Int // Add a desired height parameter
    var desiredWidth: Int
    var previewLayer: AVCaptureVideoPreviewLayer? = nil

    func makeUIView(context: Context) -> UIViewType {
        let view = UIView()
        // Set the frame of the view to have the desired height while maintaining the screen width
        view.frame = CGRect(x: 0, y: 0, width: CGFloat(desiredWidth), height: CGFloat(desiredHeight))

        if cameraManager.previewLayer == nil {
            let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
            previewLayer.frame = view.bounds // Set the previewLayer frame to match the view bounds
            previewLayer.videoGravity = .resizeAspect // Use .resizeAspect to maintain the aspect ratio
            previewLayer.connection?.videoRotationAngle = 180
            view.layer.addSublayer(previewLayer)
        }
        
        

        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
