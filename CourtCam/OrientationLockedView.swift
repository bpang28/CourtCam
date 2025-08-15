//
//  OrientationLockedView.swift
//  CourtCam
//
//  Created by bpang24 on 8/4/25.
//

import SwiftUI

struct OrientationLockedView<Content: View>: UIViewControllerRepresentable {
    typealias UIViewControllerType = OrientationHostingController<Content>
    
    let orientation: UIInterfaceOrientationMask
    let content: Content

    init(orientation: UIInterfaceOrientationMask, @ViewBuilder content: () -> Content) {
        self.orientation = orientation
        self.content = content()
    }

    func makeUIViewController(context: Context) -> OrientationHostingController<Content> {
        return OrientationHostingController(rootView: content, orientation: orientation)
    }

    func updateUIViewController(_ uiViewController: OrientationHostingController<Content>, context: Context) {
        // no-op
    }
}
