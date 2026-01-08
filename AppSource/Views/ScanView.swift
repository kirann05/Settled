import SwiftUI
import UIKit
import AVFoundation
import Photos
import Vision

// MARK: - Camera Permission Manager
class CameraPermissionManager: ObservableObject {
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var permissionMessage = ""
    
    init() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
    }
    
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func checkPhotoLibraryPermission() {
        photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus()
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraPermissionStatus = granted ? .authorized : .denied
                if !granted {
                    self?.showCameraPermissionDeniedAlert()
                }
            }
        }
    }
    
    func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryPermissionStatus = status
                if status != .authorized && status != .limited {
                    self?.showPhotoLibraryPermissionDeniedAlert()
                }
            }
        }
    }
    
    private func showCameraPermissionDeniedAlert() {
        permissionMessage = "Camera access is required to scan receipts. Please enable camera access in Settings > Privacy & Security > Camera > Settled."
        showPermissionAlert = true
    }
    
    private func showPhotoLibraryPermissionDeniedAlert() {
        permissionMessage = "Photo library access is required to upload receipt images. Please enable photo access in Settings > Privacy & Security > Photos > Settled."
        showPermissionAlert = true
    }
    
    var canUsePhotoLibrary: Bool {
        switch photoLibraryPermissionStatus {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }
}

// MARK: - Camera Capture View
struct CameraCapture: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false

        // Configure media types for JPEG/PNG only
        picker.mediaTypes = ["public.image"]

        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
            picker.showsCameraControls = false  // Hide default camera controls
            picker.cameraViewTransform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        } else if sourceType == .photoLibrary {
            // Additional configuration for photo library
            picker.modalPresentationStyle = .fullScreen
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapture

        init(_ parent: CameraCapture) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Camera Capture With Overlay Icons
struct CameraCaptureWithOverlay: View {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    let onImageCaptured: () -> Void
    let onUpload: () -> Void
    let onManualEntry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Full screen camera
            CameraCaptureView(capturedImage: $capturedImage, onImageCaptured: onImageCaptured)
                .ignoresSafeArea()

            // Top cancel button (moved to top-left)
            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.top, 60)
                    .padding(.leading, 20)
                    Spacer()
                }
                Spacer()
            }

            // Bottom overlay with camera button and action buttons
            VStack {
                Spacer()

                // Camera capture button (center, larger)
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("TakePhoto"), object: nil)
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 3)
                                .frame(width: 80, height: 80)
                        )
                }
                .padding(.bottom, 32)

                // Action buttons row with circular backgrounds
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Upload button (centered in left half)
                        Button(action: {
                            // Call onUpload directly - fullScreenCover will overlay camera
                            onUpload()
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 28, weight: .regular))
                                            .foregroundColor(.white)
                                    )
                                Text("Upload")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: geometry.size.width / 2)

                        // Manual entry button (centered in right half)
                        Button(action: {
                            isPresented = false
                            onManualEntry()
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "list.bullet.clipboard")
                                            .font(.system(size: 28, weight: .regular))
                                            .foregroundColor(.white)
                                    )
                                Text("Manual")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: geometry.size.width / 2)
                    }
                }
                .frame(height: 90)
                .padding(.bottom, 40)
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - Custom Camera View with AVFoundation
import AVFoundation

struct CameraCaptureView: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    let onImageCaptured: () -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CameraPreviewDelegate {
        let parent: CameraCaptureView

        init(_ parent: CameraCaptureView) {
            self.parent = parent
            super.init()

            // Listen for take photo notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(takePhoto),
                name: NSNotification.Name("TakePhoto"),
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func takePhoto() {
            // Will be called by the camera preview
        }

        func didCapturePhoto(_ image: UIImage) {
            parent.capturedImage = image
            DispatchQueue.main.async {
                self.parent.onImageCaptured()
            }
        }
    }
}

// MARK: - Camera Preview Delegate
protocol CameraPreviewDelegate: AnyObject {
    func didCapturePhoto(_ image: UIImage)
}

// MARK: - Camera Preview View
class CameraPreviewView: UIView {
    weak var delegate: CameraPreviewDelegate?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentPhotoSettings: AVCapturePhotoSettings?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()

        // Listen for capture trigger
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturePhoto),
            name: NSNotification.Name("TakePhoto"),
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("❌ Failed to access camera")
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    @objc func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        currentPhotoSettings = settings

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate
extension CameraPreviewView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to convert photo to image")
            return
        }

        delegate?.didCapturePhoto(image)
    }
}

// MARK: - Image Preview View
struct ImagePreview: View {
    let image: UIImage
    let onRetake: () -> Void
    let onConfirm: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    private let containerHeight: CGFloat = 400
    private let maxScale: CGFloat = 5.0

    var body: some View {
        VStack(spacing: 24) {
            // Image viewer with constrained zoom/pan
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .cornerRadius(.cornerRadiusButton)

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    let imageSize = getImageSize(for: image, in: geometry.size)
                                    offset = constrainOffset(
                                        offset: newOffset,
                                        scale: scale,
                                        imageSize: imageSize,
                                        containerSize: geometry.size
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusButton))
            }
            .frame(height: containerHeight)
            .padding(.horizontal)
            
