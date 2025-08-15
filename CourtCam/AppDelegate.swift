//
//  AppDelegate.swift
//  CourtCam
//
//  Created by bpang24 on 8/4/25.
//

import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return orientationLock
    }
}
