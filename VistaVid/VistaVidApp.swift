//
//  VistaVidApp.swift
//  VistaVid
//
//  Created by anthony on 2/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UIKit

// MARK: - App Entry Point
@main
struct VistaVidApp: App {
    // MARK: - Properties
    @StateObject private var authModel = AuthenticationViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                if authModel.isAuthenticated {
                    // Main app content will go here
                    Text("Welcome \(authModel.currentUser?.username ?? "")!")
                        .onTapGesture {
                            try? authModel.signOut()
                        }
                } else {
                    SignInView(model: authModel)
                }
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🔥 Starting Firebase configuration...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully!")
        
        // Test Firebase Auth
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("❌ Firebase Auth Error: \(error.localizedDescription)")
                return
            }
            
            if let user = authResult?.user {
                print("✅ Firebase Auth working! Anonymous user ID: \(user.uid)")
            }
        }
        
        return true
    }
}
