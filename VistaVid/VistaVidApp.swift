//
//  VistaVidApp.swift
//  VistaVid
//
//  Created by anthony on 2/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UIKit

// MARK: - App Entry Point
@main
struct VistaVidApp: App {
    // MARK: - Properties
    @StateObject private var authModel = AuthenticationViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // MARK: - Initializer
    init() {
        print("🔥 Starting Firebase configuration...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully!")
        print("📱 App name: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown")")
        
        // Initialize Firestore
        _ = Firestore.firestore()
        print("📚 Firestore instance created")
        
        // Debug current user state
        if let currentUser = Auth.auth().currentUser {
            print("👤 Current user: \(currentUser.uid)")
        } else {
            print("👤 No current user")
        }
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                if authModel.isAuthenticated {
                    MainView(authModel: authModel)
                        .environmentObject(authModel)
                } else {
                    SignInView(model: authModel)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🔥 Starting Firebase configuration...")
        
        // Check if already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Verify Firebase is configured
        if let app = FirebaseApp.app() {
            print("✅ Firebase configured successfully!")
            print("📱 App name: \(app.name)")
            
            // Test Firestore access
            _ = Firestore.firestore()
            print("📚 Firestore instance created")
            
            // Test Auth access
            let auth = Auth.auth()
            if let currentUser = auth.currentUser {
                print("👤 Current user exists: \(currentUser.uid)")
            } else {
                print("👤 No current user")
            }
        } else {
            print("❌ Firebase configuration failed!")
        }
        
        return true
    }
}
