//
//  IPBones.swift
//  ipbones
//  Created by IP-Economist 2026
//

import SwiftUI

@main
struct IPBonesUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        Settings {
            
        }
        
        #endif
    }
}