            // Enhanced instructions
            VStack(spacing: 4) {
                Text("Double tap to reset • Pinch to zoom • Drag to pan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Position the receipt for best OCR accuracy")
                    .font(.caption2)
                    .foregroundColor(.adaptiveAccentBlue)
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button(action: onRetake) {
                    HStack {
                        Image(systemName: "camera.rotate")
                        Text("Retake")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: {
                    // Capture the current view state as an image
                    let finalImage = captureImageWithCurrentTransform()
                    onConfirm(finalImage)
                }) {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text("Continue")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.adaptiveDepth0)
    }
    
    // Helper functions for constrained image viewing
    private func getImageSize(for image: UIImage, in containerSize: CGSize) -> CGSize {
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        let width: CGFloat
        let height: CGFloat
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container - fit to width
            width = containerSize.width
            height = width / imageAspectRatio
        } else {
            // Image is taller than container - fit to height
            height = containerSize.height
            width = height * imageAspectRatio
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func constrainOffset(
        offset: CGSize,
        scale: CGFloat,
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGSize {
        // Calculate the scaled image size
        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        // Calculate maximum allowed offset to prevent empty space
        let maxOffsetX = max(0, (scaledImageSize.width - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledImageSize.height - containerSize.height) / 2)
        
        // Constrain the offset
        let constrainedX = min(maxOffsetX, max(-maxOffsetX, offset.width))
        let constrainedY = min(maxOffsetY, max(-maxOffsetY, offset.height))
        
        return CGSize(width: constrainedX, height: constrainedY)
    }
    
    private func captureImageWithCurrentTransform() -> UIImage {
        // If no significant transformation was applied, return original image
        if abs(scale - 1.0) < 0.1 && abs(offset.width) < 10 && abs(offset.height) < 10 {
            return image
        }
        
        // Use the container size (400 height) that the app provides instead of original image aspect ratio
        let containerSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 400) // Matching the frame in the UI
        
        // Create a renderer with the container size (not the original image size)
        let renderer = UIGraphicsImageRenderer(size: containerSize)
        
        return renderer.image { context in
            // Fill the container background
            context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: containerSize))
            
            // Calculate how the image fits in the container (aspect fill)
            let imageSize = getImageSize(for: image, in: containerSize)
            let imageRect = CGRect(
                x: (containerSize.width - imageSize.width) / 2,
                y: (containerSize.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
            // Apply user transformations
            context.cgContext.saveGState()
            
            // Translate to center, apply scale and offset, then translate back
            context.cgContext.translateBy(x: containerSize.width / 2, y: containerSize.height / 2)
            context.cgContext.scaleBy(x: scale, y: scale)
            context.cgContext.translateBy(x: offset.width, y: offset.height)
            context.cgContext.translateBy(x: -containerSize.width / 2, y: -containerSize.height / 2)
            
            // Draw the image in the calculated rect
            image.draw(in: imageRect)
            
            context.cgContext.restoreGState()
        }
    }
}

// MARK: - Interactive Image View (Photos app-like)
struct InteractiveImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = UIImageView(image: image)
        
        // Configure scroll view
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = UIColor.clear
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // Configure image view
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        
        // Add double tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)
        
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.updateImageLayout()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: InteractiveImageView
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        
        init(_ parent: InteractiveImageView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView()
        }
        
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Optional: Add haptic feedback
            if scale == scrollView.minimumZoomScale {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            
            if scrollView.zoomScale == scrollView.minimumZoomScale {
                // Zoom in to 2x at tap location
                let tapLocation = gesture.location(in: imageView)
                let zoomRect = zoomRectForScale(2.0, center: tapLocation)
                scrollView.zoom(to: zoomRect, animated: true)
            } else {
                // Zoom out to fit
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            }
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
        
        func updateImageLayout() {
            guard let scrollView = scrollView,
                  let imageView = imageView,
                  scrollView.bounds.size.width > 0,
                  scrollView.bounds.size.height > 0 else { return }
            
            // Calculate image size to fit scroll view
            let scrollViewSize = scrollView.bounds.size
            let imageSize = parent.image.size
            
            guard imageSize.width > 0 && imageSize.height > 0 else { return }
            
            let widthScale = scrollViewSize.width / imageSize.width
            let heightScale = scrollViewSize.height / imageSize.height
            let scale = min(widthScale, heightScale)
            
            let imageViewSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )
            
            imageView.frame = CGRect(origin: .zero, size: imageViewSize)
            scrollView.contentSize = imageViewSize
            
            // Center the image
            centerImageView()
            
            // Reset zoom
            scrollView.zoomScale = 1.0
        }
        
        private func centerImageView() {
            guard let scrollView = scrollView,
                  let imageView = imageView else { return }
            
            let scrollViewSize = scrollView.bounds.size
            let imageViewSize = imageView.frame.size
            
            let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
            let verticalInset = max(0, (scrollViewSize.height - imageViewSize.height) / 2)
            
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
        
        private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
            guard let scrollView = scrollView else { return .zero }
            
            let zoomSize = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )
            
            return CGRect(
                x: center.x - zoomSize.width / 2,
                y: center.y - zoomSize.height / 2,
                width: zoomSize.width,
                height: zoomSize.height
            )
        }
    }
}

// MARK: - Permission Alert Extension
extension View {
    func permissionAlert(isPresented: Binding<Bool>, message: String) -> some View {
        self.alert("Permission Required", isPresented: isPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text(message)
        }
    }
}

