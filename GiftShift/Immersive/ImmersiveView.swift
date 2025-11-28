//
//  ImmersiveView.swift
//  GiftShift
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        RealityView { content in

            // Load default immersive content
            if let immersiveContentEntity = try? await Entity(
                named: "Immersive",
                in: realityKitContentBundle
            ) {
                content.add(immersiveContentEntity)
            }

            // Create a root entity
            let root = Entity()
            root.name = "Root"
            content.add(root)

            // MARK: - 3. Ground plane
            let groundMesh = MeshResource.generatePlane(width: 4, depth: 4)
            let groundMaterial = SimpleMaterial(color: .gray, isMetallic: false)

            let ground = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
            ground.name = "Ground"
            ground.position = [0, -0.01, 0]    // slightly below feet

            // Simple physics so things can land on it later
            ground.components.set(
                CollisionComponent(
                    shapes: [.generateBox(size: [4, 0.02, 4])]
                )
            )
            ground.components.set(
                PhysicsBodyComponent(mode: .static)
            )

            root.addChild(ground)
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
