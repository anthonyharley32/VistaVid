//
//  ContentView.swift
//  VistaVid
//
//  Created by anthony on 2/3/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authModel = AuthenticationViewModel()
    
    var body: some View {
        NavigationView {
            if authModel.isAuthenticated {
                MainView(authModel: authModel)
            } else {
                SignInView(model: authModel)
            }
        }
        // Debug log for view state changes
        .onChange(of: authModel.isAuthenticated) { oldValue, newValue in
            print("DEBUG: User authenticated state changed from: \(oldValue) to: \(newValue)")
        }
    }
}

#Preview {
    ContentView()
}