// MARK: - Refactored UIScanScreen with Design System
struct UIScanScreen: View {
    let session: BillSplitSession
    let onContinue: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var scanComplete = false
    @State private var scanningStatus = ""
    @State private var capturedImage: UIImage?
    @State private var showingImagePreview = false
    @State private var showingCamera = true  // Auto-open camera when Add tab is tapped
    @State private var showingPhotoLibrary = false
    @State private var showingOCRResults = false
    @State private var ocrResult: OCRResult?
    @StateObject private var permissionManager = CameraPermissionManager()
    @StateObject private var ocrService = OCRService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if showingCamera {
                // Add screen = Camera with 4 buttons
                CameraCaptureWithOverlay(
                    isPresented: $showingCamera,
                    capturedImage: $capturedImage,
                    onImageCaptured: handleImageCaptured,
                    onUpload: handlePhotoLibrary,
                    onManualEntry: handleManualEntry,
                    onCancel: {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                )
                .ignoresSafeArea()
            } else if showingPhotoLibrary {
                // Gallery screen - replaces Add screen completely
                CameraCapture(
                    isPresented: $showingPhotoLibrary,
                    capturedImage: $capturedImage,
                    sourceType: .photoLibrary
                )
                .ignoresSafeArea()
                .onDisappear {
                    if capturedImage != nil {
                        handleImageCaptured()
                    } else {
                        // User cancelled, return to Add screen
                        showingCamera = true
                    }
                }
            } else if showingOCRResults, let result = ocrResult {
                // OCR confirmation screen (Confirm Receipt Details)
                ocrConfirmationView(result: result)
                    .background(Color.adaptiveDepth0.ignoresSafeArea())
            } else if showingImagePreview, let image = capturedImage {
                // Image preview screen (with zoom/pan)
                VStack(spacing: .spacingLG) {
                    // Header
                    Text("Scan Receipt")
                        .font(.h3Dynamic)
                        .foregroundColor(.adaptiveTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, .paddingScreen)
                        .padding(.top, .spacingMD)

                    // Image preview with zoom/pan
                    imagePreviewView(image: image)
                }
                .background(Color.adaptiveDepth0.ignoresSafeArea())
            } else if ocrService.isProcessing {
                // Processing screen
                processingView
                    .background(Color.adaptiveDepth0.ignoresSafeArea())
            }
        }
        .permissionAlert(
            isPresented: $permissionManager.showPermissionAlert,
            message: permissionManager.permissionMessage
        )
        .onAppear(perform: checkPermissions)
    }

    // MARK: - View Components

    private func ocrConfirmationView(result: OCRResult) -> some View {
        OCRConfirmationView(
            result: result,
            image: capturedImage,
            onConfirm: { confirmedData in
                Task {
                    await processWithConfirmedData(result: result, confirmedData: confirmedData)
                }
            },
            onRetry: handleRetryOCR,
            onBack: handleBackToImageAdjustment
        )
    }

    private func handleBackToImageAdjustment() {
        showingOCRResults = false
        ocrResult = nil
        showingImagePreview = true
    }

    private func imagePreviewView(image: UIImage) -> some View {
        ImagePreview(
            image: image,
            onRetake: handleRetakePhoto,
            onConfirm: handleImageConfirmed
        )
    }

    private var processingView: some View {
        OCRProcessingView(
            progress: ocrService.progress,
            status: scanningStatus
        )
    }

    private var scanInputView: some View {
        VStack(spacing: 16) {
            ScanInputSection(
                scanningStatus: scanningStatus,
                onScan: handleScanReceipt,
                onUpload: handlePhotoLibrary,
                onManualEntry: handleManualEntry
            )
        }
    }

    // MARK: - Helper Methods

    private func checkPermissions() {
        permissionManager.checkCameraPermission()
        permissionManager.checkPhotoLibraryPermission()
    }

    private func performDebugTest() {
        scanningStatus = "Testing comprehensive item detection..."
        Task {
            let result = await ocrService.testParsing()
            await MainActor.run {
                self.ocrResult = result
                self.showingOCRResults = true
                self.scanningStatus = ""
            }
        }
    }
    
    private func handleScanReceipt() {
        // Check camera permission before proceeding
        switch permissionManager.cameraPermissionStatus {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            permissionManager.requestCameraPermission()
            // Wait for permission result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if permissionManager.cameraPermissionStatus == .authorized {
                    showingCamera = true
                }
            }
        case .denied, .restricted:
            permissionManager.showPermissionAlert = true
        @unknown default:
            permissionManager.showPermissionAlert = true
        }
    }
    
    private func handlePhotoLibrary() {
        // Check permission and show gallery (which replaces camera)
        switch permissionManager.photoLibraryPermissionStatus {
        case .authorized, .limited:
            showingCamera = false
            showingPhotoLibrary = true
        case .notDetermined:
            permissionManager.requestPhotoLibraryPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.permissionManager.canUsePhotoLibrary {
                    self.showingCamera = false
                    self.showingPhotoLibrary = true
                }
            }
        case .denied, .restricted:
            permissionManager.showPermissionAlert = true
        @unknown default:
            permissionManager.showPermissionAlert = true
        }
    }

    private func handleManualEntry() {
        print("🟢 [ScanView] handleManualEntry called")

        // Dismiss camera if showing
        if showingCamera {
            showingCamera = false
        }

        // Clear any existing scanning status to prevent loading spinner
        scanningStatus = ""

        // Set entry method to manual
        session.entryMethod = .manual
        print("🟢 [ScanView] Set entryMethod to: \(session.entryMethod)")

        // Initialize with empty items - user will add them in AssignScreen
        session.assignedItems = []

        // Set minimal required values for session
        session.confirmedTotal = 0.0
        session.confirmedTax = 0.0
        session.confirmedTip = 0.0

        print("🟢 [ScanView] Session configured for manual entry - navigating to AssignScreen")

        // Auto-save session
        session.autoSaveSession()

        // Navigate directly to AssignScreen
        onContinue()
    }

    private func handleImageCaptured() {
        // Dismiss camera and show image preview
        showingCamera = false
        showingImagePreview = true
    }
    
    private func handleImageConfirmed(_ finalImage: UIImage) {
        showingImagePreview = false
        
        // Update capturedImage to use the cropped/transformed version
        capturedImage = finalImage
        
        // Start OCR processing
        scanningStatus = "Processing image with OCR..."
        
        Task {
            let result = await ocrService.processImage(finalImage)
            
            await MainActor.run {
                self.ocrResult = result
                self.showingOCRResults = true
                self.scanningStatus = ""
            }
        }
    }
    
    private func handleRetakePhoto() {
        capturedImage = nil
        showingImagePreview = false
        showingCamera = true
    }
    
    private func handleRetryOCR() {
        showingOCRResults = false
        ocrResult = nil
        showingImagePreview = false
        capturedImage = nil
        scanningStatus = ""
    }

    private func processWithConfirmedData(result: OCRResult, confirmedData: ConfirmedReceiptData) async {
        print("🎯 processWithConfirmedData: Building bill from classified receipt")

        // Use classified receipt data if available (from Gemini or legacy classifier)
        let processedItems: [ReceiptItem]
        var actualTax = confirmedData.tax
        var actualTip = confirmedData.tip
        var gratuity: Double = 0.0

        if let classifiedReceipt = result.classifiedReceipt {
            print("✅ Using classified receipt with \(classifiedReceipt.foodItems.count) food items")

            // Convert ClassifiedReceiptItem to ReceiptItem for bill creation
            processedItems = classifiedReceipt.foodItems.map { classifiedItem in
                ReceiptItem(
                    name: classifiedItem.name,
                    price: classifiedItem.price,
                    confidence: .high,
                    originalDetectedName: classifiedItem.originalText,
                    originalDetectedPrice: classifiedItem.price
                )
            }

            // Extract tax, tip, and gratuity from classified receipt
            actualTax = classifiedReceipt.tax?.price ?? confirmedData.tax
            actualTip = classifiedReceipt.tip?.price ?? confirmedData.tip
            gratuity = classifiedReceipt.gratuity?.price ?? 0.0

            print("📝 Bill items created:")
            for (index, item) in processedItems.enumerated() {
                print("   [\(index+1)] \(item.name) - $\(String(format: "%.2f", item.price))")
            }

            print("💰 Bill summary:")
            print("   Subtotal: $\(String(format: "%.2f", classifiedReceipt.subtotal?.price ?? 0))")
            print("   Tax: $\(String(format: "%.2f", actualTax))")
            print("   Tip: $\(String(format: "%.2f", actualTip))")
            if gratuity > 0 {
                print("   Gratuity: $\(String(format: "%.2f", gratuity)) ⭐")
            }
            print("   Total: $\(String(format: "%.2f", confirmedData.total))")

        } else {
            print("⚠️ No classified receipt available, falling back to mathematical approach")
            // Fallback to mathematical approach if classification failed
            let ocrService = OCRService()
            processedItems = await ocrService.processWithMathematicalApproach(
                rawText: result.rawText,
                confirmedTax: confirmedData.tax,
                confirmedTip: confirmedData.tip,
                confirmedTotal: confirmedData.total,
                expectedItemCount: confirmedData.itemCount
            )
        }

        await MainActor.run {
            // Combine manual tip with auto-gratuity for total tip amount
            let totalTip = actualTip + gratuity

            // Set entry method to scan for scan-based flow
            session.entryMethod = .scan
            print("🟢 [ScanView] Set entryMethod to: \(session.entryMethod)")

            session.updateOCRResults(
                processedItems,
                rawText: result.rawText,
                confidence: result.confidence,
                identifiedTotal: confirmedData.total,
                suggestedAmounts: [],
                image: capturedImage,
                confirmedTax: actualTax,
                confirmedTip: totalTip,  // Combined tip + gratuity
                confirmedTotal: confirmedData.total,
                expectedItemCount: confirmedData.itemCount
            )

            print("✅ Session updated with \(processedItems.count) items, tax: $\(String(format: "%.2f", actualTax)), tip: $\(String(format: "%.2f", totalTip)) (includes $\(String(format: "%.2f", gratuity)) gratuity)")

            // Auto-save session after OCR completion
            session.autoSaveSession()

            onContinue()
        }
    }
    
}

