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
    @State private var immersiveRoot: Entity? = nil

    @State private var ground: ModelEntity? = nil
    @State private var table: Entity? = nil
    @State private var stopButton: ModelEntity? = nil   // 3D Button in the air

    @State private var cubes: [ModelEntity] = []
    @State private var spawnTimer: Timer?

    var body: some View {
        TimelineView(.animation) { _ in
            RealityView { content in

                // Root nur einmal hinzufügen
                content.add(root)

                // Immersive Content nur einmal laden
                if immersiveRoot == nil,
                   let immersiveContentEntity = try? await Entity(
                        named: "Immersive",
                        in: realityKitContentBundle
                   ) {

                    immersiveRoot = immersiveContentEntity
                    content.add(immersiveContentEntity)

                    // Tisch aus der Immersive-Szene suchen
                    // Der Name muss im Reality Composer "Table" sein
                    table = immersiveContentEntity.findEntity(named: "Table")
                }

                // Boden nur einmal erzeugen
                if ground == nil {
                    let g = makeGround()
                    root.addChild(g)
                    ground = g
                }

                // Stop-Button nur einmal erzeugen
                if stopButton == nil {
                    let button = makeStopButton()
                    root.addChild(button)
                    stopButton = button
                }

            } update: { _ in
                // Physik übernimmt die Bewegung der Würfel
            }
            // Tap-Gesten auf 3D-Entities
            .gesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        if value.entity.name == "StopButton" {
                            if spawnTimer != nil {
                                stopCubeSpawner()
                            } else {
                                startCubeSpawner()
                            }
                        }
                    }
            )
        }
        // Timer genau einmal starten
        .task {
            if spawnTimer == nil {
                startCubeSpawner()
            }
        }
        // Timer stoppen, wenn der ImmersiveView verschwindet
        .onDisappear {
            stopCubeSpawner()
        }
    }

    // ---------------------------------------------------------
    // MARK: - Cube Spawner
    // ---------------------------------------------------------
    func startCubeSpawner() {
        guard spawnTimer == nil else { return }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard let table else { return }

            let cube = makePhysicalCube(above: table)
            cubes.append(cube)
            root.addChild(cube)
            scheduleDespawn(for: cube)

            print("Spawned cube at \(cube.position)")
        }

        print("Spawner started.")
    }

    func stopCubeSpawner() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        print("Spawner stopped.")
    }

    // ---------------------------------------------------------
    // MARK: - Despawn after 15s
    // ---------------------------------------------------------
    func scheduleDespawn(for cube: ModelEntity) {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            cube.removeFromParent()
            cubes.removeAll { $0 === cube }
            print("Cube despawned.")
        }
    }

    // ---------------------------------------------------------
    // MARK: - Cube Factory (random über dem Tisch, von oben fallend)
    // ---------------------------------------------------------
    func makePhysicalCube(above table: Entity) -> ModelEntity {
        let size: Float = 0.4

        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: randomCubeColor(), isMetallic: true)
        let cube = ModelEntity(mesh: mesh, materials: [material])

        // Weltposition und Bounds des Tisches
        let tablePos = table.position(relativeTo: nil)
        let bounds = table.visualBounds(relativeTo: nil)

        // Halbe Breite/Tiefe des Tisches
        let halfWidth = bounds.extents.x / 2
        let halfDepth = bounds.extents.z / 2

        // Zufällige Position innerhalb der Tischfläche
        let randomX = Float.random(in: -halfWidth...halfWidth)
        let randomZ = Float.random(in: -halfDepth...halfDepth)

        // Höhe der Tischoberfläche (Mitte + halbe Höhe)
        let tableTopY = tablePos.y + bounds.extents.y / 2

        // Zufällige Fallhöhe über dem Tisch (2–5 m)
        let spawnHeight = Float.random(in: 2.0...5.0)

        // Würfel deutlich über der Tischoberfläche spawnen
        cube.position = [
            tablePos.x + randomX,
            tableTopY + spawnHeight,
            tablePos.z + randomZ
        ]

        // Collision
        cube.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateBox(width: size, height: size, depth: size)]
        )

        // Physik (Gravitation)
        let physicsMat = PhysicsMaterialResource.generate(friction: 1.0, restitution: 0.0)

        cube.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            massProperties: .default,
            material: physicsMat,
            mode: .dynamic
        )

        return cube
    }

    // ---------------------------------------------------------
    // MARK: - 3D Stop Button
    // ---------------------------------------------------------
    func makeStopButton() -> ModelEntity {
        let mesh = MeshResource.generateBox(size: 0.15)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        let button = ModelEntity(mesh: mesh, materials: [material])

        button.name = "StopButton"

        // Position "in der Luft" vor dem Spieler
        button.position = [0, 1.5, -1.0]

        // Etwas flacher als ein Würfel (relevant nur für Collision)
        button.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [0.2, 0.08, 0.05])]
            )
        )

        // Damit er per Tap anvisiert werden kann
        button.components.set(InputTargetComponent())

        return button
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
        ground.position = [0, -0.01, 0]   // leicht unter den Füßen

        // Collision, damit Würfel darauf landen
        ground.components.set(
            CollisionComponent(
                shapes: [.generateBox(size: [4, 0.02, 4])]
            )
        )

        // Statische Physik
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
