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
                    // Mirror the window control observers here so they are active
                    // whenever this window scene is alive.
                    .onChange(of: appModel.shouldShowWindow) { _, newValue in
                        if newValue {
                            openWindow(id: "Window")
                            appModel.shouldShowWindow = false
                        }
                    }
                    .onChange(of: appModel.shouldCloseWindow) { _, newValue in
                        if newValue {
                            dismissWindow(id: "Window")
                            appModel.shouldCloseWindow = false
                        }
                    }
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
                // Keep these if you also want ImmersiveSpace to respond while mounted.
                .onChange(of: appModel.shouldShowWindow) { _, newValue in
                    if newValue {
                        openWindow(id: "Window")
                        appModel.shouldShowWindow = false
                    }
                }
                .onChange(of: appModel.shouldCloseWindow) { _, newValue in
                    if newValue {
                        dismissWindow(id: "Window")
                        appModel.shouldCloseWindow = false
                    }
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
