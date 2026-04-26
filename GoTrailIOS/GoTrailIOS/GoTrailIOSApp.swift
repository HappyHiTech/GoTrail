// TrailGuardApp.swift
import SwiftUI

@main
struct TrailGuardApp: App {
    init() {
        if HikeSessionManager.shared.isActive {
            try? HikeSessionManager.shared.stopHike()
        }
        _ = LocalDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    LocationTracker.shared.requestPermission()
                    Task { await PlantClassifier.shared.loadModel() }
                    
                    // Wait for permission dialog to appear and be answered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        Task {
                            await HikeSessionTests.runAll()
                        }
                    }
                }
        }
    }
}


