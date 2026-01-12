// EntityFactory.swift

import UIKit
import RealityKit
import SwiftUI

enum CubeColor: String {
    case red, green, blue
}

struct CubeColorComponent: Component {
    var color: CubeColor
}

struct EntityFactory {


    // MARK: - Cube Factory

    func makePhysicalCube(above table: Entity) -> ModelEntity {
           let size: Float = 0.4

           // choose a logical game color (red/green/blue)
           let gameColor: CubeColor = [.red, .green, .blue].randomElement()!

           let mesh = MeshResource.generateBox(size: size)
           let material = SimpleMaterial(color: uiColor(for: gameColor), isMetallic: true)
           let cube = ModelEntity(mesh: mesh, materials: [material])

           cube.name = "SpawnedCube"
           cube.components.set(CubeColorComponent(color: gameColor))

           // --- spawn position (unchanged) ---
           let tablePos = table.position(relativeTo: nil)
           let bounds = table.visualBounds(relativeTo: nil)

           let halfWidth = bounds.extents.x / 2
           let halfDepth = bounds.extents.z / 2

           let randomX = Float.random(in: -halfWidth...halfWidth)
           let randomZ = Float.random(in: -halfDepth...halfDepth)

           let tableTopY = tablePos.y + bounds.extents.y / 2
           let spawnHeight = Float.random(in: 2.0...4.0)

           cube.position = [
               tablePos.x + randomX,
               tableTopY + spawnHeight,
               tablePos.z + randomZ
           ]

           cube.components.set(
               CollisionComponent(shapes: [.generateBox(size: [size, size, size])])
           )
           cube.components.set(InputTargetComponent())

           let physicsMat = PhysicsMaterialResource.generate(friction: 3.0, restitution: 0.0)
           cube.components.set(
               PhysicsBodyComponent(
                   massProperties: .default,
                   material: physicsMat,
                   mode: .dynamic
               )
           )

           return cube
       }
    
    // HUD text: show points (and optionally lost/despawned)
    func makeScoreEntity(points: Int, despawnedCubesCount: Int) -> ModelEntity {
        let message = despawnedCubesCount >= 5
            ? "YOU LOST"
            : "Points: \(points)  Lost: \(despawnedCubesCount)"

        let mesh = MeshResource.generateText(
            message,
            extrusionDepth: 0.05,
            font: .systemFont(ofSize: 0.5, weight: .bold)
        )

        let material = SimpleMaterial(color: .green, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [despawnedCubesCount >= 5 ? -1.5 : -1.7, 2.0, -2.0]
        return entity
    }

    func uiColor(for c: CubeColor) -> UIColor {
        switch c {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        }
    }

    // MARK: - Stop Button

    func makeStopButton() -> ModelEntity {
        let mesh = MeshResource.generateBox(size: 0.15)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        let button = ModelEntity(mesh: mesh, materials: [material])

        button.name = "StopButton"
        button.position = [0, 1.5, -1.0]

        button.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [0.2, 0.08, 0.05])]
            )
        )

        button.components.set(InputTargetComponent())

        return button
    }


    // MARK: - Game Score

    func makeScoreEntity(despawnedCubesCount: Int) -> ModelEntity {
        let message = despawnedCubesCount >= 5 ? "YOU LOST" : "Count: \(despawnedCubesCount)"

        let mesh = MeshResource.generateText(
            message,
            extrusionDepth: 0.05,
            font: .systemFont(ofSize: 0.5, weight: .bold)
        )

        let material = SimpleMaterial(color: .green, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [despawnedCubesCount >= 5 ? -1.5 : -1.2, 2.0, -2.0]

        return entity
    }

    // MARK: - Colors

    func randomCubeColor() -> UIColor {
        [.red, .orange, .green].randomElement()!
    }

    // MARK: - Ground

    func makeGround() -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: 4, depth: 4)
        let material = SimpleMaterial(color: .gray, isMetallic: false)
        let ground = ModelEntity(mesh: mesh, materials: [material])

        ground.name = "Ground"
        ground.position = [0, -0.01, 0]

        ground.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [4, 0.02, 4])]
            )
        )

        let groundPhysicsMat = PhysicsMaterialResource.generate(
            friction: 4.0,
            restitution: 0.0
        )

        ground.components.set(
            PhysicsBodyComponent(
                material: groundPhysicsMat,
                mode: .static
            )
        )

        return ground
    }
}