// MARK: - Supporting Views (Refactored with Design System)

struct ScanInputSection: View {
    let scanningStatus: String
    let onScan: () -> Void
    let onUpload: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: .spacingLG) {
            // Modern camera area with clean design
            ZStack {
                // Solid background with depth
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .fill(Color.adaptiveDepth1)
                    .frame(height: 450)

                // Subtle border
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .stroke(Color.adaptiveTextPrimary.opacity(0.08), lineWidth: 1)
                    .frame(height: 450)

                // Content overlay
                VStack(spacing: .spacingLG) {
                    if scanningStatus.isEmpty {
                        CameraInputView(onScan: onScan, onUpload: onUpload, onManualEntry: onManualEntry)
                    } else {
                        ScanningProgressView(status: scanningStatus)
                    }
                }
                .padding(.spacingLG)
            }
            .padding(.horizontal, .paddingScreen)
        }
    }
}

// MARK: - Refactored CameraInputView with Design System
struct CameraInputView: View {
    let onScan: () -> Void
    let onUpload: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: .spacingLG) {
            Image(systemName: "camera")
                .font(.system(size: 60))
                .foregroundColor(.adaptiveTextSecondary)

            Text("Take a photo of your receipt, upload from gallery, or enter manually")
                .font(.bodyDynamic)
                .multilineTextAlignment(.center)
                .foregroundColor(.adaptiveTextSecondary)
                .padding(.horizontal, .spacingLG)

            VStack(spacing: .spacingMD) {
                // Primary action: Take Photo - Modern button design
                Button(action: onScan) {
                    HStack(spacing: .spacingSM) {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                // Secondary action: Upload from Gallery - Clean secondary style
                Button(action: onUpload) {
                    HStack(spacing: .spacingSM) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Upload from Gallery")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                // Tertiary action: Manual Entry
                Button(action: onManualEntry) {
                    HStack(spacing: .spacingSM) {
                        Image(systemName: "square.and.pencil")
                        Text("Enter Manually")
                    }
                }
                .buttonStyle(TertiaryButtonStyle())
            }
            .padding(.horizontal, .spacingLG)
        }
    }
}

// MARK: - Refactored ScanningProgressView with Design System
struct ScanningProgressView: View {
    let status: String

    var body: some View {
        VStack(spacing: .spacingMD) {
            ProgressView()
                .scaleEffect(2)
                .padding(.spacingMD)

            Text(status == "scanning" ? "Scanning receipt..." : "Processing items...")
                .font(.bodyDynamic)
                .foregroundColor(.adaptiveTextSecondary)
        }
    }
}

struct ReceiptResultSection: View {
    let mockReceiptItems: [(String, Double)]
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            SuccessMessageView()
            ReceiptItemsView(items: mockReceiptItems)
            
            Button(action: onContinue) {
                HStack {
                    Text("Continue to Assign Items")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
        }
    }
}

struct SuccessMessageView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Receipt Scanned Successfully!")
                .fontWeight(.medium)
                .foregroundColor(.adaptiveAccentGreen)
            
            Text("We've identified the following items:")
                .font(.caption)
                .foregroundColor(.adaptiveAccentGreen)
        }
        .padding()
        .background(Color.adaptiveAccentGreen.opacity(0.1))
        .cornerRadius(.cornerRadiusButton)
        .padding(.horizontal)
    }
}

