//
//  CameraView.swift
//  CourtCam
//
//  Created by bpang24 on 6/27/25.
//
import SwiftUI
import AVFoundation
import Vision

struct CameraView: UIViewControllerRepresentable {
    @Binding var isCourt: Bool
    @Binding var isRecording: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        NotificationCenter.default.addObserver(forName: .courtDetectionUpdate, object: nil, queue: .main) { notification in
            if let isCourt = notification.userInfo?["is_court"] as? Bool {
                context.coordinator.isCourt = isCourt
            }
        }
        return vc
    }
    
    func updateUIViewController(_ vc: CameraViewController, context: Context) {
        if isRecording && !context.coordinator.isRecording {
            let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fname = "court_\(Int(Date().timeIntervalSince1970)).mov"
            let url   = docs.appendingPathComponent(fname)
            vc.startRecording(to: url)
            context.coordinator.isRecording = true
        } else if !isRecording && context.coordinator.isRecording {
            vc.stopRecording()
            context.coordinator.isRecording = false
        }
    }
    
    func makeUIView(context: Context) -> some UIView {
        let container = UIView(frame: UIScreen.main.bounds)

        let cameraController = makeUIViewController(context: context)
        let cameraView = cameraController.view!
        cameraView.frame = container.bounds
        container.addSubview(cameraView)

        let overlayImageView = UIImageView()
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.contentMode = .scaleAspectFit
        overlayImageView.image = UIImage(named: "court_white")
        container.addSubview(overlayImageView)
    
        NSLayoutConstraint.activate([
            overlayImageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            overlayImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            overlayImageView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.6),
            overlayImageView.heightAnchor.constraint(equalTo: overlayImageView.widthAnchor, multiplier: 1.5)
        ])

        // Periodically update the border color
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let imageName = context.coordinator.isCourt ? "court_green" : "court_white"
        }

        return container
    }

    class Coordinator: NSObject {
        var parent: CameraView
        var isRecording = false
        var isCourt: Bool = false {
            didSet {
                DispatchQueue.main.async {
                    self.parent.isCourt = self.isCourt
                }
            }
        }
        init(_ parent: CameraView) {
            self.parent = parent
        }
    }
}
