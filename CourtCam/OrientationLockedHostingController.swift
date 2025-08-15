import SwiftUI

class OrientationLockedHostingController<Content>: UIHostingController<Content> where Content: View {
    private var allowedOrientations: UIInterfaceOrientationMask = .all

    init(rootView: Content, allowedOrientations: UIInterfaceOrientationMask) {
        self.allowedOrientations = allowedOrientations
        super.init(rootView: rootView)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return allowedOrientations
    }
}