struct ReceiptItemsView: View {
    let items: [(String, Double)]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                    Spacer()
                    Text("$\(item.1, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.adaptiveDepth1)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.adaptiveTextTertiary.opacity(0.3)),
                    alignment: .bottom
                )
            }
            
            ReceiptTotalSection()
        }
        .cornerRadius(.cornerRadiusButton)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusButton)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct ReceiptTotalSection: View {
    var body: some View {
        VStack(spacing: 0) {
            ReceiptTotalRow(label: "Subtotal", amount: "$44.15")
            ReceiptTotalRow(label: "Tax", amount: "$3.53")
            ReceiptTotalRow(label: "Tip (18%)", amount: "$7.95")
            
            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text("$55.63")
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color.adaptiveDepth1)
        }
    }
}

struct ReceiptTotalRow: View {
    let label: String
    let amount: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.adaptiveDepth1.opacity(0.5))
    }
}

// MARK: - OCR Processing View
struct OCRProcessingView: View {
    let progress: Float
    let status: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                // OCR Icon with animation
                ZStack {
                    Circle()
                        .stroke(Color.adaptiveAccentBlue.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.adaptiveAccentBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.adaptiveAccentBlue)
                }

                VStack(spacing: 8) {
                    Text("Processing Receipt")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(status.isEmpty ? "Extracting text from image..." : status)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, .paddingScreen)
                }

                // Progress indicator
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(maxWidth: 200)

                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, .paddingScreen)

            Spacer()

            // Processing tips
            VStack(alignment: .leading, spacing: 8) {
                Text("OCR Processing Tips:")
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveAccentBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Better lighting improves text recognition")
                    Text("• Clear, uncrumpled receipts work best")
                    Text("• Processing may take a few seconds")
                }
                .font(.caption)
                .foregroundColor(.adaptiveAccentBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.adaptiveAccentBlue.opacity(0.1))
            .cornerRadius(.cornerRadiusButton)
            .padding(.horizontal, .paddingScreen)

            Spacer()
        }
    }
}

// MARK: - OCR Results View
struct OCRResultsView: View {
    @State private var items: [ReceiptItem]
    let rawText: String
    let confidence: Float
    let identifiedTotal: Double?
    let suggestedAmounts: [Double]
    let onContinue: ([ReceiptItem]) -> Void
    let onRetry: () -> Void
    
    @State private var showRawText = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with confidence indicator
            OCRHeaderView(
                confidence: confidence,
                itemCount: items.count,
                showRawText: $showRawText
            )
            
            if items.isEmpty {
                // No items found - show manual entry option
                OCREmptyStateView(
                    identifiedTotal: identifiedTotal,
                    suggestedAmounts: suggestedAmounts,
                    onRetry: onRetry
                )
            } else {
                // Items found - show editable list
                OCRItemListView(
                    items: $items,
                    identifiedTotal: identifiedTotal,
                    suggestedAmounts: suggestedAmounts,
                    onContinue: { onContinue(items) }
                )
            }
        }
        .onAppear {
            // Debug info
            if items.isEmpty {
            } else {
                for (index, item) in items.enumerated() {
                }
            }
        }
        .sheet(isPresented: $showRawText) {
            RawTextView(text: rawText)
        }
    }
}

// MARK: - OCR Header View
struct OCRHeaderView: View {
    let confidence: Float
    let itemCount: Int
    @Binding var showRawText: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan Results")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(itemCount) items found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    ConfidenceIndicator(confidence: confidence)
                    
                    Button("View Raw Text") {
                        showRawText = true
                    }
                    .font(.caption)
                    .foregroundColor(.adaptiveAccentBlue)
                }
            }
            .padding()
            
            Divider()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Confidence Indicator
struct ConfidenceIndicator: View {
    let confidence: Float
    
    var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    var confidenceText: String {
        switch confidence {
        case 0.8...1.0: return "High"
        case 0.5..<0.8: return "Medium"
        default: return "Low"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text("\(confidenceText) Confidence")
                .font(.caption)
                .foregroundColor(confidenceColor)
        }
    }
}

// MARK: - OCR Item List View
struct OCRItemListView: View {
    @Binding var items: [ReceiptItem]
    let identifiedTotal: Double?
    let suggestedAmounts: [Double]
    let onContinue: () -> Void
    
    var totalAmount: Double {
        let total = items.reduce(0) { $0.currencyAdd($1.price) }
        for (index, item) in items.enumerated() {
        }
        return total
    }
    
