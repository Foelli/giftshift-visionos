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

                Text("Sort the falling gifts fast!")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Button("Start Game") {
                    Task {
                        await openImmersiveSpace(id: appModel.immersiveSpaceID)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .glassBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: 16))

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
