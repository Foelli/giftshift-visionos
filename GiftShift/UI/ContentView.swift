import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.red.opacity(0.4), .green.opacity(0.4)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 30) {

                Text("🎄 GiftShift 🎁")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)

                if (appModel.gameState == .firstStart) {
                Text("Sort the falling gifts fast!")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Button("Start Game") {
                    Task {
                        appModel.shouldShowWindow = true
                        appModel.startNewGameToken = UUID()
                        await openImmersiveSpace(id: appModel.immersiveSpaceID)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .glassBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: 16))

                } else if (appModel.gameState == .paused) {
                Text("The game is paused")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Button("Resume") {
                    Task {
                        // Close the window (keep immersive space) and resume playing
                        appModel.shouldShowWindow = false
                        appModel.gameState = .playing
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .glassBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: 16))

                } else if (appModel.gameState == .afterRound) {
                Text("end end end")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Button("Restart") {
                    Task {
                        // Start a new game round and ensure immersive space is open
                        appModel.startNewGameToken = UUID()
                        if appModel.immersiveSpaceState != .open {
                            _ = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                        }
                        appModel.shouldShowWindow = false
                        appModel.gameState = .playing
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .glassBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: 16))

                    }

            }
        }
        .ornament(attachmentAnchor: .scene(.trailing)) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GiftShift").bold()
                Text("Version 1.0")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .glassBackgroundEffect()
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            Text("Made by Jasmin & Simon™")
                .padding(10)
                .glassBackgroundEffect()
        }
    }
}