    var totalValidationColor: Color {
        guard let detectedTotal = identifiedTotal else { return .blue }
        let difference = abs(totalAmount - detectedTotal)
        return difference <= 0.01 ? .green : .orange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Found \(items.count) items! Tap any item to edit its name or price.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            List {
                ForEach(items.indices, id: \.self) { index in
                    EditableItemRow(
                        item: $items[index],
                        onDelete: {
                            items.remove(at: index)
                        }
                    )
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(PlainListStyle())
            
            VStack(spacing: 16) {
                // Total comparison section
                VStack(spacing: 8) {
                    HStack {
                        Text("Items Total")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("$\(totalAmount, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(totalValidationColor)
                    }
                    
                    // Show comparison with detected total if available
                    if let detectedTotal = identifiedTotal {
                        HStack {
                            Text("Receipt Total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("$\(detectedTotal, specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show difference and balance remaining
                        let difference = totalAmount - detectedTotal
                        if abs(difference) > 0.01 {
                            if difference < 0 {
                                // Need to add more items
                                HStack {
                                    Text("Remaining to add")
                                        .font(.caption)
                                        .foregroundColor(.adaptiveAccentBlue)
                                    
                                    Spacer()
                                    
                                    Text("$\(abs(difference), specifier: "%.2f")")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.adaptiveAccentBlue)
                                }
                            } else {
                                // Total exceeds receipt total
                                HStack {
                                    Text("Over by")
                                        .font(.caption)
                                        .foregroundColor(.adaptiveAccentOrange)
                                    
                                    Spacer()
                                    
                                    Text("$\(difference, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.adaptiveAccentOrange)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.adaptiveAccentGreen)
                                Text("Totals match!")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveAccentGreen)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Button(action: onContinue) {
                    HStack {
                        Text("Continue to Split")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .disabled(items.isEmpty)
            }
            .padding(.vertical)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

// MARK: - Editable Item Row
struct EditableItemRow: View {
    @Binding var item: ReceiptItem
    let onDelete: () -> Void
    
    @State private var isEditingName = false
    @State private var isEditingPrice = false
    @State private var editName = ""
    @State private var editPrice = ""
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isPriceFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Item name section
            VStack(alignment: .leading, spacing: 4) {
                if isEditingName {
                    TextField("Item name", text: $editName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            saveNameEdit()
                        }
                } else {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(2)
                        .onTapGesture {
                            startNameEditing()
                        }
                    
                    Text("Tap name to edit")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Price section
            VStack(alignment: .trailing, spacing: 4) {
                if isEditingPrice {
                    HStack {
                        Text("$")
                            .font(.body)
                        TextField("0.00", text: $editPrice)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .focused($isPriceFieldFocused)
                            .onSubmit {
                                savePriceEdit()
                            }
                    }
                } else {
                    Text("$\(item.price, specifier: "%.2f")")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.adaptiveAccentBlue)
                        .onTapGesture {
                            startPriceEditing()
                        }
                    
                    Text("Tap price to edit")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        // Dismiss editing when tapping outside
        .onTapGesture {
            if isEditingName {
                saveNameEdit()
            }
            if isEditingPrice {
                savePriceEdit()
            }
        }
    }
    
    private func startNameEditing() {
        editName = item.name
        isEditingName = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }
    
    private func startPriceEditing() {
        editPrice = String(format: "%.2f", item.price)
        isEditingPrice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPriceFieldFocused = true
        }
    }
    
    private func saveNameEdit() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            item.name = trimmedName
        }
        isEditingName = false
        isNameFieldFocused = false
    }
    
    private func savePriceEdit() {
        if let price = Double(editPrice), price > 0 {
            item.price = price
        }
        isEditingPrice = false
        isPriceFieldFocused = false
    }
}

// MARK: - OCR Empty State View
struct OCREmptyStateView: View {
    let identifiedTotal: Double?
    let suggestedAmounts: [Double]
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Show success if we found a total
            if let total = identifiedTotal {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.adaptiveAccentGreen)
                    
                    VStack(spacing: 8) {
                        Text("Total Found: $\(total, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveAccentGreen)
                        
                        Text("Now add items manually to split the bill")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Show suggested amounts if available
                    if !suggestedAmounts.isEmpty {
                        VStack(spacing: 8) {
                            Text("Suggested amounts found:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveAccentBlue)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(suggestedAmounts.count, 4)), spacing: 8) {
                                ForEach(suggestedAmounts.prefix(8), id: \.self) { amount in
                                    Text("$\(amount, specifier: "%.2f")")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.adaptiveAccentBlue.opacity(0.1))
                                        .foregroundColor(.adaptiveAccentBlue)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(Color.adaptiveAccentBlue.opacity(0.05))
                        .cornerRadius(.cornerRadiusButton)
                        .padding(.horizontal)
                    }
                }
            } else {
                // Show failure state
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 12) {
                        Text("No Items Detected")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("The OCR couldn't identify any items from the receipt. You can try taking another photo or add items manually.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            
            VStack(spacing: 12) {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "camera.rotate")
                        Text("Try Another Photo")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.adaptiveAccentBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.adaptiveAccentBlue.opacity(0.1))
                    .cornerRadius(.cornerRadiusButton)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Raw Text View
struct RawTextView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(text.isEmpty ? "No text was detected from the image." : text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Raw OCR Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Confirmation Data Structure
struct ConfirmedReceiptData {
    let tax: Double
    let tip: Double
    let total: Double
    let itemCount: Int
}

// MARK: - OCR Confirmation View
struct OCRConfirmationView: View {
    let result: OCRResult
    let image: UIImage?
    let onConfirm: (ConfirmedReceiptData) -> Void
    let onRetry: () -> Void
    let onBack: () -> Void
    
    @State private var taxInput = ""
    @State private var tipInput = ""
    @State private var totalInput = ""
    @State private var itemCountInput = ""
    
    @State private var detectedTax: Double = 0.0
    @State private var detectedTip: Double = 0.0
    @State private var detectedTotal: Double = 0.0
    @State private var detectedItemCount: Int = 0
    
    @State private var isLoading = true
    @State private var showingImagePopup = false
    @FocusState private var focusedField: ConfirmationField?
    
    enum ConfirmationField {
        case tax, tip, total, itemCount
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Back button
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .regular))
                        }
                        .foregroundColor(.adaptiveAccentBlue)
                    }

                    Spacer()
                }
                .padding(.horizontal, .paddingScreen)
                .padding(.top, 8)

                // Header with image preview - Option A: Icon + Compact Layout
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Confirm Receipt Details")
                            .font(.h3Dynamic)
                            .foregroundColor(.adaptiveTextPrimary)

                        HStack(spacing: 8) {
                            Text("Review the detected values below")
                                .font(.system(size: 15))
                                .foregroundColor(.adaptiveTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Image preview thumbnail
                    if let image = image {
                        Button(action: {
                            showingImagePopup = true
                        }) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.adaptiveAccentBlue, lineWidth: 2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, .paddingScreen)
                .padding(.bottom, .spacingMD)  // Add 16px for 40px total spacing to form

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing receipt data...")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                } else {
                    // Bill Details Form - Clean layout without container
                    VStack(spacing: 16) {
                        // Number of Items Field
                        HStack(spacing: 12) {
                            // Label on left
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Number of Items")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.adaptiveTextPrimary)
                                        .lineLimit(1)
                                    Text("*")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.adaptiveAccentRed)
                                }
                                if detectedItemCount > 0 {
                                    Text("Detected: \(detectedItemCount) items")
                                        .font(.system(size: 12))
                                        .foregroundColor(.adaptiveAccentGreen)
                                }
                            }

                            Spacer()

                            // Input field on right
                            TextField("0", text: $itemCountInput)
                                .keyboardType(.numberPad)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.adaptiveTextPrimary)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .itemCount)
                                .frame(width: 140)
                                .padding(.spacingMD)
                                .background(
                                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                        .fill(Color.adaptiveDepth3)
                                        .shadow(color: focusedField == .itemCount ? Color.adaptiveAccentBlue.opacity(0.3) : Color.black.opacity(0.08), radius: focusedField == .itemCount ? 10 : 8, x: 0, y: focusedField == .itemCount ? 4 : 3)
                                        .shadow(color: focusedField == .itemCount ? Color.adaptiveAccentBlue.opacity(0.15) : Color.black.opacity(0.04), radius: focusedField == .itemCount ? 4 : 2, x: 0, y: 1)
                                )
                                .animation(.easeOut(duration: 0.2), value: focusedField == .itemCount)
                        }

                        // Tax Amount Field
                        HStack(spacing: 12) {
                            // Label on left
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Tax")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.adaptiveTextPrimary)
                                if detectedTax > 0 {
                                    Text("Detected: $\(detectedTax, specifier: "%.2f")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.adaptiveAccentGreen)
                                }
                            }

                            Spacer()

                            // Input field on right
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.adaptiveTextSecondary)
                                TextField("0.00", text: $taxInput)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.adaptiveTextPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedField, equals: .tax)
                            }
                            .frame(width: 140)
                            .padding(.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                    .fill(Color.adaptiveDepth3)
                                    .shadow(color: focusedField == .tax ? Color.adaptiveAccentBlue.opacity(0.3) : Color.black.opacity(0.08), radius: focusedField == .tax ? 10 : 8, x: 0, y: focusedField == .tax ? 4 : 3)
                                    .shadow(color: focusedField == .tax ? Color.adaptiveAccentBlue.opacity(0.15) : Color.black.opacity(0.04), radius: focusedField == .tax ? 4 : 2, x: 0, y: 1)
                            )
                            .animation(.easeOut(duration: 0.2), value: focusedField == .tax)
                        }

                        // Tip Amount Field
                        HStack(spacing: 12) {
                            // Label on left
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Tip")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.adaptiveTextPrimary)
                                if detectedTip > 0 {
                                    Text("Detected: $\(detectedTip, specifier: "%.2f")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.adaptiveAccentGreen)
                                }
                            }

                            Spacer()

                            // Input field on right
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.adaptiveTextSecondary)
                                TextField("0.00", text: $tipInput)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.adaptiveTextPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedField, equals: .tip)
                            }
                            .frame(width: 140)
                            .padding(.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                    .fill(Color.adaptiveDepth3)
                                    .shadow(color: focusedField == .tip ? Color.adaptiveAccentBlue.opacity(0.3) : Color.black.opacity(0.08), radius: focusedField == .tip ? 10 : 8, x: 0, y: focusedField == .tip ? 4 : 3)
                                    .shadow(color: focusedField == .tip ? Color.adaptiveAccentBlue.opacity(0.15) : Color.black.opacity(0.04), radius: focusedField == .tip ? 4 : 2, x: 0, y: 1)
                            )
                            .animation(.easeOut(duration: 0.2), value: focusedField == .tip)
                        }

                        // Elegant divider before Total Amount
                        Rectangle()
                            .fill(Color.adaptiveTextPrimary.opacity(0.15))
                            .frame(height: 1)
                            .padding(.vertical, 8)

                        // Total Amount Field - Same styling as others
                        HStack(spacing: 12) {
                            // Label on left
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Total Amount")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.adaptiveTextPrimary)
                                        .lineLimit(1)
                                    Text("*")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.adaptiveAccentRed)
                                }
                                if detectedTotal > 0 {
                                    Text("Detected: $\(detectedTotal, specifier: "%.2f")")
                                        .font(.system(size: 12))
                                        .foregroundColor(.adaptiveAccentGreen)
                                }
                            }

                            Spacer()

                            // Input field on right - same size as others
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.adaptiveTextPrimary)
                                TextField("0.00", text: $totalInput)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.adaptiveTextPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focusedField, equals: .total)
                            }
                            .frame(width: 140)
                            .padding(.spacingMD)
                            .background(
                                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                    .fill(Color.adaptiveDepth3)
                                    .shadow(color: focusedField == .total ? Color.adaptiveAccentGreen.opacity(0.3) : Color.black.opacity(0.08), radius: focusedField == .total ? 10 : 8, x: 0, y: focusedField == .total ? 4 : 3)
                                    .shadow(color: focusedField == .total ? Color.adaptiveAccentGreen.opacity(0.15) : Color.black.opacity(0.04), radius: focusedField == .total ? 4 : 2, x: 0, y: 1)
                            )
                            .animation(.easeOut(duration: 0.2), value: focusedField == .total)
                        }
                    }
                    .padding(.horizontal, .paddingScreen)
                    .padding(.bottom, .spacingMD)  // Add 16px for 40px total spacing to buttons
                }

                // Action button
                if canConfirm {
                    Button(action: handleConfirm) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Continue")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                } else {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Continue")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .background(Color.adaptiveDepth0)
        .task {
            await analyzeReceiptData()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .foregroundColor(.adaptiveAccentBlue)
            }
        }
        .fullScreenCover(isPresented: $showingImagePopup) {
            if let image = image {
                ImagePopupView(image: image) {
                    showingImagePopup = false
                }
            }
        }
    }
    
    private var canConfirm: Bool {
        let total = Double(totalInput) ?? 0
        let itemCount = Int(itemCountInput) ?? 0
        return total > 0 && itemCount > 0
    }
    
    private func analyzeReceiptData() async {
        await MainActor.run {
            // Use classified receipt data if available (from Gemini or legacy classifier)
            if let classifiedReceipt = result.classifiedReceipt {
                // Extract values from classified receipt
                detectedTax = classifiedReceipt.tax?.price ?? 0.0

                // ✅ FIX: Combine tip + gratuity for display
                let manualTip = classifiedReceipt.tip?.price ?? 0.0
                let autoGratuity = classifiedReceipt.gratuity?.price ?? 0.0
                detectedTip = manualTip + autoGratuity

                detectedTotal = classifiedReceipt.total?.price ?? 0.0
                detectedItemCount = classifiedReceipt.foodItems.count

                print("📊 UI: Using classified receipt data:")
                print("   Food items: \(classifiedReceipt.foodItems.count)")
                print("   Tax: $\(String(format: "%.2f", detectedTax))")
                print("   Tip: $\(String(format: "%.2f", manualTip))")
                if autoGratuity > 0 {
                    print("   Gratuity: $\(String(format: "%.2f", autoGratuity)) ⭐")
                    print("   Total Tip (Tip + Gratuity): $\(String(format: "%.2f", detectedTip))")
                }
                print("   Total: $\(String(format: "%.2f", detectedTotal))")
            } else {
                // Fallback to simple text analysis if classification failed
                print("⚠️ UI: No classified receipt available, using fallback analysis")
                let ocrService = OCRService()

                Task {
                    let analysis = await ocrService.analyzeReceiptForConfirmation(text: result.rawText)

                    await MainActor.run {
                        detectedTax = analysis.tax
                        detectedTip = analysis.tip
                        detectedTotal = analysis.total
                        detectedItemCount = analysis.itemCount

                        // Pre-populate inputs with detected values
                        taxInput = detectedTax > 0 ? String(format: "%.2f", detectedTax) : ""
                        tipInput = detectedTip > 0 ? String(format: "%.2f", detectedTip) : ""
                        totalInput = detectedTotal > 0 ? String(format: "%.2f", detectedTotal) : ""
                        itemCountInput = detectedItemCount > 0 ? String(detectedItemCount) : ""

                        isLoading = false
                    }
                }
                return
            }

            // Pre-populate inputs with detected values
            taxInput = detectedTax > 0 ? String(format: "%.2f", detectedTax) : ""
            tipInput = detectedTip > 0 ? String(format: "%.2f", detectedTip) : ""
            totalInput = detectedTotal > 0 ? String(format: "%.2f", detectedTotal) : ""
            itemCountInput = detectedItemCount > 0 ? String(detectedItemCount) : ""

            isLoading = false
        }
    }
    
    private func handleConfirm() {
        let confirmedData = ConfirmedReceiptData(
            tax: Double(taxInput) ?? 0,
            tip: Double(tipInput) ?? 0,
            total: Double(totalInput) ?? 0,
            itemCount: Int(itemCountInput) ?? 0
        )
        onConfirm(confirmedData)
    }
}

