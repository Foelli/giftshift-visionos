//
//  ImmersiveView.swift
//  GiftShift
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    @State private var root = Entity()
    @State private var ground: ModelEntity? = nil
    @State private var cubes: [ModelEntity] = []
    @State private var spawnTimer: Timer?

    var body: some View {
        TimelineView(.animation) { _ in
            RealityView { content in

                // Add root entity once
                content.add(root)

                // Load immersive content (optional)
                if let immersiveContentEntity = try? await Entity(
                    named: "Immersive",
                    in: realityKitContentBundle
                ) {
                    content.add(immersiveContentEntity)
                }


                // Create ground plane once
                if ground == nil {
                    let g = makeGround()
                    root.addChild(g)
                    ground = g
                }

                // Start the cube spawner only once
                if spawnTimer == nil {
                    startCubeSpawner()
                }

            } update: { _ in
                // No manual falling — physics handles movement
            }
        }
    }

    // ---------------------------------------------------------
    // MARK: - Cube Spawner
    // ---------------------------------------------------------
    func startCubeSpawner() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard let ground else { return }

            let cube = makePhysicalCube()
            cubes.append(cube)
            root.addChild(cube)

            print("Spawned cube at \(cube.position)")
        }
    }

    // ---------------------------------------------------------
    // MARK: - Cube Factory
    // ---------------------------------------------------------
    func makePhysicalCube() -> ModelEntity {
        let size: Float = 0.4

        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: randomCubeColor(), isMetallic: true)
        let cube = ModelEntity(mesh: mesh, materials: [material])

        // Spawn above ground
        cube.position = [
            Float.random(in: 0...1),
            1.4,
            Float.random(in: 0...1)
        ]

        // Collision
        cube.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateBox(width: size, height: size, depth: size)]
        )

        // Physics (real gravity)
        let physicsMat = PhysicsMaterialResource.generate(friction: 1.0, restitution: 0.0)

        cube.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            massProperties: .default,
            material: physicsMat,
            mode: .dynamic
        )

        return cube
    }

    // ---------------------------------------------------------
    // MARK: - Colors
    // ---------------------------------------------------------
    func randomCubeColor() -> UIColor {
        [.red, .orange, .green].randomElement()!
    }

    // ---------------------------------------------------------
    // MARK: - Ground Plane
    // ---------------------------------------------------------
    func makeGround() -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: 4, depth: 4)
        let material = SimpleMaterial(color: .gray, isMetallic: false)
        let ground = ModelEntity(mesh: mesh, materials: [material])

        ground.name = "Ground"
        ground.position = [0, -0.01, 0]   // slightly below the user's feet

        // Collision so cubes stack properly
        ground.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [4, 0.02, 4])]
            )
        )

        // Static physics
        ground.components.set(
            PhysicsBodyComponent(mode: .static)
        )

        return ground
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
