//
//  VistaVidApp.swift
//  VistaVid
//
//  Created by anthony on 2/3/25.
//

import SwiftUI
import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🔥 Starting Firebase configuration...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully!")
        return true
    }
}

@main
struct VistaVidApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
