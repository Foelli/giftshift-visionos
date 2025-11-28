//
//  ContentView.swift
//  GiftShift
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @State private var root = Entity()
    @State private var floor: ModelEntity? = nil
    @State private var cubes: [ModelEntity] = []
    @State private var spawnTimer: Timer?

    var body: some View {
        TimelineView(.animation) { _ in
            RealityView { content in
                
                content.add(root)
                
                // Create floor (your table)
                let f = makeFloor()
                root.addChild(f)
                floor = f
                
                startCubeSpawner()
                
            } update: { _ in
                updateCubeMovement()
            }
        }
    }

    // ---------------------------------------------------------
    // MARK: - Cube Spawner
    // ---------------------------------------------------------
    func startCubeSpawner() {
        spawnTimer?.invalidate()

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard let floor else { return }

            let cube = makePhysicalCube()
            cubes.append(cube)
            floor.addChild(cube)

            print("Spawned cube at local position \(cube.position)")
        }
    }

    // ---------------------------------------------------------
    // MARK: - Manual Falling Movement
    // ---------------------------------------------------------
    func updateCubeMovement() {
        for cube in cubes {
            // Stop if it already landed
            if cube.position.y <= 0.075 {
                cube.position.y = 0.075
                continue
            }

            cube.position.y -= 0.002  // slow manual fall

            if cube.position.y <= 0.075 {
                cube.position.y = 0.075
            }
        }
    }

    // ---------------------------------------------------------
    // MARK: - Cube Factory
    // ---------------------------------------------------------
    func makePhysicalCube() -> ModelEntity {
        let size: Float = 0.15

        let mesh = MeshResource.generateBox(size: size)

        let material = SimpleMaterial(color: randomCubeColor(), isMetallic: false)
        let cube = ModelEntity(mesh: mesh, materials: [material])

        cube.position = [Float.random(in: -0.5...0.5), 0.8, 0] // spawn above table

        cube.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateBox(width: size, height: size, depth: size)]
        )

        let physicsMat = PhysicsMaterialResource.generate(
            friction: 1.0,
            restitution: 0.0
        )

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
    // MARK: - Floor Model
    // ---------------------------------------------------------
    func makeFloor() -> ModelEntity {
        let floor = ModelEntity(
            mesh: .generatePlane(width: 5, depth: 5),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.1), isMetallic: true)]
        )

        floor.position = [0, 0, 0]

        floor.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateBox(width: 5, height: 0.01, depth: 5)]
        )

        floor.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            material: .default,
            mode: .static
        )

        return floor
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