// MARK: - Image Popup View
struct ImagePopupView: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                // Full screen image viewer
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        onDismiss()
                    }
                
                Spacer()
                
                // Instructions
                Text("Tap outside image to close")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom)
            }
        }
    }
}

// MARK: - Calculation Summary View
struct CalculationSummaryView: View {
    let tax: Double
    let tip: Double
    let total: Double
    
    var actualItemsPrice: Double {
        return max(0, total - tax - tip)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Calculation Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Total Amount")
                    Spacer()
                    Text("$\(total, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                
                if tax > 0 {
                    HStack {
                        Text("Less: Tax")
                        Spacer()
                        Text("-$\(tax, specifier: "%.2f")")
                            .foregroundColor(.adaptiveAccentRed)
                    }
                }
                
                if tip > 0 {
                    HStack {
                        Text("Less: Tip")
                        Spacer()
                        Text("-$\(tip, specifier: "%.2f")")
                            .foregroundColor(.adaptiveAccentRed)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Items Price Target")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("$\(actualItemsPrice, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.adaptiveAccentBlue)
                }
            }
            .font(.subheadline)
            
            if actualItemsPrice > 0 {
                Text("The app will find item combinations that sum to $\(actualItemsPrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.adaptiveAccentBlue.opacity(0.05))
        .cornerRadius(.cornerRadiusButton)
    }
}

// MARK: - View Modifiers

private struct CameraSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    let onImageCaptured: () -> Void
    let onUpload: () -> Void
    let onManualEntry: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                CameraCaptureWithOverlay(
                    isPresented: $isPresented,
                    capturedImage: $capturedImage,
                    onImageCaptured: onImageCaptured,
                    onUpload: onUpload,
                    onManualEntry: onManualEntry,
                    onCancel: onCancel
                )
                .ignoresSafeArea()
            }
    }
}

