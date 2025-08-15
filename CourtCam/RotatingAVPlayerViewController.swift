import AVKit

class RotatingAVPlayerViewController: AVPlayerViewController {
    var dismissCompletion: (() -> Void)?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dismissCompletion?()
    }
}
