//
//  OrientationLockedHostingController.swift
//  CourtCam
//
//  Created by bpang24 on 8/4/25.
//

import UIKit
import SwiftUI

class OrientationHostingController<Content: View>: UIHostingController<Content> {
    private var orientation: UIInterfaceOrientationMask
    
    init(rootView: Content, orientation: UIInterfaceOrientationMask) {
        self.orientation = orientation
        super.init(rootView: rootView)
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        orientation
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Inform AppDelegate about the lock
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }

        // Request geometry update with completion handler
        if let scene = view.window?.windowScene {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientation)
            scene.requestGeometryUpdate(preferences) { error in
                print("❌ Failed to update orientation: \(error)")
            }
        }

        // Optional: Force immediate rotation if needed
        if orientation.contains(.portrait) {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        } else if orientation.contains(.landscapeRight) {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        } else if orientation.contains(.landscapeLeft) {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
