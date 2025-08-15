//
//  CameraViewController.swift
//  CourtCam
//
//  Created by bpang24 on 6/27/25.
//

import UIKit
import AVFoundation
import Photos

extension Notification.Name {
    static let courtDetectionUpdate = Notification.Name("courtDetectionUpdate")
}

struct CourtResponse: Decodable {
    let is_court: Bool
}

@objcMembers
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let movieOutput = AVCaptureMovieFileOutput()
    var frameCount = 0
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissions()
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { self.setupSession() } }
            }
        default:
            return
        }
    }
    
    private func setupSession() {
        captureSession = AVCaptureSession()
        guard
            let cam   = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: .back),
            let input = try? AVCaptureDeviceInput(device: cam)
        else { return }
        captureSession.addInput(input)
        
        // Preview Layer
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame        = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
        
        // Frame output for Vision
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self,
                                       queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(output)
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
        
        captureSession.startRunning()
    }
    
    // MARK: – Frame capture & sending to server
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process every 3rd frame
        if frameCount % 5 == 0 {
            guard let image = imageFromSampleBuffer(sampleBuffer) else { return }
            sendFrameToServer(image)
        }
        frameCount += 1
    }
    
    // Convert sampleBuffer to UIImage
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Method to send the frame to the FastAPI endpoint
    func sendFrameToServer(_ image: UIImage) {
        guard let url = URL(string: "http://tennis-lb-api-308609498.us-east-1.elb.amazonaws.com/isCourt") else { return }
        
        // Convert UIImage to JPEG data
        let resized = resizeImage(image, targetSize: CGSize(width: 320, height: 180))
        guard let imageData = resized.jpegData(compressionQuality: 0.3) else {
            print("❌ Failed to compress resized image")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart/form-data body
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        // Send HTTP request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending frame: \(error)")
                return
            }
            guard let data = data,
                  let result = try? JSONDecoder().decode(CourtResponse.self, from: data) else {
                print("❌ Failed to decode is_court response")
                return
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .courtDetectionUpdate, object: nil, userInfo: ["is_court": result.is_court])
            }
        }
        task.resume()
    }

    // MARK: – Recording controls
    func startRecording(to url: URL) {
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }
    
    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }
    
    // MARK: – AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let err = error {
            print("⚠️ Recording error:", err)
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("❌ No permission to save video")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            }) { success, saveError in
                if let se = saveError {
                    print("⚠️ Save failed:", se)
                } else {
                    print("✅ Movie saved to Camera Roll")
                }
                try? FileManager.default.removeItem(at: outputFileURL)
            }
        }
    }
}
