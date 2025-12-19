//
//  GiftShiftApp.swift
//  GiftShift
//
//  Created by Simon Felhofer on 21.11.25.
//

import SwiftUI

@main
struct GiftShiftApp: App {
    
    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()
    
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        WindowGroup(id: "Window") {
            if avPlayerViewModel.isPlaying {
                AVPlayerView(viewModel: avPlayerViewModel)
            } else {
                ContentView()
                    .environment(appModel)
            }
        }
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    avPlayerViewModel.play()
                    dismissWindow(id: "Window")
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    avPlayerViewModel.reset()
                }
                .onChange(of: appModel.shouldShowWindow) { _, newValue in
                    if newValue {
                        openWindow(id: "Window")
                        appModel.shouldShowWindow = false
                    }
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
