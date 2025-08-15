import SwiftUI

struct OrientationLockedView<Content: View>: UIViewControllerRepresentable {
    let orientation: UIInterfaceOrientationMask
    let content: Content

    init(orientation: UIInterfaceOrientationMask, @ViewBuilder content: () -> Content) {
        self.orientation = orientation
        self.content = content()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        OrientationLockedHostingController(rootView: content, allowedOrientations: orientation)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}
