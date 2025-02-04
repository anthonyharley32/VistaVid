import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🔥 Starting Firebase configuration...")
        
        do {
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
        } catch {
            print("❌ Firebase configuration failed: \(error.localizedDescription)")
            return false
        }
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