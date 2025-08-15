//
//  RotatingAVPlayerViewController.swift
//  CourtCam
//
//  Created by bpang24 on 8/4/25.
//


import AVKit

class RotatingAVPlayerViewController: AVPlayerViewController {
    var dismissCompletion: (() -> Void)?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .allButUpsideDown  // Allow full rotation in fullscreen only
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dismissCompletion?()
    }
}
