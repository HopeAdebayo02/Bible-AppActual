//
//  Bible_AppApp.swift
//  Bible App
//
//  Created by Hope Adebayo on 9/9/25.
//

import SwiftUI

@main
struct Bible_AppApp: App {
    init() {
        // Initialize API keys first
        APIKeySetup.setupKeys()
        
        // Initialize Supabase when the app starts
        _ = SupabaseManager.shared
        
        // Clear NLT cache to remove old data with section headings
        BibleCacheService.shared.clearNLTCache()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthService.shared)
                .environmentObject(AppearanceService.shared)
                .onOpenURL { url in
                    // Handle Supabase OAuth callback globally to avoid duplicate handlers
                    Task {
                        do {
                            _ = try await SupabaseManager.shared.client.auth.session(from: url)
                            await AuthService.shared.refreshState()
                        } catch {
                            // Optionally log the error
                            print("OAuth callback error: \(error.localizedDescription)")
                        }
                    }
                }
        }
    }
}