private struct PhotoLibrarySheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    @Binding var showingCamera: Bool
    let onImageCaptured: () -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                CameraCapture(
                    isPresented: $isPresented,
                    capturedImage: $capturedImage,
                    sourceType: .photoLibrary
                )
                .ignoresSafeArea()
                .onAppear {
                    // Dismiss camera when photo library appears
                    showingCamera = false
                }
                .onDisappear {
                    if capturedImage != nil {
                        // User selected an image, proceed with it
                        onImageCaptured()
                    } else {
                        // User cancelled without selecting image, restore camera
                        showingCamera = true
                    }
                }
            }
    }
}

extension View {
    func cameraSheet(
        isPresented: Binding<Bool>,
        capturedImage: Binding<UIImage?>,
        onImageCaptured: @escaping () -> Void,
        onUpload: @escaping () -> Void,
        onManualEntry: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(CameraSheetModifier(
            isPresented: isPresented,
            capturedImage: capturedImage,
            onImageCaptured: onImageCaptured,
            onUpload: onUpload,
            onManualEntry: onManualEntry,
            onCancel: onCancel
        ))
    }

    func photoLibrarySheet(
        isPresented: Binding<Bool>,
        capturedImage: Binding<UIImage?>,
        showingCamera: Binding<Bool>,
        onImageCaptured: @escaping () -> Void
    ) -> some View {
        modifier(PhotoLibrarySheetModifier(
            isPresented: isPresented,
            capturedImage: capturedImage,
            showingCamera: showingCamera,
            onImageCaptured: onImageCaptured
        ))
    }
}
