// EntityFactory.swift

import UIKit
import RealityKit
import SwiftUI

struct EntityFactory {

    // MARK: - Cube

    func makePhysicalCube(above table: Entity) -> ModelEntity {
        let size: Float = 0.4

        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: randomCubeColor(), isMetallic: true)
        let cube = ModelEntity(mesh: mesh, materials: [material])

        cube.name = "SpawnedCube"

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
            CollisionComponent(
                shapes: [.generateBox(size: [size, size, size])]
            )
        )

        cube.components.set(InputTargetComponent())

        let physicsMat = PhysicsMaterialResource.generate(
            friction: 3.0,
            restitution: 0.0
        )

        cube.components.set(
            PhysicsBodyComponent(
                massProperties: .default,
                material: physicsMat,
                mode: .dynamic
            )
        )

        return cube
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

    // MARK: - Score Text

    func makeScoreEntity(despawnedCubesCount: Int) -> ModelEntity {
        let message = despawnedCubesCount >= 5
            ? "YOU LOST"
            : "Count: \(despawnedCubesCount)"

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

        let physicsMat = PhysicsMaterialResource.generate(
            friction: 4.0,
            restitution: 0.0
        )

        ground.components.set(
            PhysicsBodyComponent(
                material: physicsMat,
                mode: .static
            )
        )

        return ground
    }

    // MARK: - Utilities

    func randomCubeColor() -> UIColor {
        [.red, .orange, .green].randomElement()!
    }
}
